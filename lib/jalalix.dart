// JalaliX - Jalali (Persian / Shamsi) calendar for Dart.
///
// Algorithm matches `@jalalix/typescript@0.9.0`: base date 1348/10/11
// (= 1970-01-01), leapYearDivision = 0.24219858156.
library jalalix;

const double _leapYearDivision = 0.24219858156;
const int _dateLength = 86400000;
const int _firstDayOfWeek = 6;
const int _baseYear = 1348;
const int _baseMonth = 10;
const int _baseDay = 11;

const List<String> _weekDaysNames = [
	'شنبه',
	'یکشنبه',
	'دوشنبه',
	'سه شنبه',
	'چهار شنبه',
	'پنج شنبه',
	'جمعه',
];

const List<String> _weekDaysLetters = ['ش', 'ی', 'د', 'س', 'چ', 'پ', 'ج'];

const List<String> _weekDaysGregorianNames = [
	'Sunday',
	'Monday',
	'Tuesday',
	'Wednesday',
	'Thursday',
	'Friday',
	'Saturday',
];

const List<String> _weekDaysGregorianLetters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

const List<String> _monthsNames = [
	'فروردین',
	'اردیبهشت',
	'خرداد',
	'تیر',
	'مرداد',
	'شهریور',
	'مهر',
	'آبان',
	'آذر',
	'دی',
	'بهمن',
	'اسفند',
];

const List<String> _monthsGregorianNames = [
	'January',
	'February',
	'March',
	'April',
	'May',
	'June',
	'July',
	'August',
	'September',
	'October',
	'November',
	'December',
];

const List<String> persianNumbers = [
	'۰',
	'۱',
	'۲',
	'۳',
	'۴',
	'۵',
	'۶',
	'۷',
	'۸',
	'۹',
];

const List<String> arabicNumbers = [
	'٠',
	'١',
	'٢',
	'٣',
	'٤',
	'٥',
	'٦',
	'٧',
	'٨',
	'٩',
];

const String _am = 'ق.ظ.';
const String _pm = 'ب.ظ.';
const String _amGregorian = 'AM';
const String _pmGregorian = 'PM';

// Fixed ZoneOffset (seconds east of UTC) for embedded IANA ids.
// Iran uses permanent UTC+03:30 (no DST since 2022).
const Map<String, int> _zoneOffsetsSeconds = {
	'UTC': 0,
	'Etc/UTC': 0,
	'GMT': 0,
	'Asia/Tehran': 12600, // +03:30
	'Asia/Tokyo': 32400, // +09:00
	'Europe/London': 0, // baseline; DST not modeled in minimal embed
	'America/New_York': -18000, // EST baseline; DST not modeled
};

class _WallParts {
	final int year, month, day, hour, minute, second, ms;

	const _WallParts({
		required this.year,
		required this.month,
		required this.day,
		required this.hour,
		required this.minute,
		required this.second,
		required this.ms,
	});
}

class _JalaliDate {
	int year;
	int month;
	int day;
	int hours;
	int min;
	int sec;
	int ms;
	bool isLeapYear;

	_JalaliDate({
		this.year = _baseYear,
		this.month = _baseMonth,
		this.day = _baseDay,
		this.hours = 0,
		this.min = 0,
		this.sec = 0,
		this.ms = 0,
		this.isLeapYear = false,
	});

	_JalaliDate copy() => _JalaliDate(
				year: year,
				month: month,
				day: day,
				hours: hours,
				min: min,
				sec: sec,
				ms: ms,
				isLeapYear: isLeapYear,
			);
}

// Jalali calendar wrapper around a UTC Unix-millisecond instant + IANA zone.
class JalaliX {
	int _ms;
	String _timezone;
	late _JalaliDate _jalali;
	bool _isConverted = false;

	JalaliX._(this._ms, this._timezone) {
		_jalali = _JalaliDate();
	}

	static String _hostTimezone() {
		// Dart has no portable IANA local id; default host alias -> UTC.
		return 'UTC';
	}

	static int _offsetSeconds(String timezone, int utcMs) {
		final off = _zoneOffsetsSeconds[timezone];

		if (off == null) {
			throw ArgumentError('Invalid IANA timezone: $timezone');
		}
		return off;
	}

