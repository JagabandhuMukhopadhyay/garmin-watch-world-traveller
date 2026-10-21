# JM-Garmin-v1: Multi-Flight Travel Watch Face (Forerunner 965)

Status: draft spec. Items marked **[ASSUMPTION]** are my proposals and need confirming. Items under "Open questions" are undecided.

## 1. Purpose

A watch face for travel days that involve up to two plane changes. It shows the local time at each stop on the route, plus the boarding time for each flight the traveller still has to catch.

## 2. Target

| Item | Value |
|---|---|
| Device | Garmin Forerunner 965 (`fr965`) |
| App type | Watch face (Connect IQ, Monkey C) |
| Display | 454 x 454 round AMOLED **[ASSUMPTION: confirm against the SDK device profile]** |
| Min API level | Currently 1.2.0 in `manifest.xml`. **[ASSUMPTION]** Raise it to the level the fr965 supports, so that settings and modern APIs are available. |
| Permissions | None expected. All data comes from the system clock and user settings. |

## 3. Route model

The route has 3 or 4 points, in this order:

| # | Point | Time zone clock | Boarding time |
|---|---|---|---|
| 1 | Start | Yes | Yes |
| 2 | Change 1 | Yes | Yes |
| 3 | Change 2 (optional) | Yes | Yes |
| 4 | Destination | Yes | No (journey ends) |

- Change 2 is optional. If it is unused, the face shows 3 zones (Start, Change 1, Destination).
- If Change 1 is also unused, the face shows 2 zones. This is a fallback and not a stated requirement.
- Each point has a short label (e.g. an IATA code like `SIN`) so the layout stays compact.

## 4. Display requirements

For each active point, show:

1. Label (Start / Change 1 / Change 2 / Destination, or the user's code)
2. Current local time at that point
3. Boarding time (Start, Change 1, Change 2 only), in that point's local time

Other requirements:

- Current time of the wearer's own location is not required separately. Start is expected to serve this role. **[ASSUMPTION]**
- Layout must remain readable with 4 rows on a round screen. Rows near the top and bottom edges must stay inside the circle.
- Flight-passed behaviour **[ASSUMPTION]**: once a boarding time has passed, dim or hide it so only upcoming boardings stand out.
- Optional extras, only if space allows: battery %, date. Not required for v1.

## 5. Configuration

A watch face cannot take typed input on the watch. Configuration is through Connect IQ settings, edited in the Garmin Connect app (or the simulator's settings editor).

Settings resources (`resources/settings/settings.xml` and `properties.xml`) are to be added. Per point:

| Setting | Type | Notes |
|---|---|---|
| Label | string | Short code, e.g. `SIN` |
| UTC offset | number or list | Offset of that location. See the DST note below. |
| Boarding time | string | Local time at that airport. Format is an open question. Connect IQ settings have no native date-time picker. |
| Enabled | boolean | Needed for Change 2 (and possibly Change 1). |

**DST note:** Monkey C has no time zone database, so the face cannot look up DST by city. The user supplies the UTC offset that applies on the travel date. Offsets must allow half-hour and 45-minute zones (e.g. India +5:30, Nepal +5:45), so store offsets in minutes or as a list.

## 6. Time logic

- Read the current instant once per update with `Time.now()` and derive each zone from it as UTC + that zone's offset. Do not rely on `System.getClockTime()` for the other zones, since that is only the watch's own local time.
- Boarding time is entered in the airport's local time and compared against that zone's current time, so "time remaining" is correct whichever zone the watch is in.
- Boarding time needs a date as well as a time, because journeys can cross midnight.

## 7. Power and AMOLED behaviour

- The fr965 is AMOLED. In low-power (always-on) mode, the face must lit only a small share of pixels and should shift content slightly to avoid burn-in. Check the current Garmin watch face guidelines for the exact limits.
- In low power the system calls `onUpdate` about once per minute, so seconds must not be shown in that mode.
- High-power mode (after a wrist gesture) can show richer detail.
- Hooks already stubbed in [source/JagaGarmin1View.mc](source/JagaGarmin1View.mc): `onExitSleep` and `onEnterSleep`.

## 8. Implementation plan (files)

| File | Change |
|---|---|
| `manifest.xml` | Raise `minApiLevel` if needed. Edit through the extension commands, not by hand. |
| `resources/settings/settings.xml`, `properties.xml` | New. Define the per-point settings above. |
| `resources/strings/strings.xml` | Setting titles, default labels. |
| `resources/layouts/layout.xml` | Replace the single `TimeLabel` with rows for each point. Or draw custom in `onUpdate`. |
| `source/JagaGarmin1View.mc` | Read settings, compute per-zone times, draw rows, handle low-power mode. |
| `source/JagaGarmin1App.mc` | Add `onSettingsChanged()` to redraw when the user edits settings. |

## 9. Testing

- Run in the Connect IQ simulator for `fr965` and use its settings editor to enter sample routes.
- Cases to cover: 4-point route, 3-point route, half-hour offsets, boarding time crossing midnight, boarding time already passed, low-power rendering.
- Also test on the real watch, because AMOLED burn-in and legibility cannot be judged in the simulator.

## 10. Open questions

1. Should the user be able to set the route on the phone only (Garmin Connect settings), or is any on-watch interaction wanted?
2. Boarding time format: a text string `YYYY-MM-DD HH:MM`, or separate date and time fields?
3. Should the face show a countdown ("boards in 2h 15m") alongside, or instead of, the boarding clock time?
4. Is Start's time meant to be the watch's own local time, or a separately configured zone?
5. 12-hour or 24-hour display?
6. Any colour preferences per point?
