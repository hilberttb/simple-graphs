# Simple Graphs
**Version: 0.2.0**  
Date: 9/24/2026

A work-in-progress Crusader Kings III mod that records how many counties belong to each faith and
each culture, once a year, and draws the result as a connected line graph in its
own window.

There is no vanilla or mod precedent (as far as I could find) in CK3 for rendering a numeric time series.
This builds one out of the primitives the engine happens to expose.

**Status:** Still a proof of concept, but no longer a plain one. Data collection,
the picker and the plot all function, the graph is drawn on a paper background,
and every faith and culture plots in **its own colour**, taken from the colour
the game itself gives it on the map.

Still to come: a real y axis with numbering and gridlines, an auto-adjusting
y scale, and more than one series on screen at once.

---

## Requirements

| | |
|---|---|
| Game version | CK3 1.19.* (Scribe) - `supported_version` in `descriptor.mod`. I have not tested this mod with any other CK3 version. It might work, or it might not. |
| Debug mode | Only needed for the console commands and the `debug.log` output |
| Other mods | Touches no vanilla file. Adds its window through the `gui/scripted_widgets/` hook. I don't think it will conflict with other mods, but I have not verified that yet. |

**A played character is required to use the picker.** In Observer mode a scripted
GUI's `Execute` does not run at all, so clicking a row does nothing. This is an
engine property, not a bug in the mod. If I find a different way, I will implement that.

---

## Installing

The mod is available on the **Steam Workshop** and **GitHub**.  
- Steam Workshop: https://steamcommunity.com/sharedfiles/filedetails/?id=3802432178
- GitHub Releases: https://github.com/hilberttb/simple-graphs/releases

Do not mix different installing types. Always remove (i.e. unsubscribe or delete)
the previously installed version before getting it another way.

The instructions below are for a manual install using this GitHub repo.

The mod folder belongs at:

```
Documents/Paradox Interactive/Crusader Kings III/mod/simple-graphs/
```

The GitHub repository may also carry development material (design notes, verification
scripts, log dumps) that the game ignores, so cloning it straight to that path
works. `build-workshop.ps1` writes the same folder containing only the files
the mod actually needs.

It sits alongside a launcher descriptor `mod/simple-graphs.mod` (not to be confused with
`descriptor.mod` which is included in this repo) that points at it:

```
version="0.2.0"
name="Simple Graphs"
supported_version="1.19.*"
path="<absolute path to the mod folder>"
```

That `.mod` file lives outside the repository and is not tracked here. Enable
"Simple Graphs" in the launcher's playset.

---

## Existing saves

### Adding the mod to a campaign already in progress

This should work. The snapshot clock is started by a game-start hook and then
re-arms itself once a year from inside the save, so it does not need the mod to
have been present from day one.

**It cannot recover the years that have already passed.** The mod counts
counties as they are at the moment a snapshot fires; there is nothing in the
save for it to reconstruct earlier years from. A campaign you add it to in 1150
starts its history in 1150, and since a line needs **two** snapshots, you will
need a year of play before anything is drawn.

I have not actually tested this, so treat "should work" as exactly that. If it
does not start on its own, forcing one snapshot from the console in debug mode
(`effect sg_snapshot_collect_effect = yes`) starts the chain, and it re-arms
from there.

### Updating the mod on a save that already uses it

Safe. Updating does not disturb the data already recorded: the stored lists are
only ever appended to, and no update rewrites, reorders or deletes what is in
them. A campaign's history survives across mod versions intact.

What an update *can* do is add new things alongside it. 0.2.0 is an example.
It gives every tracked faith and culture a colour, and an older save simply picks
those up on its next snapshot rather than the moment it loads. So a save carried
forward may be missing a new feature for up to one in-game year, and then have
it permanently.

---

## Using it

1. Start a new campaign. A small round button showing a rising line sits in the
   top-right, immediately left of the **Outliner** button. Hover it for a
   tooltip.