	static String _normalizeTimezone(String? timezone, String current) {
		if (timezone == null || timezone.isEmpty) return current;

		final lowered = timezone.trim().toLowerCase();

		if (lowered == 'default' || lowered == 'local' || lowered == 'system') {
			return _hostTimezone();
		}

		if (lowered == 'utc' || lowered == 'gmt') return 'UTC';

		if (!_zoneOffsetsSeconds.containsKey(timezone)) {
			// Accept case-insensitive match for known keys.
			for (final key in _zoneOffsetsSeconds.keys) {
				if (key.toLowerCase() == lowered) return key;
			}

			throw ArgumentError('Invalid IANA timezone: $timezone');
		}

		return timezone;
	}

	_WallParts _getWallParts() {
		final offMs = _offsetSeconds(_timezone, _ms) * 1000;
		final wallMs = _ms + offMs;
		final t = DateTime.fromMillisecondsSinceEpoch(wallMs, isUtc: true);
		final ms = ((_ms % 1000) + 1000) % 1000;

		return _WallParts(
			year: t.year,
			month: t.month,
			day: t.day,
			hour: t.hour,
			minute: t.minute,
			second: t.second,
			ms: ms,
		);
	}

	int _wallToUtc(int y, int m, int d, int h, int mi, int s, int ms) {
		final want = DateTime.utc(y, m, d, h, mi, s).millisecondsSinceEpoch;
		var utc = want;

		for (var i = 0; i < 14; i++) {
			final offMs = _offsetSeconds(_timezone, utc) * 1000;
			final gotWall = DateTime.fromMillisecondsSinceEpoch(utc + offMs, isUtc: true);

			final got = DateTime.utc(
				gotWall.year,
				gotWall.month,
				gotWall.day,
				gotWall.hour,
				gotWall.minute,
				gotWall.second,
			).millisecondsSinceEpoch;

			final diff = want - got;

			if (diff == 0) break;

			utc += diff;
		}

		return (utc ~/ 1000) * 1000 + (((ms % 1000) + 1000) % 1000);
	}

	static bool _checkLeapYear(int year) {
		if (year > 0) {
			final checkYear = (year + 2346) * _leapYearDivision;
			return checkYear - checkYear.truncateToDouble() < _leapYearDivision;
		}

		return false;
	}

	_JalaliDate _toJalali() {
		if (!_isConverted) {
			final wall = _getWallParts();

			final civilDay =
					DateTime.utc(wall.year, wall.month, wall.day).millisecondsSinceEpoch ~/
							_dateLength;

			final baseDayNum =
					DateTime.utc(1970, 1, 1).millisecondsSinceEpoch ~/ _dateLength;

			final diffDays = civilDay - baseDayNum;

			_jalali.year = _baseYear;
			_jalali.month = _baseMonth;
			_jalali.day = _baseDay;

			if (diffDays > 0) {
				for (var i = 0; i < diffDays; i++) {
					_jalali.day++;

					if (_jalali.month < 7 && _jalali.day > 31) {
						_jalali.month++;
						_jalali.day = 1;
					} else if (_jalali.month > 6 &&
							_jalali.month < 12 &&
							_jalali.day > 30) {
						_jalali.month++;
						_jalali.day = 1;
					} else if (_jalali.month == 12) {
						final isLeap = _checkLeapYear(_jalali.year);

						if (isLeap && _jalali.day > 30) {
							_jalali.year++;
							_jalali.month = 1;
							_jalali.day = 1;
						} else if (!isLeap && _jalali.day > 29) {
							_jalali.year++;
							_jalali.month = 1;
							_jalali.day = 1;
						}
					}
				}
			} else if (diffDays < 0) {
				for (var i = 0; i < -diffDays; i++) {
					_jalali.day--;

					if (_jalali.day < 1) {
						if (_jalali.month == 1) {
							_jalali.year--;
							_jalali.month = 12;
							_jalali.day = _checkLeapYear(_jalali.year) ? 30 : 29;
						} else if (_jalali.month < 8) {
							_jalali.month--;
							_jalali.day = 31;
						} else if (_jalali.month < 13) {
							_jalali.month--;
							_jalali.day = 30;
						}
					}
				}
			}

			_jalali.hours = wall.hour;
			_jalali.min = wall.minute;
			_jalali.sec = wall.second;
			_jalali.ms = wall.ms;
			_jalali.isLeapYear = _checkLeapYear(_jalali.year);
			_isConverted = true;
		}

		return _jalali;
	}

