import 'package:jalalix/jalalix.dart';
import 'package:test/test.dart';

void main() {
	group('fromPersian / toPersian digits', () {
		test('converts persian and arabic-indic digits', () {
			expect(JalaliX.toPersian('1403/12/07'), '۱۴۰۳/۱۲/۰۷');
			expect(JalaliX.fromPersian('۱۴۰۳/۱۲/۰۷'), '1403/12/07');
			expect(JalaliX.fromPersian('١٤٠٣/١٢/٠٧'), '1403/12/07');
		});
	});

	group('parseJalali dot separator', () {
		test('accepts . as separator', () {
			expect(JalaliX.parseJalali('1403.12.07').toISODate(), '2025-02-25');
		});
	});

	group('normalizeQueryDate sentinels and timestamps', () {
		test('sentinels return null', () {
			expect(JalaliX.normalizeQueryDate(null), isNull);
			expect(JalaliX.normalizeQueryDate('null'), isNull);
			expect(JalaliX.normalizeQueryDate(''), isNull);
			expect(JalaliX.normalizeQueryDate('undefined'), isNull);
			expect(JalaliX.normalizeQueryDate('Invalid Date'), isNull);
			expect(JalaliX.normalizeQueryDate('NaN'), isNull);
			expect(JalaliX.normalizeQueryDate(0), isNull);
			expect(JalaliX.normalizeQueryDate(-1), isNull);
		});

		test('unix seconds / milliseconds with timezone', () {
			const seconds = 1740430800; // 2025-02-24 21:00:00 UTC / 2025-02-25 00:30:00 Tehran

			expect(
				JalaliX.normalizeQueryDate(seconds, {'timezone': 'UTC'}),
				'2025-02-24 21:00:00',
			);

			expect(
				JalaliX.normalizeQueryDate(seconds * 1000, {'timezone': 'Asia/Tehran'}),
				'2025-02-25 00:30:00',
			);
		});
	});

	group('normalizeQueryDate Jalali and Gregorian', () {
		test('detects Jalali vs Gregorian by year band', () {
			expect(
				JalaliX.normalizeQueryDate('1403/12/07', {'timezone': 'UTC'}),
				'2025-02-25 00:00:00',
			);

			expect(
				JalaliX.normalizeQueryDate('۱۴۰۳-۱۲-۰۷ 14:30:00', {'timezone': 'UTC'}),
				'2025-02-25 14:30:00',
			);

			expect(JalaliX.normalizeQueryDate('2025.02.25'), '2025-02-25 00:00:00');

			expect(
				JalaliX.normalizeQueryDate('2025-02-25 12:30:45.123Z'),
				'2025-02-25 12:30:45',
			);

			expect(JalaliX.normalizeQueryDate('not-a-date'), 'not-a-date');

			// Wider default band than the old 1278-1600 heuristic.
			expect(
				JalaliX.normalizeQueryDate('1200/01/01', {'timezone': 'UTC'}),
				isNotNull,
			);

			expect(
				JalaliX.normalizeQueryDate('1800/01/01', {'timezone': 'UTC'}),
				isNotNull,
			);

			// Gregorian years stay Gregorian; override bounds when needed.
			expect(JalaliX.normalizeQueryDate('2025-01-01'), '2025-01-01 00:00:00');

			expect(
				JalaliX.normalizeQueryDate('2025-01-01', {
					'timezone': 'UTC',
					'jalaliYearMin': 1,
					'jalaliYearMax': 3000,
				}),
				isNot('2025-01-01 00:00:00'),
			);
		});
	});
}
