# JalaliX - Dart

Jalali (Persian / Shamsi) calendar on top of a millisecond Unix timestamp. Pure Dart - no runtime dependencies.

[![pub package](https://img.shields.io/pub/v/jalalix.svg)](https://pub.dev/packages/jalalix)
[![license](https://img.shields.io/github/license/jalalix/dart.svg)](./LICENSE)

```yaml
dependencies:
    jalalix: ^0.2.0
```

```dart
import 'package:jalalix/jalalix.dart';

final date = JalaliX.create('2025-02-25');

date.format('YYYY/MM/DD'); // 1403/12/07
date.format('DD MMM YYYY', {'persianDigits': true}); // ۰۷ اسفند ۱۴۰۳

JalaliX.parseJalali('1403/12/07').toISODate(); // 2025-02-25
```

`toISODate()` uses wall-clock getters in the active timezone. Prefer it over UTC-based formatting when you need a calendar date string.

## Install

```yaml
dependencies:
    jalalix: ^0.2.0
```

```dart
import 'package:jalalix/jalalix.dart';
```

## Usage

### create / format

```dart
final now = JalaliX.create(DateTime.now(), {'timezone': 'Asia/Tehran'});

now.format('YYYY/MM/DD');
now.format('WN، DD MMM YYYY');
now.format('YYYY/MM/DD', {'persianDigits': true});
now.format('DD MMM YYYY', {'calendar': 'gregorian'});
```

`format` also accepts the older positional form: `format(str, persianDigits?, gregorian?)`.

### parseJalali

```dart
JalaliX.parseJalali('1403/12/07');
JalaliX.parseJalali('۱۴۰۳-۱۲-۰۷ 14:30');
JalaliX.parseJalali('1403.12.07');
```

Accepts `/`, `-`, or `.` as the date separator.

### normalizeQueryDate

Soft-normalize loose query / form date values to Gregorian `Y-m-d H:i:s` (or `null`). Does not throw on junk input.

```dart
JalaliX.normalizeQueryDate('1403/12/07', {'timezone': 'Asia/Tehran'});
// '2025-02-25 00:00:00'

JalaliX.normalizeQueryDate('undefined'); // null
JalaliX.normalizeQueryDate(1740430800000, {'timezone': 'Asia/Tehran'});
// '2025-02-25 00:30:00'
```

Handles sentinels (`null`, `''`, `'null'`, `'undefined'`, `'Invalid Date'`, `NaN`) → `null`; unix timestamps (seconds or milliseconds; non-positive → `null`); Persian/Arabic-Indic digits; `/` `-` `.` separators; fractional seconds.

Detects Jalali when the year is in `jalaliYearMin`…`jalaliYearMax` (default `1`…`1899`) **and** the civil date is valid; otherwise Gregorian when valid, or returns the digit-cleaned string. Non-string/non-number values pass through unchanged.

### toISODate

```dart
final d = JalaliX.create('2025-02-25T00:30:00+03:30');

d.toISODate();         // 2025-02-25
d.toISODate('jalali'); // 1403-12-07
```

### add / start / end

```dart
JalaliX.create('2025-02-25').addMonths(1).getStartOfMonth().format('YYYY/MM/DD');
// e.g. 1404/01/01

final d = JalaliX.create('2025-02-25', {'timezone': 'Asia/Tehran'});
d.addDays(7).format('YYYY/MM/DD');
d.getEndOfWeek().format('YYYY/MM/DD');
```

### Persian / Arabic digits

```dart
JalaliX.toPersian('1403/12/07');   // ۱۴۰۳/۱۲/۰۷
JalaliX.fromPersian('۱۴۰۳/۱۲/۰۷'); // 1403/12/07
JalaliX.fromPersian('١٤٠٣/١٢/٠٧'); // 1403/12/07 (Arabic-Indic)
```

## Timezone

Internal storage is always a **UTC Unix millisecond instant** plus an IANA timezone id. `setTimezone` is **instant-preserving**: the timestamp stays the same; only the zone (and therefore wall clock / Jalali day) changes.

```dart
final d = JalaliX.create(1740430800000); // 2025-02-25T00:30:00+03:30

final tehran = d.setTimezone('Asia/Tehran');
tehran.format('YYYY/MM/DD'); // 1403/12/07
tehran.format('HH:mm');    // 00:30

final utc = d.setTimezone('UTC');
utc.format('YYYY/MM/DD'); // 1403/12/06
utc.format('HH:mm');    // 21:00

tehran.getTime() == utc.getTime(); // true
```

- **Aliases:** `utc` / `gmt` → `UTC`; `local` / `default` / `system` → `UTC` (portable host default).
- **Invalid zone** → throws `ArgumentError`.
- Embedded fixed offsets for `UTC`, `Etc/UTC`, `Asia/Tehran` (+03:30), plus a few extras. Iran's permanent +03:30 (no DST since 2022) covers golden / production Tehran cases.

```dart
JalaliX.create(DateTime.now(), {'timezone': 'Asia/Tehran'});
```

## Months

Easy to get wrong:

- `getMonth()` → **1…12** (Farvardin = 1)
- `setMonth(m)` / `setFullYear(y, m)` → **0…11**, same as JS `Date` (Farvardin = 0)

```dart
final d = JalaliX.create(DateTime.now());
d.setFullYear(1404, 0, 1); // 1 Farvardin 1404
d.getMonth(); // 1
```

## Format tokens

| Token               | Meaning                         |
| ------------------- | ------------------------------- |
| `YYYY` `YY`         | year                            |
| `MMM` `MM` `M`      | month name / number             |
| `DD` `D`            | day                             |
| `HH` `hh` `mm` `ss` | time                            |
| `A` `a`             | meridiem (ق.ظ. / ب.ظ. or AM/PM) |
| `WN` `WL`           | weekday name / letter           |
| `w` `DDD`           | week of year / day of year      |
| `X` `x`             | unix seconds / ms               |

## API

Method names match the TypeScript package (camelCase).

### Top-level constants

| API              | Description                                    |
| ---------------- | ---------------------------------------------- |
| `persianNumbers` | List of Persian digit characters `۰`…`۹`.      |
| `arabicNumbers`  | List of Arabic-Indic digit characters `٠`…`٩`. |

### Static (`JalaliX`)

| API                                   | Description                                                                                                                        |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| `create(date, options?)`              | Build from unix ms, ISO/`YYYY-MM-DD` string, or `DateTime`. Optional `{'timezone': String}`.                                       |
| `parseJalali(str, options?)`          | Parse a Jalali date/time string (`/` `-` `.`, Persian/Arabic digits, optional time).                                               |
| `normalizeQueryDate(value, options?)` | Soft-normalize loose query/form values → Gregorian `Y-m-d H:i:s` or `null`. Options: `timezone`, `jalaliYearMin`, `jalaliYearMax`. |
| `isValidDate(value)`                  | `true` for `JalaliX`, `DateTime`, or numeric timestamp types.                                                                      |
| `toPersian(str)`                      | Replace Western digits `0-9` with Persian `۰-۹`.                                                                                   |
| `fromPersian(str)`                    | Replace Persian `۰-۹` and Arabic-Indic `٠-٩` with Western digits.                                                                  |
| `compare(a, b)`                       | `true` if `a` is strictly before `b` (by unix ms).                                                                                 |

### Instance - getters

| API                                                                  | Description                                            |
| -------------------------------------------------------------------- | ------------------------------------------------------ |
| `getFullYear()`                                                      | Jalali year in the active timezone.                    |
| `getMonth()`                                                         | Jalali month **1…12** (Farvardin = 1).                 |
| `getDate()`                                                          | Jalali day of month **1…31**.                          |
| `getDay()`                                                           | Weekday **1…7** (Saturday = 1 … Friday = 7).           |
| `getHours()` / `getMinutes()` / `getSeconds()` / `getMilliseconds()` | Wall-clock time in the active timezone.                |
| `getTime()`                                                          | Unix timestamp in milliseconds (UTC instant).          |
| `getTimezone()`                                                      | Active IANA timezone id.                               |
| `getWeekOfYear()`                                                    | Jalali week-of-year (1-based).                         |
| `getDayOfYear()`                                                     | Day of Jalali year (1…365/366).                        |
| `getDayISO()`                                                        | ISO-style weekday index used internally for week math. |
| `getHoursISO()`                                                      | Hours in 0…23 for formatting helpers.                  |
| `getMeridiem()`                                                      | Localized meridiem string (ق.ظ./ب.ظ.).                 |

### Instance - setters

| API                                | Description                                              |
| ---------------------------------- | -------------------------------------------------------- |
| `setTime(ms)`                      | Set the UTC instant from unix milliseconds.              |
| `setMilliseconds(ms)`              | Set milliseconds (wall clock).                           |
| `setSeconds(sec, ms?)`             | Set seconds (and optional ms).                           |
| `setMinutes(min, sec?, ms?)`       | Set minutes (and optional lower units).                  |
| `setHours(h, min?, sec?, ms?)`     | Set hours (and optional lower units).                    |
| `setDate(day)`                     | Set Jalali day of month.                                 |
| `setMonth(month, date?)`           | Set Jalali month **0…11** (Farvardin = 0); optional day. |
| `setFullYear(year, month?, date?)` | Set Jalali year; optional month **0…11** and day.        |
| `setTimezone(tz)`                  | Instant-preserving zone change; returns a new instance.  |

### Instance - math, range, format

| API                                                                               | Description                                                                           |
| --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------- |
| `addYears(n)` / `addMonths(n)` / `addWeeks(n)` / `addDays(n)`                     | Add calendar units; mutate and return `this`.                                         |
| `getStartOfYear()` / `getStartOfMonth()` / `getStartOfWeek()` / `getStartOfDay()` | Start of unit (`this`).                                                               |
| `getEndOfYear()` / `getEndOfMonth()` / `getEndOfWeek()` / `getEndOfDay()`         | End of unit (`this`).                                                                 |
| `format(str, options?)`                                                           | Format with tokens above; map `{'calendar', 'persianDigits'}` or positional booleans. |
| `toISODate(calendar?)`                                                            | `YYYY-MM-DD` in `'gregorian'` (default) or `'jalali'`.                                |
| `clone()`                                                                         | Copy with the same instant and timezone.                                              |
| `toString()`                                                                      | String view of the date/time (overrides `Object.toString`).                           |

## Links

- https://pub.dev/packages/jalalix
- https://jalalix.com
- https://github.com/jalalix/dart
- [CHANGELOG.md](./CHANGELOG.md)

## License

MIT
