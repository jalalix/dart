# JalaliX (Dart)

Jalali (Persian / Shamsi) calendar library. Pure Dart — no runtime dependencies.

[![pub package](https://img.shields.io/pub/v/jalalix.svg)](https://pub.dev/packages/jalalix)
[![license](https://img.shields.io/github/license/jalalix/dart.svg)](./LICENSE)

```yaml
dependencies:
    jalalix: ^0.1.0
```

```dart
import 'package:jalalix/jalalix.dart';

final date = JalaliX.create('2025-02-25');

date.format('YYYY/MM/DD'); // 1403/12/07
date.format('DD MMM YYYY', {'persianDigits': true}); // ۰۷ اسفند ۱۴۰۳

JalaliX.parseJalali('1403/12/07').toISODate(); // 2025-02-25
```

Algorithm matches `@jalalix/typescript@0.8.0`: base date **1348/10/11** (= 1970-01-01), `leapYearDivision = 0.24219858156`.

`toISODate()` uses wall-clock getters in the active timezone. Prefer it when you need a calendar date string without UTC shift surprises.

## Timezone

Internal storage is a **UTC Unix millisecond instant** plus an IANA timezone id. `setTimezone` is **instant-preserving**: the timestamp stays the same; wall clock / Jalali day may change.

```dart
final d = JalaliX.create(1740430800000);

final tehran = d.setTimezone('Asia/Tehran');
tehran.format('YYYY/MM/DD'); // 1403/12/07
tehran.format('HH:mm:ss');   // 00:30:00

final utc = d.setTimezone('UTC');
utc.format('YYYY/MM/DD'); // 1403/12/06
utc.format('HH:mm:ss');   // 21:00:00

tehran.getTime() == utc.getTime(); // true
```

- **Aliases:** `utc` / `gmt` -> `UTC`; `local` / `default` / `system` -> `UTC` (portable host default).
- **Invalid zone** -> throws.
- Embedded fixed offsets for `UTC`, `Etc/UTC`, `Asia/Tehran` (+03:30), plus a few extras. Iran’s permanent +03:30 (no DST since 2022) covers golden / production Tehran cases.

```dart
JalaliX.create(DateTime.now(), {'timezone': 'Asia/Tehran'});
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
```

### toISODate

```dart
final d = JalaliX.create('2025-02-25');

d.toISODate();         // 2025-02-25
d.toISODate('jalali'); // 1403-12-07
```

### add / start / end

```dart
JalaliX.create('2025-02-25').addMonths(1).getStartOfMonth().format('YYYY/MM/DD');
```

### Persian digits

```dart
JalaliX.toPersian('1403/12/07');   // ۱۴۰۳/۱۲/۰۷
JalaliX.fromPersian('۱۴۰۳/۱۲/۰۷'); // 1403/12/07
```

## Months

Easy to get wrong:

- `getMonth()` -> 1..12 (Farvardin = 1)
- `setMonth(m)` / `setFullYear(y, m)` -> 0..11, same as JS `Date` (Farvardin = 0)

```dart
final d = JalaliX.create(DateTime.now());
d.setFullYear(1404, 0, 1); // 1 Farvardin 1404
d.getMonth(); // 1
```

## Format tokens

| Token               |                                 |
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

Static:

- `create(date, options?)` — ms, ISO string, or `DateTime`
- `parseJalali(str, options?)`
- `isValidDate(value)`
- `toPersian(str)` / `fromPersian(str)`
- `compare(a, b)` — true if `a` is before `b`

Instance (main ones):

- `format(...)`, `toISODate(calendar?)`
- `getFullYear()`, `getMonth()`, `getDate()`, `getDay()`, …
- `setFullYear`, `setMonth`, `setDate`, `setHours`, …
- `addYears`, `addMonths`, `addWeeks`, `addDays`
- `getStartOfYear` / `Month` / `Week` / `Day` and matching `getEndOf*`
- `clone()`, `setTimezone(tz)`, `getTimezone()`

Method names match the TypeScript package (camelCase).

## Links

- https://jalalix.com
- https://github.com/jalalix/dart
- [CHANGELOG.md](./CHANGELOG.md)

## License

MIT