2. Click it to open the window; click it again, or **Close**, to dismiss it.
   The window is draggable.
3. The right-hand column lists every faith and every culture that has ever held
   at least one county, with the current selection named above the list. Click
   any row to plot it. Faiths sit under a header for their **religion**,
   cultures under a header for their **heritage**, the way the ruler designer
   groups its own two lists.
4. The left-hand half is a sheet of paper carrying the graph and nothing else.
   The plot is centred on it, with the county count at each end of the line and
   in-game years along the bottom.

If the plot is empty, it says why in the middle of the sheet: either there is no
played character (see above) or the campaign has not taken two snapshots yet,
which is the minimum a line needs.

The first snapshot fires automatically on the first in-game day. Every later one
fires exactly one year later, on the same calendar day, indefinitely.
This rate is hardcoded so far. The only way to change it is to change the mod's source code.

### Reading the plot

Oldest snapshot at the left; higher means more counties. A series needs **two**
snapshots before any line appears. An object that came into existence mid-campaign
correctly starts its line where it started existing.

### Colours

Each faith and culture plots in its own colour, the one the game gives it on the
map. CK3 does not expose that colour to a mod at runtime, nothing on `Faith`,
`Culture`, `Religion` or any related type returns one, and no effect or trigger
reads one, so the mod ships a table generated from the game's own
`religion_types/` and `cultures/` files: 140 faiths and 244 cultures.

Two consequences worth knowing:

- **The colours are darkened.** Map colours are picked to be told apart as large
  filled areas, and over half of them are lighter than the paper the graph is
  drawn on. Each is scaled down until it is clearly darker than the sheet. Hue
  and saturation are untouched, so it is the same colour, just darker.
- **Anything the table cannot know gets a palette colour instead.** a faith
  reformed during the campaign, a hybrid or divergent culture, or anything added
  by another mod. Twelve colours, handed out in order and then remembered, so an
  object keeps its colour for the rest of that campaign.

### Console commands (debug mode)

```
effect sg_snapshot_collect_effect = yes
```

Forces a snapshot immediately instead of waiting a year. **This is the entry
point**. Calling `sg_c_faithculture_snapshot_effect` directly would skip the
engine's counter advance and tag its points with the previous snapshot's index.

```
effect sg_dump_effect = yes
effect sg_dump_all_effect = yes
```

Writes the stored state to `debug.log`, tagged `SIMPLE_GRAPHS_DUMP` so it can be
grepped out of a log that also has snapshot traffic. The first dumps whatever is
currently selected in the window; the second dumps every tracked faith and
culture, needs no selection, and therefore works in Observer mode too. Both
begin with the snapshot number the figures belong to.

One line per object: this snapshot's county count, the sizes of the three stored
lists, the previous plotted y, and the colour. **Not** one row per stored entry -
a script effect cannot produce that. Iterating a list of numbers puts CK3 in its
`value` scope, which cannot execute effects at all, and `debug_log` is an effect.
The savegame holds every entry in plain text if that level of detail is needed.

This replaces the debug readouts the window used to carry, which are parked in
`sg_debug_widgets.gui.bak` until they come back behind a debug-mode check.

A burst helper also exists, for stress testing. It is development scaffolding
rather than a feature, but it does ship:

```
effect sg_dev_burst_effect = { COUNT = 25 }     # COUNT is the custom amount of snapshots
effect sg_dev_burst_10 = yes                    # also _50, _200 for quick access
```

---

## What gets stored

Per faith and per culture object, persisted in the savegame:

