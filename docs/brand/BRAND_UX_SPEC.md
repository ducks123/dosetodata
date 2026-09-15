# Dose to Data Interface Brand Spec

Version 1.0 · For the agent implementing brand alignment in the app.
Companion to `Dose_to_Data_Visual_Identity.pdf` (the brand guidelines).

---

## 0. Read this before you change anything

The brand guidelines are a **marketing** system. This document is the **interface**
translation of it. They are not the same, and applying the marketing system literally to
the app will break the product.

The single most important rule in the entire brand system:

> **The interface is light. The dark navy field belongs to marketing, not to the product.**
> Deep Navy is type and primary actions inside the app. It is not the app background.

If you find yourself setting the app's background to `#0F1A3E` in light mode, stop. That is
the marketing field the phone sits *on* in an ad, not the screen.

**Scope of this work:** color tokens, typography roles, component styling, chart styling,
and state colors. **Not** in scope: information architecture, navigation structure, feature
changes, copy rewrites, or layout restructuring. If a change you are considering alters what
a screen does rather than how it looks, stop and ask.

---

## 1. The six non-negotiables

1. **Light interface.** Paper and white surfaces, Deep Navy type. Dark mode is a separate
   theme, defined in section 2.
2. **One accent per surface.** Never two accent colors competing in one view.
3. **Warm on dark, cool on light.** Signal Orange is the accent on dark surfaces only.
   Iris Deep is the accent on light surfaces. This maps cleanly onto dark mode and light
   mode, which is why the accent token changes between themes.
4. **Signal Orange is never type on a light surface.** It reads 1.93:1 on Paper. It may be
   a *fill* with Deep Navy type on top.
5. **No hue outside orange, iris and neutral.** Green and red exist only as system state
   feedback. They never become decorative or brand colors.
6. **Controls are defined by fill, not by outline.** A hairline is decorative separation
   only. Never let a 1px border be the only thing that makes a control visible.

---

## 2. Design tokens

Implement these as **semantic** tokens. Do not scatter raw hex through the codebase, and do
not name tokens after their color (`blue500`); name them after their job (`accent`). Every
value below is contrast-verified; the ratio is given so you can confirm your implementation.

### Light theme

| Token | Hex | Role | Contrast |
|---|---|---|---|
| `surface` | `#F8F9FA` | Screen background | base |
| `surface-raised` | `#FFFFFF` | Cards, sheets, rows | base |
| `surface-sunken` | `#F1F3F7` | Unselected control fills, inset wells | base |
| `text-primary` | `#0F1A3E` | Headings, values, labels | 16.1:1 |
| `text-secondary` | `#5A6478` | Supporting copy, units, captions | 5.65:1 |
| `text-tertiary` | `#626D82` | Timestamps, metadata. Use sparingly | 4.94:1 |
| `text-disabled` | `#98A2B8` | Placeholder and disabled only | exempt |
| `accent` | `#2F5FB8` | Links, selected state, interactive text | 5.77:1 |
| `on-accent` | `#FFFFFF` | Type on an accent fill | 6.09:1 |
| `action-primary` | `#0F1A3E` | Primary button fill | 16.1:1 |
| `on-action-primary` | `#F8F9FA` | Primary button label | 16.1:1 |
| `separator` | `#E4E7EC` | Hairlines between rows. Decorative only | exempt |
| `data-1` | `#548CE8` | Primary chart series | 3.17:1 |
| `data-2` | `#5588DC` | Comparison series. See note below | 3.35:1 |
| `data-marker` | `#0F1A3E` | Dose-change markers, axis emphasis | 16.1:1 |
| `data-current` | `#FE9F5E` | Current value point only. See §6 | needs ring |
| `success` | `#0F7B4F` | Positive delta, confirmation | 5.02:1 |
| `error` | `#A32E2E` | Negative delta, validation | 6.67:1 |

### Dark theme

| Token | Hex | Role | Contrast |
|---|---|---|---|
| `surface` | `#0F1A3E` | Screen background | base |
| `surface-raised` | `#17234B` | Cards, sheets, rows | base |
| `surface-sunken` | `#0B1330` | Inset wells | base |
| `text-primary` | `#F8F9FA` | Headings, values, labels | 16.1:1 |
| `text-secondary` | `#98A2B8` | Supporting copy, units, captions | 6.62:1 |
| `text-tertiary` | `#7A86A0` | Timestamps, metadata | 4.64:1 |
| `accent` | `#FE9F5E` | Links, selected state, interactive text | 8.35:1 |
| `on-accent` | `#0F1A3E` | Type on an accent fill | 8.35:1 |
| `action-primary` | `#FE9F5E` | Primary button fill | 8.35:1 |
| `on-action-primary` | `#0F1A3E` | Primary button label | 8.35:1 |
| `separator` | `#25315C` | Hairlines | exempt |
| `data-1` | `#548CE8` | Primary chart series | 5.09:1 |
| `data-2` | `#82ADFB` | Comparison series | 7.53:1 |
| `data-marker` | `#F8F9FA` | Dose-change markers | 16.1:1 |
| `data-current` | `#FE9F5E` | Current value point only | 8.35:1 |
| `success` | `#4ADE9B` | Positive delta | 9.87:1 |
| `error` | `#FF8A8A` | Negative delta | 7.48:1 |

