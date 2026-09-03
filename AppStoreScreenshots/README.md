# Dose to Data App Store Screenshots

The final 6.5-inch iPhone screenshots are in `final/` at 1242 x 2688 pixels.

Recommended order:

1. `01-clear-trends.png` - daily data becomes understandable, with medication changes labeled on the chart.
2. `02-fast-check-in.png` - customizable check-ins built around the user's own questions.
3. `03-medication-context.png` - today's score and weekly medication adherence in one view.
4. `04-medication-schedule.png` - medication reminders shown alongside the daily schedule.
5. `05-appointment-picture.png` - one daily score built from the user's chosen metrics.

The raw simulator captures are kept in `raw/`. Re-render the final set from the
repository root with:

```sh
swift AppStoreScreenshots/render.swift
```

Apple places App Preview videos before screenshots on iPhone, even when they are
rearranged in App Store Connect. Keep this screenshot-led set without a video if
the trends message should remain first. If a video is added later, use the same
visual system and design its poster frame to carry that opening message.
