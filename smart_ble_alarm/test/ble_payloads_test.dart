import 'package:flutter_test/flutter_test.dart';
import 'package:smart_ble_alarm/core/ble/ble_payloads.dart';
import 'package:smart_ble_alarm/domain/entities/alarm.dart';

void main() {
  group('BlePayloads', () {
    test('encodes uint32 values big-endian for clock firmware', () {
      expect(BlePayloads.uint32(0x12345678), [0x12, 0x34, 0x56, 0x78]);
    });

    test('encodes alarm payload according to the HM-10 protocol', () {
      const alarm = Alarm(
        id: 7,
        hour: 6,
        minute: 45,
        dayMask: 0x80 | 0x3E,
        qrRequired: true,
      );

      expect(BlePayloads.alarm(alarm), [7, 6, 45, 0xBE, 1]);
    });

    test('encodes clock settings payload with minute precision', () {
      expect(
        BlePayloads.clockSettings(
          autoDim: true,
          sleepStartHour: 22,
          sleepStartMinute: 30,
          sleepEndHour: 6,
          sleepEndMinute: 15,
        ),
        [1, 22, 30, 6, 15],
      );
    });
  });
}