| Name | What |
|---|---|
| `sg_faithculture_counties` | Variable list: the readable history. One entry per snapshot |
| `sg_faithculture_counties_seg` | Variable list: one packed entry per line segment |
| `sg_faithculture_years` | Variable list: the ingame year of each snapshot, for the x axis |
| `sg_faithculture_counties_now` | This snapshot's entry, read directly by the picker |
| `sg_faithculture_prev_y` | Previous snapshot's plotted y |
| `sg_faithculture_running_count` | Scratch counter for the counting pass |
| `sg_faithculture_encoded` | Legacy `base + count` value, now only feeding a debug line |
| `sg_faithculture_ever_tracked` | Sticky "has held a county" marker, gates the picker |
| `sg_faithculture_color_r` / `_g` / `_b` | This object's plot colour, one 0-1 fraction per channel |
| `sg_faithculture_group_members` | Variable list, on a **religion** or a delegate culture: that group's picker rows |

Globals:

| Name | What |
|---|---|
| `sg_snapshot_index` | 1, 2, 3 … the snapshot number |
| `sg_snapshot_base` | 10000, 20000 … the legacy scaled counter |
| `sg_snapshot_year` | The ingame year of the snapshot currently being taken |
| `sg_faith_registry` / `sg_culture_registry` | Lists of faith/culture **scopes**, rebuilt each snapshot |
| `sg_faith_registry_count` / `sg_culture_registry_count` | Sizes, for the debug line |
| `sg_religion_registry` | The religions holding at least one tracked faith — one picker header each |
| `sg_heritage_registry` | One **culture** per distinct heritage, standing in for it — see below |
| `sg_religion_registry_count` / `sg_heritage_registry_count` | Sizes, for the debug line |
| `sg_selected_faith` / `sg_selected_culture` | The current selection. Exactly one is ever set |
| `sg_color_rotor` | Next palette slot to hand out, for objects with no authored colour |
| `sg_c_faithculture_colors_stamped` | Set once the authored colour table has been applied to this save |

Entries are **not** raw counts. `add_to_variable_list` de-duplicates by value, so
a flat series would silently collapse to a single entry. All three encodings exist
to make every entry unique by construction:

```
plain    entry = value + snapshot_index * 0.0001
segment  y     = Y_MAX - clamp( round( value * Y_SCALE ), 0, Y_MAX )
         entry = snapshot_index * 1000000 + y_prev * 1000 + y_now
year     entry = snapshot_index * 10000 + year
```

The year list carries the index term for the same reason: several snapshots
forced in one sitting share a year, and a bare-year list would lose all but the
first of them.

`FixedPointToInt()` in the GUI truncates a plain entry straight back to the count.
`Y_MAX` **must be ≤ 999** — the packing uses a radix of 1000 and a y of 1000 would
carry into the previous endpoint.

---

## Performance

### Save file size

I measured this on a single campaign, paused from the start so that nothing but
the mod changed between measurements, forcing snapshots through the console:

| Snapshots taken | Save size (of the whole file) |
|---|---|
| 1 | 7,895 kb |
| 101 | 8,222 kb |
| 501 | 9,997 kb |
| 1,001 | 11,652 kb |

That works out to roughly **3.75 kb per snapshot**. For comparison, I have
unrelated long-running campaigns on the same machine well past 50,000 kb.

Some context for those numbers:

- **1,001 snapshots is not reachable in normal play.** At the current one-per-year
  rate, a full campaign from the earliest start (867) to the default end date
  (1453) is under 600 snapshots. That last row only matters if the snapshot rate
  ever changes.
- Growth is roughly, not exactly, linear: 3.27, 4.44 and 3.31 kb per snapshot
  across the three intervals. The game was paused throughout, so the middle
  interval is almost certainly compression variance rather than more data being
  written.
- Because the campaign was paused, the number of tracked faiths and cultures
  stayed fixed. A live campaign creates hybrid cultures and reformed faiths over
  time, so per-snapshot cost creeps up slowly as there are more objects to track.

History lists do still grow forever and retention capping is not built. These
numbers are why I consider that a future nicety rather than a blocker.

### Runtime

**The annual snapshot does not noticeably affect game performance.** The counting
pass is one sweep over every county per snapshot. I have not seen a hitch or a
stutter from it. Forcing many snapshots at once can cause brief lags.

