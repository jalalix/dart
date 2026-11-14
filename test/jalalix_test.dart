import 'dart:convert';
import 'dart:io';

import 'package:jalalix/jalalix.dart';
import 'package:test/test.dart';

JalaliX createFrom(Map<String, dynamic> spec) {
  if (spec.containsKey('unixMs')) {
    var d = JalaliX.create(spec['unixMs'] as int);

    if (spec['timezone'] != null) {
      d = d.setTimezone(spec['timezone'] as String);
    }

    return d;
  }

  return JalaliX.create(spec['isoDate'] as String);
}

void main() {
  final goldenFile = File('testdata/golden.json');

  final golden =
      jsonDecode(goldenFile.readAsStringSync()) as Map<String, dynamic>;

  group('calendar', () {
    for (final raw in golden['calendar'] as List) {
      final c = raw as Map<String, dynamic>;

      test(c['id'] as String, () {
        final d = createFrom(c['create'] as Map<String, dynamic>);
        final expectMap = c['expect'] as Map<String, dynamic>;
        expect(d.format('YYYY/MM/DD'), expectMap['formatYYYYMMDD']);
        expect(d.toISODate(), expectMap['toISODateGregorian']);
        expect(d.toISODate('jalali'), expectMap['toISODateJalali']);
      });
    }
  });

  group('parse', () {
    for (final raw in golden['parse'] as List) {
      final c = raw as Map<String, dynamic>;

      test(c['id'] as String, () {
        final d = JalaliX.parseJalali(c['input'] as String);
        final expectMap = c['expect'] as Map<String, dynamic>;
        expect(d.toISODate(), expectMap['toISODateGregorian']);

        if (expectMap['formatYYYYMMDD'] != null) {
          expect(d.format('YYYY/MM/DD'), expectMap['formatYYYYMMDD']);
        }
      });
    }
  });

  group('format', () {
    for (final raw in golden['format'] as List) {
      final c = raw as Map<String, dynamic>;

      test(c['id'] as String? ?? 'persian_helpers', () {
        if (c['toPersian'] != null) {
          final tp = c['toPersian'] as Map<String, dynamic>;
          final fp = c['fromPersian'] as Map<String, dynamic>;
          expect(JalaliX.toPersian(tp['input'] as String), tp['expect']);
          expect(JalaliX.fromPersian(fp['input'] as String), fp['expect']);
          return;
        }

        final d = createFrom(c['create'] as Map<String, dynamic>);

        expect(
          d.format(c['pattern'] as String, c['options'] as Map),
          c['expect'],
        );
      });
    }
  });

  group('timezone', () {
    for (final raw in golden['timezone'] as List) {
      final c = raw as Map<String, dynamic>;

      test(c['id'] as String, () {
        if (c['setTimezoneAlias'] != null) {
          final d = JalaliX.create(c['unixMs'] as int)
              .setTimezone(c['setTimezoneAlias'] as String);

          expect(d.getTimezone(), c['expectTimezone']);
          return;
        }

        final d = JalaliX.create(c['unixMs'] as int)
            .setTimezone(c['withTimezone'] as String);

        final ex = c['expect'] as Map<String, dynamic>;
        expect(d.format('YYYY/MM/DD'), ex['jalaliSlash']);

        if (ex['jalaliIso'] != null) {
          expect(d.toISODate('jalali'), ex['jalaliIso']);
        }

        if (ex['wallGregorian'] != null) {
          expect(d.toISODate(), ex['wallGregorian']);
        }

        expect(d.getHours(), ex['hours']);
        expect(d.getMinutes(), ex['minutes']);

        if (ex['getTime'] != null) {
          expect(d.getTime(), ex['getTime']);
        }
      });
    }
  });

  group('mutations', () {
    for (final raw in golden['mutations'] as List) {
      final c = raw as Map<String, dynamic>;

      test(c['id'] as String, () {
        var d = createFrom(c['create'] as Map<String, dynamic>);
        final expectMap = c['expect'] as Map<String, dynamic>;

        if (c['setFullYear'] != null) {
          final sf = c['setFullYear'] as Map<String, dynamic>;
          d.setFullYear(sf['year'] as int, sf['month0'] as int, sf['day'] as int);
          expect(d.getMonth(), expectMap['getMonth']);
          expect(d.format('YYYY/MM/DD'), expectMap['formatYYYYMMDD']);
          return;
        }

        for (final op in c['ops'] as List) {
          final s = op as String;

          if (s.startsWith('addMonths:')) {
            d = d.addMonths(int.parse(s.split(':')[1]));
          } else if (s == 'getStartOfMonth') {
            d = d.getStartOfMonth();
          }
        }

        expect(d.format('YYYY/MM/DD'), expectMap['formatYYYYMMDD']);
      });
    }
  });
}
