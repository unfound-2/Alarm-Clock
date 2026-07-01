import '../../domain/entities/alarm.dart';

class BlePayloads {
  const BlePayloads._();

  static List<int> uint32(int value) {
    final normalized = value & 0xFFFFFFFF;
    return [
      (normalized >> 24) & 0xFF,
      (normalized >> 16) & 0xFF,
      (normalized >> 8) & 0xFF,
      normalized & 0xFF,
    ];
  }

  static List<int> currentEpochSeconds([DateTime? now]) {
    final timestamp = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000;
    return uint32(timestamp);
  }

  static List<int> alarm(Alarm alarm) {
    return [
      alarm.id & 0xFF,
      alarm.hour & 0xFF,
      alarm.minute & 0xFF,
      alarm.dayMask & 0xFF,
      alarm.qrRequired ? 1 : 0,
    ];
  }

  static List<int> clockSettings({
    required bool autoDim,
    required int sleepStartHour,
    required int sleepStartMinute,
    required int sleepEndHour,
    required int sleepEndMinute,
  }) {
    return [
      autoDim ? 1 : 0,
      sleepStartHour & 0xFF,
      sleepStartMinute & 0xFF,
      sleepEndHour & 0xFF,
      sleepEndMinute & 0xFF,
    ];
  }
}
