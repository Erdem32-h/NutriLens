import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/config/drift/app_database.dart';
import 'package:nutrilens/features/ramadan/data/fasting_days_local_datasource.dart';

void main() {
  late AppDatabase db;
  late FastingDaysLocalDataSource ds;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ds = FastingDaysLocalDataSourceImpl(db);
  });
  tearDown(() => db.close());

  test('setFasted(true) iki kez tek satir birakir', () async {
    await ds.setFasted('u1', '2027-02-08', true);
    await ds.setFasted('u1', '2027-02-08', true);
    expect(await ds.countDays('u1'), 1);
  });

  test('setFasted(false) satiri siler', () async {
    await ds.setFasted('u1', '2027-02-08', true);
    await ds.setFasted('u1', '2027-02-08', false);
    expect(await ds.countDays('u1'), 0);
  });

  test('setFasted(false) satir yokken sessizce gecer', () async {
    await ds.setFasted('u1', '2027-02-08', false);
    expect(await ds.countDays('u1'), 0);
  });

  test('getDays yariacik aralikta kullanicinin gunlerini doner', () async {
    await ds.setFasted('u1', '2027-02-08', true);
    await ds.setFasted('u1', '2027-02-09', true);
    await ds.setFasted('u1', '2027-02-10', true);
    await ds.setFasted('u2', '2027-02-09', true);

    final days = await ds.getDays(
      'u1',
      from: '2027-02-08',
      toExclusive: '2027-02-10',
    );
    expect(days, {'2027-02-08', '2027-02-09'});
  });

  test(
    'reassignOwner misafir gunlerini tasir, cakisan gunde ikisini de tek satira birlestirir',
    () async {
      await ds.setFasted('guest', '2027-02-08', true);
      await ds.setFasted('guest', '2027-02-09', true);
      await ds.setFasted('u1', '2027-02-09', true);

      await ds.reassignOwner(fromUserId: 'guest', toUserId: 'u1');

      expect(await ds.countDays('guest'), 0);
      expect(await ds.countDays('u1'), 2);
      final days = await ds.getDays(
        'u1',
        from: '2027-02-01',
        toExclusive: '2027-03-01',
      );
      expect(days, {'2027-02-08', '2027-02-09'});
    },
  );

  test('deleteFor yalniz o kullaniciyi siler', () async {
    await ds.setFasted('u1', '2027-02-08', true);
    await ds.setFasted('u2', '2027-02-08', true);
    await ds.deleteFor('u1');
    expect(await ds.countDays('u1'), 0);
    expect(await ds.countDays('u2'), 1);
  });
}