	int _toGregorian(_JalaliDate jDate) {
		final wall = _getWallParts();
		final cursor = _JalaliDate();
		var diffDays = 0;

		final afterOrEqual = jDate.year > 1348 ||
				(jDate.year == 1348 && jDate.month >= 10) ||
				(jDate.year == 1348 && jDate.month == 10 && jDate.day >= 11);

		final before = jDate.year < 1348 ||
				(jDate.year == 1348 && jDate.month < 10) ||
				(jDate.year == 1348 && jDate.month == 10 && jDate.day < 11);

		if (afterOrEqual) {
			while (true) {
				if (cursor.year == jDate.year &&
						cursor.month == jDate.month &&
						cursor.day == jDate.day) {
					break;
				}

				diffDays++;
				cursor.day++;

				if (cursor.month < 7 && cursor.day > 31) {
					cursor.month++;
					cursor.day = 1;
				} else if (cursor.month > 6 && cursor.month < 12 && cursor.day > 30) {
					cursor.month++;
					cursor.day = 1;
				} else if (cursor.month == 12) {
					final isLeap = _checkLeapYear(cursor.year);

					if (isLeap && cursor.day > 30) {
						cursor.year++;
						cursor.month = 1;
						cursor.day = 1;
					} else if (!isLeap && cursor.day > 29) {
						cursor.year++;
						cursor.month = 1;
						cursor.day = 1;
					}
				}
			}
		} else if (before) {
			while (true) {
				if (cursor.year == jDate.year &&
						cursor.month == jDate.month &&
						cursor.day == jDate.day) {
					break;
				}

				diffDays--;
				cursor.day--;

				if (cursor.day < 1) {
					if (cursor.month == 1) {
						cursor.year--;
						cursor.month = 12;
						cursor.day = _checkLeapYear(cursor.year) ? 30 : 29;
					} else if (cursor.month < 8) {
						cursor.month--;
						cursor.day = 31;
					} else if (cursor.month < 13) {
						cursor.month--;
						cursor.day = 30;
					}
				}
			}
		}

		final hours = wall.hour;
		final min = wall.minute;
		final sec = wall.second;
		final ms = wall.ms;

		final wallAsUtc =
				diffDays * _dateLength + (hours * 3600 + min * 60 + sec) * 1000 + ms;

		final civil = DateTime.fromMillisecondsSinceEpoch(wallAsUtc, isUtc: true);

		return _wallToUtc(
			civil.year,
			civil.month,
			civil.day,
			civil.hour,
			civil.minute,
			civil.second,
			civil.millisecond,
		);
	}

	_JalaliDate _reset() {
		_isConverted = false;
		_jalali.year = _baseYear;
		_jalali.month = _baseMonth;
		_jalali.day = _baseDay;

		return _toJalali();
	}

	static String _addZero(int number) {
		if (number > -1 && number < 10) return '0$number';
		return '$number';
	}

	// JS `Date.getUTCDay()`: 0=Sunday … 6=Saturday for the wall civil date.
	int _getWallWeekday() {
		final wall = _getWallParts();
		// Dart weekday: Mon=1 … Sun=7 -> JS: Sun=0 … Sat=6 via `% 7`.
		return DateTime.utc(wall.year, wall.month, wall.day).weekday % 7;
	}

	int _getGregorianDayOfYear() {
		final wall = _getWallParts();
		final start = DateTime.utc(wall.year, 1, 0); // Dec 31 previous
		final civil = DateTime.utc(wall.year, wall.month, wall.day);

		return ((civil.millisecondsSinceEpoch - start.millisecondsSinceEpoch) / _dateLength).round();
	}