**I have not measured save and load times.** I have not noticed a problem with
either, but not noticing is not the same as measuring, so treat this as untested
rather than confirmed.

**A genuinely late-game world state is untested.** The stress test above ran on a
paused campaign, which exercises the snapshot effect many times over but does not
reproduce a world decades in, with many created cultures and faiths to track. I
have no particular reason to expect trouble, but I have not verified it.

---

## Layout

Files are split into **engine** (knows nothing about any game object type) and
**consumer** (knows exactly one set of types, and always will). The prefix is
load-bearing; the folders are secondary.

```
common/
  on_action/
    sg_engine_schedule.txt          ENGINE    game-start hook
  scripted_effects/
    sg_engine_storage.txt           ENGINE    sg_engine_append_point_effect
    sg_engine_snapshot.txt          ENGINE    snapshot counters, registry helper
    sg_engine_palette.txt           ENGINE    fallback colour palette + rotor
    sg_engine_dump.txt              ENGINE    the debug dump's globals line
    sg_c_faithculture_collect.txt   consumer  every_county -> faith/culture
    sg_c_faithculture_colors.txt    consumer  GENERATED authored-colour table
    sg_c_faithculture_dump.txt      consumer  sg_dump_effect, sg_dump_all_effect
    sg_wiring.txt                   WIRING    the one file that knows both sides
    sg_dev_burst.txt                dev-only, gitignored
  scripted_guis/
    sg_c_faithculture_select.txt    consumer  the two click handlers
events/
  sg_engine_events.txt              ENGINE    the hidden scope=none snapshot event
gui/
  scripted_widgets/sg_widgets.txt             widget registration
  simple_graphs/
    sg_engine_plot.gui              ENGINE    the line template
    sg_c_faithculture_window.gui    consumer  the window
    sg_button.gui                             the floating toggle button
localization/english/
  sg_engine_l_english.yml           ENGINE
  sg_c_faithculture_l_english.yml   consumer
```

`sg_c_faithculture_colors.txt` is generated, not hand-written. It is regenerated
by a dev script that reads the colours out of the CK3 install, and needs
re-running after any game update that adds or removes faiths or cultures. A
faith the table does not know simply falls back to the palette; one the game has
removed leaves a dangling reference and an `error.log` line.

`sg_debug_widgets.gui.bak` at the repository root holds the debug widgets the
window used to show. The extension is not `.gui`, so the game never parses it,
and the root is outside what the build script copies, so it never ships.

Two rules keep that boundary strict.

1. No `sg_engine_*` file may contain the strings `faith`, `culture`, `county`,
   `title`, `character` or `dynasty`.
2. No `sg_c_*` file may be referenced by an `sg_engine_*` file. Dependencies
   point the other way only.

All script and localization files are **UTF-8 with BOM**. CK3 loads BOM-less
script anyway but logs an error per file; localization without a BOM is ignored
outright and debug lines print as raw key names.

---

## Adding another consumer

The engine takes per-object time-series storage, both encodings, the matching GUI
decode expressions, the snapshot clock and the registry pattern off a new
consumer's hands. It cannot take the **counting pass** (that *is* the metric) or
the **picker and any on-screen name** (CK3 has no polymorphic name accessor on
`Scope`, so a type must be named somewhere).

Wiring one in is a single line in `sg_wiring.txt`:

```
sg_snapshot_collect_effect = {
    sg_engine_begin_snapshot_effect = yes       # must stay first
    sg_c_faithculture_snapshot_effect = yes
    sg_c_yourthing_snapshot_effect = yes        # the new line
}
```

`sg_engine_append_point_effect` takes `VALUE_VAR`, `PLAIN_LIST`, `PLAIN_VAR`,
`SEG_LIST`, `PREV_Y_VAR`, `Y_SCALE` and `Y_MAX`. `Y_SCALE` is a per-consumer
number: it needs the range of the metric, which only the consumer knows. Pick it
against the largest value the metric can reach — if `value * Y_SCALE` exceeds
`Y_MAX`, the clamp pins every such object to the same y and silently merges
distinct series onto the top edge.

