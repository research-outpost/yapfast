//! Twemoji's pictures, which upstream Yapfast draws its emoji from, were cut
//! from this fork: the fork draws emoji through the system's colour font,
//! cached once per glyph by [`crate::emoji_glyphs`], to keep the program's size
//! and memory as 0.3.0 had them. The call sites stay, and get `None` here.

use slint::Image;

/// Nothing to draw from: callers fall back to the system font's glyph.
pub fn picture(_glyph: &str, _px: f32, _scale: f32) -> Option<Image> {
    None
}

/// Nothing is kept, so there is nothing to let go of.
pub fn forget() {}