	int _getGregorianWeekOfYear() {
		final wall = _getWallParts();
		var d = DateTime.utc(wall.year, wall.month, wall.day);
		final dow = d.weekday; // Mon=1 … Sun=7
		d = d.add(Duration(days: 4 - dow));
		final yearStart = DateTime.utc(d.year, 1, 1);

		return ((((d.millisecondsSinceEpoch - yearStart.millisecondsSinceEpoch) / _dateLength) + 1) / 7).ceil();
	}

	String _getWeekDayName() =>
			_weekDaysNames[(getDay() + _firstDayOfWeek) % 7];

	String _getWeekDayLetter() =>
			_weekDaysLetters[(getDay() + _firstDayOfWeek) % 7];

	int _normalizeDate(int days) {
		_ms += days * _dateLength;
		return _ms;
	}

	int _normalizeJalali(_JalaliDate jDate, int year, int month, int day) {
		if (month < 1) {
			final yearDiff = ((1 - month) / 12).ceil();
			year -= yearDiff;
			month = 12 * yearDiff + month;
		} else if (month > 12) {
			final yearDiff = ((month - 1) / 12).floor();
			year += yearDiff;
			month = month - 12 * yearDiff;
		}

		if (month > 6 && month < 12 && day > 30) {
			day = 30;
		} else if (month == 12) {
			final isLeap = _checkLeapYear(year);
			if (isLeap && day > 30) {
				day = 30;
			} else if (!isLeap && day > 29) {
				day = 29;
			}
		}

		final target = jDate.copy();
		target.year = year;
		target.month = month;
		target.day = day;
		_ms = _toGregorian(target);

		return _ms;
	}

	static int _parseInput(dynamic date) {
		if (date is JalaliX) return date._ms;
		if (date is int) return date;
		if (date is double) return date.toInt();
		if (date is DateTime) return date.toUtc().millisecondsSinceEpoch;
		if (date is String) return _parseIsoString(date);

		throw ArgumentError('JalaliX.create: unsupported date type ${date.runtimeType}');
	}

	static final _isoDateOnly = RegExp(r'^\d{4}-\d{2}-\d{2}$');

	static int _parseIsoString(String value) {
		final s = value.trim();

		if (_isoDateOnly.hasMatch(s)) {
			final p = s.split('-').map(int.parse).toList();
			return DateTime.utc(p[0], p[1], p[2]).millisecondsSinceEpoch;
		}

		var normalized = s;

		if (normalized.endsWith('Z')) {
			normalized = '${normalized.substring(0, normalized.length - 1)}+00:00';
		}

		final dt = DateTime.parse(normalized);
		return dt.toUtc().millisecondsSinceEpoch;
	}

	// Creates a JalaliX from Unix ms, ISO string, or [DateTime].
	static JalaliX create(dynamic date, [Map<String, dynamic>? options]) {
		final ms = _parseInput(date);
		var out = JalaliX._(ms, 'UTC');
		final tz = options?['timezone'];

		if (tz is String && tz.isNotEmpty) {
			out = out.setTimezone(tz);
		}

		return out;
	}

	static final _jalaliParseRe = RegExp(
		r'^(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})(?:[ T](\d{1,2}):(\d{1,2})(?::(\d{1,2}))?)?$',
	);

	static final _queryDateRe = RegExp(
		r'^(\d{4})[/\-.](\d{1,2})[/\-.](\d{1,2})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?(?:Z|[+-]\d{2}:?\d{2})?)?',
	);

	static final _fracSecondsRe = RegExp(r'(\d{2}:\d{2}:\d{2})\.\d+');

	static final _nanRe = RegExp('nan', caseSensitive: false);

	// Parses a Jalali date string (`YYYY/MM/DD` or `YYYY-MM-DD`, optional time, Persian digits).
	static JalaliX parseJalali(String value, [Map<String, dynamic>? options]) {
		final normalized = fromPersian(value).trim();
		final match = _jalaliParseRe.firstMatch(normalized);

		if (match == null) {
			throw ArgumentError('JalaliX.parseJalali: invalid Jalali date "$value"');
		}

		final year = int.parse(match.group(1)!);
		final month = int.parse(match.group(2)!);
		final day = int.parse(match.group(3)!);
		final hours = int.parse(match.group(4) ?? '0');
		final minutes = int.parse(match.group(5) ?? '0');
		final seconds = int.parse(match.group(6) ?? '0');

		if (month < 1 || month > 12 || day < 1 || day > 31) {
			throw ArgumentError('JalaliX.parseJalali: invalid Jalali date "$value"');
		}

		final output = create(DateTime.now(), options);
		output.setFullYear(year, month - 1, day);
		output.setHours(hours, minutes, seconds, 0);
		return output;
	}