Two further engine effects, `sg_engine_clear_group_registry_effect` and
`sg_engine_register_group_member_effect`, give a picker one level of grouping:
a global list whose entries are **group** objects, plus a per-group variable
list of that group's **members**, which the GUI walks as a datamodel inside a
datamodel. Both are type-free. Working out *which* group a member belongs to
stays with the consumer, because that is the part that cannot be written
without naming a type — and the two sides of this consumer show how differently
that can go:

- **Faiths** get their group from a plain scope link, `religion`.
- **Cultures** have no such link. Nothing in 1.19 reaches a culture's heritage
  as a scope: `culture_pillar` takes a literal key, `has_cultural_pillar` takes
  a literal name, and no trigger on a pillar scope identifies it as a heritage.
  The one thing script *can* do is compare two cultures with
  `has_same_culture_heritage`. So `sg_heritage_registry` holds a **delegate** —
  the first tracked culture found carrying a given heritage, standing in for it
  — and the window names the heritage with `Culture.GetHeritage`, the hop that
  exists on the GUI side but not in script.

The storage layer works on any of the 57 CK3 object types that declare
`.MakeScope`, with no new engine support and nothing to verify per type. This was
demonstrated on `landed_title` before being backed out.

---

## Known limitations (in version 0.2.0)

- **The x axis compresses as snapshots accumulate.** The step auto-fits, so the
  series always fills the 600px plot exactly and can never leave it, however
  many snapshots there are. The trade is that spacing is not comparable between
  two objects with different history lengths. A horizontal scrollbar is
  planned, but my current attempts have failed.
- **The picker needs a played character** (Observer mode, above).
- **History lists grow forever.** One entry per faith and per culture per
  snapshot, persisted in every save. Retention capping is not built.
- **Picker rows are grouped but not sorted.** Faiths sit under their religion
  and cultures under their heritage, but within a group, and between groups,
  rows are still in registry insertion order. Unrelated to county count or
  name. CK3 datamodels have no sort, so any real ordering has to be produced
  script-side. Grouping is as far as this goes for now.
- **The groups do not collapse.** Vanilla's collapsible list widgets
  (`CollapsibleReligionList`, `CollapsibleCultureList`) are reachable only
  through `RulerDesignerWindow`, which a mod cannot instantiate, so a
  collapsible picker would need a different mechanism than the one the ruler
  designer uses. Not built.
- **A faith or culture that has never held a county never appears** in the
  picker. Collection is unaffected. Everything is still recorded.
- **There is an x axis of ingame years, but still no y axis** - only two y
  labels, giving the county count at the first and the last snapshot of the
  selected series, placed at the height of those two points. No ticks, no
  gridlines, no scale in between.
- **The y scale is fixed at 0-1000 counties** and does not adapt to the series
  being shown, so a faith with 20 counties draws as a flat line near the bottom.
- **No legend, and one series at a time.** Each series has its own colour now,
  but only one is ever on screen, so there is nothing to tell apart yet.
- **Colours are not the map colours exactly.** They are darkened so they can be
  seen on the paper, and objects created during a campaign get a palette colour
  rather than their own. See "Colours" above.
- **On a save made before 0.2.0, colours appear on the next snapshot**, not on
  load. Until then every line draws in the default ink colour.
- **Performance in a late game is unverified (see more in the performance section).**

---

## License

MIT. See `LICENSE`.

---

## Contributing

You can inform me of issues, requests, etc. by commenting on the Steam Workshop. I'd rather not get private messages about this mod, unless it's urgent.
You can also contribute by forking this repo and creating a PR, if you are comfortable with GitHub.
Within the terms of the License, you may use this mod's code for your own mod or an alternative to this one.
That means you can use the code with no restrictions, but I ask you to credit me if you do.

---

## AI Disclosure

Developed with help from Claude Code for scripting and game-file research.