//! The system's title bar in the theme's colours, on Windows: DWM draws its
//! caption on the rail's ground with the text's ink, its frame dark or light
//! as the theme is, so the bar Windows draws reads as part of the window
//! while keeping what only the system's bar does (Snap Layouts, the system
//! menu, the shadow). Windows 11 reads these; older Windows ignores them and
//! keeps its own colours. Elsewhere it does nothing.

use yapfast_ui::YapfastWindow;

/// Gives the window's caption the colours of the theme it shows now. Slint
/// makes the system's window only once its event loop runs, so a window shown
/// at start has none yet: then this tries again shortly, a few times.
#[cfg(windows)]
pub(super) fn paint(window: &YapfastWindow) {
    use slint::ComponentHandle;

    if !painted(window) {
        retry(window.as_weak(), RETRIES);
    }
}

#[cfg(not(windows))]
pub(super) fn paint(_: &YapfastWindow) {}

/// How many times, and how far apart, a window without its system window yet
/// is tried again: up to a second in all.
#[cfg(windows)]
const RETRIES: u32 = 20;
#[cfg(windows)]
const RETRY_EVERY: std::time::Duration = std::time::Duration::from_millis(50);

#[cfg(windows)]
fn retry(window: slint::Weak<YapfastWindow>, left: u32) {
    if left == 0 {
        return;
    }
    slint::Timer::single_shot(RETRY_EVERY, move || {
        if let Some(shown) = window.upgrade()
            && !painted(&shown)
        {
            retry(window, left - 1);
        }
    });
}

/// Sets the caption's colours, if the system's window exists yet.
#[cfg(windows)]
fn painted(window: &YapfastWindow) -> bool {
    use slint::{
        ComponentHandle,
        winit_030::{
            WinitWindowAccessor,
            winit::raw_window_handle::{HasWindowHandle, RawWindowHandle},
        },
    };

    let tokens = window.global::<yapfast_ui::Theme>();
    let caption = colorref(tokens.get_rail());
    let text = colorref(tokens.get_text());
    let dark = i32::from(tokens.get_dark());
    window
        .window()
        .with_winit_window(|winit| {
            let Ok(handle) = winit.window_handle() else {
                return false;
            };
            let RawWindowHandle::Win32(handle) = handle.as_raw() else {
                return false;
            };
            let hwnd = handle.hwnd.get() as *mut core::ffi::c_void;
            set(hwnd, DARK_MODE, &dark);
            set(hwnd, BORDER_COLOR, &caption);
            set(hwnd, CAPTION_COLOR, &caption);
            set(hwnd, TEXT_COLOR, &text);
            true
        })
        .unwrap_or(false)
}

/// `DWMWINDOWATTRIBUTE`s: a BOOL, then three COLORREFs.
#[cfg(windows)]
const DARK_MODE: u32 = 20;
#[cfg(windows)]
const BORDER_COLOR: u32 = 34;
#[cfg(windows)]
const CAPTION_COLOR: u32 = 35;
#[cfg(windows)]
const TEXT_COLOR: u32 = 36;

/// A COLORREF, `0x00bbggrr`.
#[cfg(windows)]
fn colorref(colour: slint::Color) -> u32 {
    (u32::from(colour.blue()) << 16) | (u32::from(colour.green()) << 8) | u32::from(colour.red())
}

#[cfg(windows)]
#[link(name = "dwmapi")]
unsafe extern "system" {
    fn DwmSetWindowAttribute(
        hwnd: *mut core::ffi::c_void,
        attribute: u32,
        value: *const core::ffi::c_void,
        size: u32,
    ) -> i32;
}

/// Sets one attribute. A version of Windows that doesn't know it answers
/// with an error, which leaves the caption as it was.
#[cfg(windows)]
fn set<T>(hwnd: *mut core::ffi::c_void, attribute: u32, value: &T) {
    // SAFETY: `hwnd` is the live window winit just handed out, and `value`
    // points at a `T` that outlives the call, whose size is what's passed.
    unsafe {
        DwmSetWindowAttribute(
            hwnd,
            attribute,
            std::ptr::from_ref(value).cast(),
            u32::try_from(size_of::<T>()).unwrap_or(0),
        );
    }
}

#[cfg(all(test, windows))]
mod tests {
    use super::colorref;

    #[test]
    fn a_colour_goes_to_windows_blue_first() {
        assert_eq!(
            colorref(slint::Color::from_rgb_u8(0x0a, 0x14, 0x1d)),
            0x001d_140a
        );
    }
}