	static bool isValidDate(dynamic date) {
		if (date is JalaliX) return true;
		if (date is DateTime) return true;
		if (date is int || date is double) return true;

		return false;
	}

	static String toPersian(String str) {
		var out = str;

		for (var i = 0; i <= 9; i++) {
			out = out.replaceAll('$i', persianNumbers[i]);
		}

		return out;
	}

	static String fromPersian(String str) {
		var out = str;

		for (var i = 0; i <= 9; i++) {
			out = out.replaceAll(persianNumbers[i], '$i');
			out = out.replaceAll(arabicNumbers[i], '$i');
		}

		return out;
	}

	static bool _isNumericString(String s) {
		if (s.isEmpty) return false;

		return num.tryParse(s) != null;
	}

	// Y/M/D is a valid Jalali civil date (year >= 1).
	static bool _isValidJalaliCivilDate(int year, int month, int day) {
		if (year < 1 || month < 1 || month > 12 || day < 1) return false;
		if (month <= 6) return day <= 31;
		if (month <= 11) return day <= 30;

		final isLeap = _checkLeapYear(year);

		return day <= (isLeap ? 30 : 29);
	}

	static bool _isValidGregorianDate(int year, int month, int day) {
		if (month < 1 || month > 12 || day < 1) return false;

		final d = DateTime.utc(year, month, day);

		return d.year == year && d.month == month && d.day == day;
	}

	static dynamic _normalizeQueryTimestamp(
		int timestamp,
		Map<String, dynamic>? options,
	) {
		var ts = timestamp;

		if (ts > 9999999999) ts = (ts / 1000).floor();
		if (ts <= 0) return null;

		final created = create(ts * 1000, options);

		return created.format('YYYY-MM-DD HH:mm:ss', {'calendar': 'gregorian'});
	}

	/// Soft-normalizes loose query / form date inputs into a Gregorian
	/// `Y-m-d H:i:s` string.
	///
	/// Handles empty/sentinel values (`null`, `'null'`, `''`, `'undefined'`,
	/// `'Invalid Date'`, values containing `'NaN'`), unix timestamps (seconds
	/// or milliseconds), Persian/Arabic-Indic digits, `/` `-` `.` separators,
	/// fractional seconds, optional `Z` / offset suffixes, and auto-detects
	/// Jalali vs Gregorian by year band: years in `jalaliYearMin...jalaliYearMax`
	/// (default `1...1899`) are treated as Jalali when the civil date is
	/// valid; otherwise Gregorian.
	///
	/// Invalid or unrecognized values are returned cleaned (digits normalized)
	/// rather than throwing; sentinels and non-positive timestamps return
	/// `null`. Non-`String` / non-numeric values pass through unchanged.
	///
	/// [options] may contain `timezone`, `jalaliYearMin`, `jalaliYearMax`.
	static dynamic normalizeQueryDate(
		dynamic value, [
		Map<String, dynamic>? options,
	]) {
		if (value == null) return null;

		if (value is String) {
			if (value == 'null' ||
					value == '' ||
					value == 'undefined' ||
					value.toLowerCase() == 'invalid date' ||
					_nanRe.hasMatch(value)) {
				return null;
			}
		}

		if (value is num) {
			return _normalizeQueryTimestamp(value.toInt(), options);
		}

		if (value is! String) return value;

		final trimmed = value.trim();

		if (_isNumericString(trimmed)) {
			return _normalizeQueryTimestamp(num.parse(trimmed).toInt(), options);
		}

		var digits = fromPersian(value);
		digits = digits.replaceAllMapped(
			_fracSecondsRe,
			(m) => m.group(1)!,
		);

		final match = _queryDateRe.firstMatch(digits);

		if (match == null) return digits;

		final year = int.parse(match.group(1)!);
		final month = int.parse(match.group(2)!);
		final day = int.parse(match.group(3)!);
		final hour = int.parse(match.group(4) ?? '0');
		final minute = int.parse(match.group(5) ?? '0');
		final second = int.parse(match.group(6) ?? '0');

		final jalaliYearMin = (options?['jalaliYearMin'] as int?) ?? 1;
		final jalaliYearMax = (options?['jalaliYearMax'] as int?) ?? 1899;

		if (year >= jalaliYearMin &&
				year <= jalaliYearMax &&
				_isValidJalaliCivilDate(year, month, day)) {
			try {
				final jStr =
						'${year.toString().padLeft(4, '0')}/${month.toString().padLeft(2, '0')}/${day.toString().padLeft(2, '0')} '
						'${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';

				final d = parseJalali(jStr, options);

				return d.format('YYYY-MM-DD HH:mm:ss', {'calendar': 'gregorian'});
			} catch (_) {
				// fall through to Gregorian / cleaned
			}
		}

		if (_isValidGregorianDate(year, month, day)) {
			return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')} '
					'${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
		}

		return digits;
	}