**Three notes on why these differ from the brand PDF.** The guidelines are written for
marketing surfaces, where large type and big shapes carry more contrast headroom than a
2px chart line does. Three values needed interface-specific corrections:

- **`data-2` in light mode is `#5588DC`, not Sky `#82ADFB`.** Sky reads 2.14:1 on Paper,
  below the 3:1 minimum for a graphical object. Sky stays correct on dark surfaces and in
  marketing. Same hue family, so nothing about the brand changes.
- **`data-current` (Signal Orange) needs a ring on light surfaces.** See §6.
- **`text-tertiary` in light mode is `#626D82`.** Do not use `#98A2B8` as readable text on
  a light surface; it reads 2.43:1 and is for placeholder and disabled states only.

---

## 3. Typography

**The app uses the platform system face throughout. Do not add Poppins to the app.**

Poppins is the marketing display face. It appears in ads and App Store screenshots, not in
the product. Using the system face means Dynamic Type, accessibility settings and language
fallbacks all work correctly, which matters more here than typographic consistency with the
marketing layer.

| Role | Weight | Notes |
|---|---|---|
| Screen title | Bold | Platform default large-title size |
| Section head | Semibold | |
| Row label | Semibold | |
| Body, supporting | Regular | |
| Numeric values | Bold, **tabular** | Required, see below |
| Eyebrow, overline | Semibold, uppercase, tracked | Use sparingly |

**Tabular numerals are mandatory** for every score, dose, date, percentage and streak
count. Without them, values shift horizontally as they change and the whole interface
twitches during updates. Set the numeric font feature explicitly rather than relying on the
default.

**Support Dynamic Type.** Do not hard-code font sizes. Every layout must survive the largest
accessibility text size without truncating a value or clipping a row.

---

## 4. Surfaces and layout

- Screen background is `surface`. Content sits in `surface-raised` cards.
- Cards: 20 to 28pt corner radius, generous internal padding, separated by consistent
  vertical rhythm. Prefer a soft shadow or a `separator` hairline to define a card, not a
  heavy border.
- Rows inside a card are separated by `separator` hairlines that stop short of the card's
  horizontal padding, in the standard platform inset style.
- Never nest a raised surface inside a raised surface. If content needs a third level, use
  `surface-sunken` as an inset well.

---

## 5. Components

### Buttons
- **Primary:** `action-primary` fill, `on-action-primary` label, full width in sheets and
  at the bottom of scroll views. One per screen.
- **Secondary:** `surface-raised` fill with a `separator` border and `text-primary` label.
- **Tertiary / text button:** `accent` label, no fill.
- Minimum tap target 44 x 44pt regardless of visual size.

### Selection controls (segmented, rating scales, chips)
- Unselected: `surface-sunken` fill, `text-secondary` label.
- Selected: `action-primary` fill, `on-action-primary` label.
- The selected state must be distinguishable **without** relying on color alone. The fill
  change carries it here, which satisfies that. Do not replace the fill with a colored
  outline or a colored label only.

### Toggles
- On: `data-1` track. Off: a neutral track from `surface-sunken` darkened, never a red one.

### Checkmarks and completion
- Completed: `success` fill with a white glyph.
- Incomplete: `surface-raised` fill with a 2 to 3pt `text-disabled` ring.
- Do not use `accent` for completion. Completion is a state, not an action.

---

## 6. Charts

This is where the brand is most visible in the product, and where it is easiest to get
wrong. Read this section fully before touching any chart code.

**Series and roles**
- `data-1` is the primary series. Solid stroke, 2.5 to 3pt.
- `data-2` is the comparison or previous-period series. Dashed stroke, 2pt. **Dashed is
  required**, not decorative: it is what distinguishes the series for a color-blind user.
- `data-marker` is a vertical rule marking a dose change, plus a filled point where it meets
  the primary series.
- `data-current` marks the **current value only**. It is a single point. It is never a
  series, never a fill, never a stroke, and never appears more than once per chart.

