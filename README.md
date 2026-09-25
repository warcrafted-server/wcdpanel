# wcdpanel

*[Versión en castellano](README.es.md)*

An information addon for World of Warcraft: Wrath of the Lich King (3.3.5a). It draws
configurable bars anchored to the top or bottom of the screen (or floating, anywhere you like),
each with room for your location, bags, durability, quests, gold, clock, volume, mail,
professions, and every other addon's icon: everything you currently pile up around the minimap,
kept tidy and out of its way.

It's inspired by TitanPanel, but written from scratch: a new addon, not a patch on top of Titan,
and it doesn't require having Titan installed. Titan's license forbids redistributing modified
copies of it, so none of its code is in here; only the same "bar with plugins" idea you already
know.

## Installing

Copy the repository into `World of Warcraft/Interface/AddOns/` under the name `wcdpanel` (not
`wcdpanel-main` or similar), and enable it from the AddOns list at the character select screen.

## First look

On first login with a character, a top bar is already there, laid out like this:

- **Left**: location, bags, durability, quests, gold, loot method, rested XP, guild, performance,
  and one icon per profession you've learned.
- **Right**: clock, volume, mail, the auto-hide toggle, and behind it, your own addons' icons
  (both the ones using LibDataBroker and the ones that drop a loose button on the minimap).

All of that is configurable from the start: what's shown, where, and how it looks. Nothing needs
hand-editing to start changing it.

## Moving things around

With bars unlocked (`/wcd lock`, or the "Lock all bars" checkbox in the options), any element can
be dragged: drop it on another bar, or on the left/center/right third of the same bar, to move it
there. A "free" bar's own background (one not anchored to the top or bottom) can be dragged too,
to place it anywhere on screen.

Right-clicking an element or a bar's background opens a menu with the most common actions: remove
from the bar, move it elsewhere, lock, auto-hide... without having to open the options panel for
everyday changes.

## Bars

There's no limit on how many bars you can have. `/wcd bar add top|bottom|free` creates one (or
the "Add bar" button in the options); `/wcd bar del <n>` removes it. Each bar has its own name,
height, scale, opacity, background color, whether it hides in combat, and whether it auto-hides
when the mouse moves away. Bars anchored to the top or bottom (`top`/`bottom`) can also push
Blizzard's own frames out of the way (the player frame, the minimap, the action bar...) so they
don't overlap; `free` bars sit wherever you put them and never move anything else.

## All your addons, on the bar

Two plugins exist to stop the minimap from turning into a graveyard of icons:

- **LDB**: any addon using LibDataBroker (quest trackers, calendars, gold counters...) shows up
  automatically as another bar element, with its own icon, text, tooltip, and menu. "Launcher"
  data objects (the ones that just open a window on click) can be shown icon-only to save room.
- **MinimapButtons**: picks up the loose buttons some addons attach to the minimap (the ones that
  don't use LibDataBroker) and places them the same way, at a uniform icon size, without touching
  their click behavior or function. Each button can be "collected" or left on the minimap
  individually, from the plugin's options.

Both can be turned off if you'd rather keep those icons on the minimap.

## Professions

One icon per profession you've learned (runeforging included, for death knights), already placed
on the bar from the start. They're icon-only to save space: hover to see the skill level, click
for that profession's main action (smelting, gathering herbs, opening a cooking fire...),
shift-click for the secondary action where one exists. Professions with no meaningful click (like
skinning) just show the icon.

## Profiles

Settings are saved per account profile (AceDB), so you can share one bar layout across every
character, or give a specific one its own profile, from the Profiles tab in the options.

## Options

`/wcd` opens the full panel (also reachable from Interface ▸ AddOns): general settings (spacing
between elements, icon size...), one section per bar, one section per plugin (enable it, its own
settings, and where each of its elements is placed), and profiles.

A few standalone commands, so the panel isn't always needed: `/wcd lock` locks or unlocks every
bar; `/wcd bar add top|bottom|free` and `/wcd bar del <n>` create or remove a bar; `/wcd bar`
lists the existing ones.

## Writing your own plugin

`docs/PLUGIN_API.md` documents the full API with a minimal example. The gist: a plugin registers
one or more elements (`WCDPanel:NewPlugin`), each with its icon, text, and click/tooltip
callbacks; wcdpanel takes care of placing it, moving it, saving its position, and exposing it in
the options.

## Status

Under active development. See `CHANGELOG.md` for what's been fixed and added in each pass.