	static bool compare(JalaliX date, JalaliX comparing) =>
			date.getTime() < comparing.getTime();

	int getTime() => _ms;

	String getTimezone() => _timezone;

	JalaliX clone() {
		final out = JalaliX._(_ms, _timezone);

		return out;
	}

	// Instant-preserving: same `getTime()`, new zone id / wall display.
	JalaliX setTimezone(String? timezone) {
		final id = _normalizeTimezone(timezone, _timezone);

		return JalaliX._(_ms, id);
	}

	int getFullYear() => _toJalali().year;

	// Jalali month 1–12 (Farvardin = 1).
	int getMonth() => _toJalali().month;

	int getDate() => _toJalali().day;

	int getDay() =>
			(_getWallWeekday() - _firstDayOfWeek + 7 + 1) % 7;

	int getHours() => _getWallParts().hour;
	int getMinutes() => _getWallParts().minute;
	int getSeconds() => _getWallParts().second;
	int getMilliseconds() => ((_ms % 1000) + 1000) % 1000;

	int getDayOfYear() {
		final j = _toJalali();
		if (j.month < 7) return j.day + (j.month - 1) * 31;
		if (j.month < 12) return j.day + 186 + (j.month - 7) * 30;

		return j.day + 336;
	}

	int getDayISO() => ((getDay() + 6) % 7) + 1;

	int getWeekOfYear() {
		final dayOfYear = getDayOfYear();
		final dayOfWeek = clone().getStartOfYear().getDayISO();

		return ((dayOfYear + dayOfWeek - 1) / 7).ceil();
	}

	int getHoursISO() {
		final hours = getHours();

		return hours > 12 ? hours - 12 : hours;
	}

	String getMeridiem() => _toJalali().hours > 12 ? _pm : _am;

	String _getGregorianMeridiem() =>
			getHours() >= 12 ? _pmGregorian : _amGregorian;

	int setTime(int time) {
		_ms = time;
		_reset();

		return _ms;
	}

	int setMilliseconds(int ms) {
		final w = _getWallParts();
		_ms = _wallToUtc(w.year, w.month, w.day, w.hour, w.minute, w.second, ms);
		_reset();

		return _ms;
	}

	int setSeconds(int sec, [int? ms]) {
		final w = _getWallParts();
		_ms = _wallToUtc(
				w.year, w.month, w.day, w.hour, w.minute, sec, ms ?? w.ms);
		_reset();

		return _ms;
	}

	int setMinutes(int min, [int? sec, int? ms]) {
		final w = _getWallParts();
		_ms = _wallToUtc(w.year, w.month, w.day, w.hour, min, sec ?? w.second,
				ms ?? w.ms);
		_reset();

		return _ms;
	}

	int setHours(int hours, [int? min, int? sec, int? ms]) {
		final w = _getWallParts();
		_ms = _wallToUtc(w.year, w.month, w.day, hours, min ?? w.minute,
				sec ?? w.second, ms ?? w.ms);
		_reset();

		return _ms;
	}

