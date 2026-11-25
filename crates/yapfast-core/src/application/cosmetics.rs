//! Which of the cosmetics people wear show, as Settings → Appearance →
//! Profiles says. What's off is never asked for: the pictures the core
//! downloads, and the rows the window draws, go through these first, so an
//! effect, decoration or tag badge that's off is neither fetched nor
//! decoded. Nameplates have their own switch, `AppState::hide_nameplates`.

/// The profile switches. Off is the cheaper side of each, which fetches and
/// decodes nothing of it; see "Profile switches" in `docs/discord/people.md`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Cosmetics {
    /// Profile covers show: the effect played over a card and the frame
    /// drawn round it. One switch for both, as they are one piece of art;
    /// off, neither the shop nor its pictures are asked for.
    pub covers: bool,
    /// Avatar decorations show.
    pub decorations: bool,
    /// Decorations and nameplates play their animated pictures. Off, only
    /// their stills are fetched.
    pub moving: bool,
    /// Display names show in the font and colours their person picked.
    pub name_styles: bool,
    /// A role whose colour is a gradient or holographic one draws it across
    /// the name, letter by letter. Off, names keep the role's first colour.
    pub name_colours: bool,
    /// Server tags show beside names, with their badges.
    pub server_tags: bool,
    /// Badges show on a card: a picture each, and one levels request per
    /// profile while the card is open.
    pub badges: bool,
    /// A profile's background shows: its banner picture and, on a themed
    /// card, the gradient of its two colours.
    pub background: bool,
}

impl Default for Cosmetics {
    /// Everything on, as Discord's client draws a profile; each switch turns
    /// its cosmetic off.
    fn default() -> Self {
        Self {
            covers: true,
            decorations: true,
            moving: true,
            name_styles: true,
            name_colours: true,
            server_tags: true,
            badges: true,
            background: true,
        }
    }
}

impl Cosmetics {
    /// The address of a decoration around an avatar, if decorations show.
    pub fn decoration(self, url: Option<&str>) -> Option<&str> {
        url.filter(|_| self.decorations)
    }

    /// A server tag beside a name, if tags show.
    pub fn tag<T>(self, tag: Option<&T>) -> Option<&T> {
        tag.filter(|_| self.server_tags)
    }

    /// A display name's style, if styles show.
    pub fn style<T>(self, style: Option<T>) -> Option<T> {
        style.filter(|_| self.name_styles)
    }

    /// A role colour's gradient ends, if names draw gradients.
    pub fn colours<T>(self, end: Option<T>) -> Option<T> {
        end.filter(|_| self.name_colours)
    }

    /// A profile's frame, if covers show.
    pub fn frame<T>(self, frame: Option<T>) -> Option<T> {
        frame.filter(|_| self.covers)
    }

    /// A profile's effect, if covers show.
    pub fn effect<T>(self, effect: Option<T>) -> Option<T> {
        effect.filter(|_| self.covers)
    }

    /// A profile's badges, if they show.
    pub fn badges<T>(self, badges: T) -> Option<T> {
        self.badges.then_some(badges)
    }

    /// A profile's banner and theme colours, if its background shows.
    pub fn background<T>(self, background: Option<T>) -> Option<T> {
        background.filter(|_| self.background)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn off_leaves_out_each_cosmetic() {
        let off = Cosmetics {
            covers: false,
            decorations: false,
            moving: false,
            name_styles: false,
            name_colours: false,
            server_tags: false,
            badges: false,
            background: false,
        };
        assert_eq!(off.decoration(Some("https://cdn/static")), None);
        assert_eq!(off.tag(Some(&"TAG")), None);
        assert_eq!(off.style(Some(1)), None);
        assert_eq!(off.colours(Some((1, Some(2)))), None);
        assert_eq!(off.effect(Some("sku")), None);
        assert_eq!(off.frame(Some("sku")), None);
        assert_eq!(off.badges(vec!["a"]), None);
        assert_eq!(off.background(Some("https://cdn/banner.png")), None);
    }

    #[test]
    fn on_shows_each_as_discord_gives_it() {
        let on = Cosmetics::default();
        assert_eq!(on.decoration(Some("url")), Some("url"));
        assert_eq!(on.tag(Some(&"TAG")), Some(&"TAG"));
        assert_eq!(on.style(Some(1)), Some(1));
        assert_eq!(on.colours(Some((1, Some(2)))), Some((1, Some(2))));
        assert_eq!(on.effect(Some("sku")), Some("sku"));
        assert_eq!(on.frame(Some("sku")), Some("sku"));
        assert_eq!(on.badges(1), Some(1));
        assert_eq!(on.background(Some("url")), Some("url"));
        // Covers are one switch over both pieces.
        assert_eq!(Cosmetics::default(), on);
    }
}