**The Signal Orange ring.** `data-current` reads 1.93:1 against a white or Paper surface, so
the point cannot carry its own contrast. Draw it as a Signal Orange fill with a 2pt
`data-marker` ring around it. The ring supplies the contrast; the orange supplies the brand.
Do not substitute a white ring on a light surface, which was the mistake in the first draft.

**Area fills.** The primary series may carry a vertical gradient fill from `data-1` at 20%
opacity down to 0%. No other series gets a fill. Never use the Warm or Cool marketing
gradients inside a chart.

**Gridlines and axes.** `separator` weight, dashed for intermediate lines, solid for the
baseline. Axis labels use `text-tertiary`.

**Never encode meaning in color alone.** Every series needs a second cue: line style, a
direct label, or a legend with shape swatches that match the marks. A user who cannot
distinguish `data-1` from `data-2` by hue must still be able to read the chart.

**Deltas.** A positive change uses `success`, a negative uses `error`, and both are
accompanied by a `+` or `-` sign so the sign carries the meaning, not the color.

---

## 7. Accessibility requirements

These are acceptance criteria, not aspirations.

- Body and label text: **4.5:1** minimum against its actual background.
- Large text (roughly 24pt+, or 19pt+ bold): **3:1** minimum.
- Graphical objects that convey information, including chart strokes, icons and control
  boundaries: **3:1** minimum.
- Tap targets: **44 x 44pt** minimum.
- Dynamic Type: all text scales, no clipping at the largest size.
- Color is never the sole carrier of meaning anywhere in the app.
- Test both themes. A token that passes in light mode is not assumed to pass in dark.

---

## 8. Screens that appear in marketing

These five screens are used in App Store screenshots and paid social, so they carry an extra
constraint: they must read clearly when scaled down inside a device frame and cropped at the
bottom edge.

1. Insights, week view with the score chart
2. Weekly summary with the day strip
3. The record, dose changes and what followed
4. Today's check-in
5. What you track

For these screens specifically: keep the most meaningful content in the **top two thirds**,
avoid placing a critical value within 200pt of the bottom of the scroll view, and make sure
the screen looks complete rather than empty when it is only partially visible. This is a
composition constraint only. Do not change what these screens do.

---

## 9. Do not do

- **Do not** make the app background navy in light mode.
- **Do not** add Poppins, or any custom font, to the app.
- **Do not** use Signal Orange as text, as a chart series, or as a button fill in light mode.
- **Do not** use the Warm or Cool marketing gradients as screen or card backgrounds. They
  are marketing fields. The one permitted use inside the product is a subtle informational
  callout card, at the Lavender `#DCE4FB` flat tint, never as a gradient.
- **Do not** introduce a new hue, including a "brand purple," a warning amber, or a chart
  palette of five colors. If a chart needs more than two series, ask before inventing colors.
- **Do not** remove or genericize real medication names from the product. The rule against
  showing real drug names applies to **advertising creative only**, because of Meta's health
  and personal attribute policy. Inside the app, real names are the entire point. Do not
  propagate a marketing constraint into the product.
- **Do not** restyle anything not covered here without asking. Ambiguity is a question, not
  a judgment call.

---

## 10. Acceptance checklist

Work through this before reporting the task complete. Check each item against the running
app, not against the code.

**Tokens**
- [ ] No raw hex outside the token definitions.
- [ ] Tokens are named by role, not by color.
- [ ] Both light and dark themes are fully defined; no token falls back to a platform default.

**Contrast** (measure, do not estimate)
- [ ] Every text style meets 4.5:1, or 3:1 if it qualifies as large.
- [ ] Every chart stroke meets 3:1 against its surface, **in both themes**.
- [ ] The `data-current` point has its `data-marker` ring in light mode.

**Type**
- [ ] No custom font is bundled or referenced.
- [ ] Every numeric value uses tabular figures.
- [ ] Layouts hold at the largest Dynamic Type size with no clipping.

**Components**
- [ ] One primary button per screen, maximum.
- [ ] Selection states are carried by fill, not by color of label or border alone.
- [ ] All tap targets are at least 44 x 44pt.

**Charts**
- [ ] The comparison series is dashed.
- [ ] Signal Orange appears exactly once per chart, as the current point.
- [ ] No marketing gradient appears inside any chart.
- [ ] Every chart is legible in greyscale.

**Scope**
- [ ] No navigation, IA, feature or copy changes were made.
- [ ] Real medication names are still present in the product.
- [ ] Anything ambiguous was raised as a question rather than decided unilaterally.

---

## 11. Report back

When finished, provide:

1. Before and after screenshots of all five marketing screens, **in both themes**.
2. The measured contrast ratio for every token pairing you introduced or changed.
3. A list of anything in this spec that conflicted with the existing codebase, and what you
   did about it.
4. A list of decisions you made that this spec did not cover.