	int setDate(int date) {
		final j = _toJalali();
		_normalizeDate(date - j.day);

		return _ms;
	}

	// Month is 0–11 (Farvardin = 0), matching JS `Date` / TypeScript.
	int setMonth(int month, [int? date]) {
		final j = _toJalali();
		_normalizeJalali(j, j.year, month + 1, j.day);
		_reset();

		if (date != null) {
			final j2 = _toJalali();
			_normalizeDate(date - j2.day);
			_reset();
		}

		return _ms;
	}

	// Optional [month] is 0–11 (Farvardin = 0).
	int setFullYear(int year, [int? month, int? date]) {
		final j = _toJalali();
		_normalizeJalali(j, year, month != null ? month + 1 : j.month, j.day);
		_reset();

		if (date != null) {
			final j2 = _toJalali();
			_normalizeDate(date - j2.day);
			_reset();
		}

		return _ms;
	}

	JalaliX addYears(int year) {
		final j = _toJalali();
		_normalizeJalali(j, j.year + year, j.month, j.day);
		_reset();

		return this;
	}

	JalaliX addMonths(int month) {
		final j = _toJalali();
		_normalizeJalali(j, j.year, j.month + month, j.day);
		_reset();

		return this;
	}

	JalaliX addWeeks(int weeks) {
		_normalizeDate(weeks * 7);
		_reset();

		return this;
	}

	JalaliX addDays(int days) {
		_normalizeDate(days);
		_reset();

		return this;
	}

	JalaliX getStartOfYear() =>
			addDays(-1 * getDayOfYear() + 1).getStartOfDay();

	JalaliX getStartOfMonth() =>
			addDays(-1 * getDate() + 1).getStartOfDay();

	JalaliX getStartOfWeek() =>
			addDays(-1 * getDayISO() + 1).getStartOfDay();

	JalaliX getStartOfDay() {
		setHours(0, 0, 0, 0);

		return this;
	}

	JalaliX getEndOfYear() {
		final j = _toJalali();
		final lastDay = j.isLeapYear ? 366 : 365;

		return addDays(lastDay - getDayOfYear()).getEndOfDay();
	}

	JalaliX getEndOfMonth() {
		final j = _toJalali();
		var lastDay = 31;

		if (j.month > 6 && j.month < 12) {
			lastDay = 30;
		} else if (j.month == 12) {
			lastDay = j.isLeapYear ? 30 : 29;
		}

		return addDays(lastDay - getDate()).getEndOfDay();
	}

	JalaliX getEndOfWeek() => addDays(7 - getDayISO()).getEndOfDay();

	JalaliX getEndOfDay() {
		setHours(23, 59, 59, 999);

		return this;
	}

	String toISODate([String calendar = 'gregorian']) {
		if (calendar == 'jalali') return format('YYYY-MM-DD');

		final wall = _getWallParts();

		return '${wall.year}-${_addZero(wall.month)}-${_addZero(wall.day)}';
	}

	// Formats with pattern. Pass a map `{calendar, persianDigits}` or positional bools.
	String format(String str, [dynamic persianOrOptions, bool? gregorian]) {
		var persian = false;
		var useGregorian = false;

		if (persianOrOptions is Map) {
			persian = persianOrOptions['persianDigits'] == true;
			useGregorian = persianOrOptions['calendar'] == 'gregorian';
		} else if (persianOrOptions is bool) {
			persian = persianOrOptions;
			useGregorian = gregorian == true;
		}

		final placeholders = <String>[];

		String ph(String val) {
			final i = placeholders.length;
			placeholders.add(val);
			return '\uE000$i\uE001';
		}

		var output = str;
		final wall = _getWallParts();
		var year = useGregorian ? wall.year : getFullYear();
		var month = useGregorian ? wall.month : getMonth();

		var weekOfYear =
				useGregorian ? _getGregorianWeekOfYear() : getWeekOfYear();

		var dayOfYear =
				useGregorian ? _getGregorianDayOfYear() : getDayOfYear();

		var date = useGregorian ? wall.day : getDate();

		var monthName =
				useGregorian ? _monthsGregorianNames[month - 1] : _monthsNames[month - 1];

		var weekDayName = useGregorian
				? _weekDaysGregorianNames[_getWallWeekday()]
				: _getWeekDayName();

		var weekDayLetter = useGregorian
				? _weekDaysGregorianLetters[_getWallWeekday()]
				: _getWeekDayLetter();

		var meridiem =
				useGregorian ? _getGregorianMeridiem() : getMeridiem();

		final yearStr = '$year';

		void replaceToken(String token, String Function() make) {
			if (output.contains(token)) {
				output = output.replaceAll(token, make());
			}
		}

		replaceToken('YYYY', () => ph(yearStr));
		replaceToken('YYY', () => ph(_sliceEnd(yearStr, 3)));
		replaceToken('YY', () => ph(_sliceEnd(yearStr, 2)));
		replaceToken('Y', () => ph(_sliceEnd(yearStr, 1)));
		replaceToken('MMM', () => ph(monthName));
		replaceToken('MM', () => ph(_addZero(month)));
		replaceToken('M', () => ph('$month'));
		replaceToken('W', () => ph(_addZero(weekOfYear)));
		replaceToken('w', () => ph('$weekOfYear'));
		replaceToken('DW', () => ph('${getDayISO()}'));

		replaceToken('dw', () {
			if (useGregorian) {
				final d = _getWallWeekday();
				return ph('${d == 0 ? 7 : d}');
			}
			return ph('${getDay()}');
		});

		replaceToken('WN', () => ph(weekDayName));
		replaceToken('wn', () => ph(weekDayName));
		replaceToken('WL', () => ph(weekDayLetter));
		replaceToken('wl', () => ph(weekDayLetter));
		replaceToken('DDDD', () => ph(_addZero(dayOfYear)));
		replaceToken('DDD', () => ph('$dayOfYear'));
		replaceToken('DD', () => ph(_addZero(date)));
		replaceToken('D', () => ph('$date'));

		final hours = getHours();
		replaceToken('HH', () => ph(_addZero(hours)));
		replaceToken('H', () => ph('$hours'));
		final hoursISO = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
		replaceToken('hh', () => ph(_addZero(hoursISO)));
		replaceToken('h', () => ph('$hoursISO'));
		replaceToken('mm', () => ph(_addZero(getMinutes())));
		replaceToken('m', () => ph('${getMinutes()}'));
		replaceToken('ss', () => ph(_addZero(getSeconds())));
		replaceToken('s', () => ph('${getSeconds()}'));
		replaceToken('sss', () => ph('${getMilliseconds()}'));
		replaceToken('SSS', () => ph('${getMilliseconds()}'));
		replaceToken('A', () => ph(meridiem));
		replaceToken('a', () => ph(meridiem));
		replaceToken('X', () => ph('${getTime() ~/ 1000}'));
		replaceToken('x', () => ph('${getTime()}'));

		for (var i = 0; i < placeholders.length; i++) {
			output = output.replaceAll('\uE000$i\uE001', placeholders[i]);
		}

		return persian ? toPersian(output) : output;
	}

	static String _sliceEnd(String s, int n) =>
			s.length <= n ? s : s.substring(s.length - n);

	@override
	String toString() {
		final j = _toJalali();

		final asUtc = DateTime.utc(
			_getWallParts().year,
			_getWallParts().month,
			_getWallParts().day,
			_getWallParts().hour,
			_getWallParts().minute,
			_getWallParts().second,
			_getWallParts().ms,
		).millisecondsSinceEpoch;

		final offsetMin = ((asUtc - _ms) / 60000).round();
		final sign = offsetMin >= 0 ? '+' : '-';
		final abs = offsetMin.abs();

		final tz =
				' GMT$sign${_addZero(abs ~/ 60)}${_addZero(abs % 60)}';

		return '${_getWeekDayName()} ${_addZero(j.day)} ${_monthsNames[j.month - 1]} ${_addZero(j.year)} ${j.hours}:${_addZero(j.min)}:${_addZero(j.sec)}$tz';
	}
}
