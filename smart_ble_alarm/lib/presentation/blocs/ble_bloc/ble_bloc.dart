import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../../domain/repositories/ble_repository.dart';
import 'ble_event.dart';
import 'ble_state.dart';

class BleConnectionBloc extends Bloc<BleEvent, BleState> {
  final BleRepository bleRepository;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  Timer? _scanTimeoutTimer;
  Timer? _reconnectTimer;
  BluetoothDevice? _connectedDevice;
  String? _autoReconnectDeviceId;

  BleConnectionBloc({required this.bleRepository}) : super(BleDisconnected()) {
    on<StartScanEvent>(_onStartScan);
    on<StopScanEvent>(_onStopScan);
    on<DeviceFoundEvent>(_onDeviceFound);
    on<ConnectionStateChangedEvent>(_onConnectionStateChanged);
    on<ToggleSimulationEvent>(_onToggleSimulation);
    on<AutoConnectEvent>(_onAutoConnect);
    on<ScanTimedOutEvent>(_onScanTimedOut);
  }

  void _onStartScan(StartScanEvent event, Emitter<BleState> emit) async {
    _autoReconnectDeviceId = null;
    _reconnectTimer?.cancel();
    emit(BleScanning());

    _scanSubscription?.cancel();
    _scanSubscription = bleRepository.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (_isTargetClock(r)) {
          add(DeviceFoundEvent(r.device));
          break;
        }
      }
    });

    try {
      _startScanTimeout();
      await bleRepository.startScan();
    } catch (e) {
      _scanTimeoutTimer?.cancel();
      emit(BleDisconnected());
    }
  }

  void _onStopScan(StopScanEvent event, Emitter<BleState> emit) async {
    _scanTimeoutTimer?.cancel();
    await bleRepository.stopScan();
    if (state is BleScanning) {
      emit(BleDisconnected());
    }
  }

  void _onAutoConnect(AutoConnectEvent event, Emitter<BleState> emit) async {
    _autoReconnectDeviceId = event.deviceId;
    _reconnectTimer?.cancel();

    if (event.deviceId == 'simulated_device') {
      final device = BluetoothDevice.fromId('simulated_device');
      _connectedDevice = device;

      _connectionSubscription?.cancel();
      _connectionSubscription = bleRepository.connectionState(device).listen((
        connectionState,
      ) {
        add(ConnectionStateChangedEvent(connectionState));
      });

      try {
        await bleRepository.connectToDevice(device);
      } catch (e) {
        emit(BleDisconnected());
      }
      return;
    }

    emit(BleConnecting());

    _scanSubscription?.cancel();
    _scanSubscription = bleRepository.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.remoteId.str == event.deviceId) {
          add(DeviceFoundEvent(r.device));
          break;
        }
      }
    });

    try {
      _startScanTimeout();
      await bleRepository.startScan();
    } catch (e) {
      _scanTimeoutTimer?.cancel();
      emit(BleDisconnected());
    }
  }

  void _onDeviceFound(DeviceFoundEvent event, Emitter<BleState> emit) async {
    _scanTimeoutTimer?.cancel();
    await bleRepository.stopScan();
    emit(BleConnecting());

    _connectedDevice = event.device;
    _connectionSubscription?.cancel();
    _connectionSubscription = bleRepository
        .connectionState(event.device)
        .listen((connectionState) {
          add(ConnectionStateChangedEvent(connectionState));
        });

    try {
      await bleRepository.connectToDevice(event.device);
    } catch (e) {
      emit(BleDisconnected());
    }
  }

  void _onConnectionStateChanged(
    ConnectionStateChangedEvent event,
    Emitter<BleState> emit,
  ) {
    if (event.state == BluetoothConnectionState.connected &&
        _connectedDevice != null) {
      _reconnectTimer?.cancel();
      emit(BleConnected(_connectedDevice!));
    } else if (event.state == BluetoothConnectionState.disconnected) {
      final reconnectId =
          _autoReconnectDeviceId ?? _connectedDevice?.remoteId.str;
      _connectedDevice = null;
      emit(BleDisconnected());
      if (reconnectId != null) {
        _scheduleReconnect(reconnectId);
      }
    }
  }

  void _onToggleSimulation(
    ToggleSimulationEvent event,
    Emitter<BleState> emit,
  ) {
    if (state is BleConnected &&
        _connectedDevice?.remoteId.str == 'simulated_device') {
      bleRepository.disconnectFromDevice(_connectedDevice!);
    } else {
      add(const AutoConnectEvent('simulated_device'));
    }
  }

  void _onScanTimedOut(ScanTimedOutEvent event, Emitter<BleState> emit) async {
    if (state is BleScanning || state is BleConnecting) {
      await bleRepository.stopScan();
      emit(BleDisconnected());
      if (_autoReconnectDeviceId != null) {
        _scheduleReconnect(_autoReconnectDeviceId!);
      }
    }
  }

  bool _isTargetClock(ScanResult result) {
    final platformName = result.device.platformName.toLowerCase();
    final advertisedName = result.advertisementData.advName.toLowerCase();
    final serviceUuids = result.advertisementData.serviceUuids
        .map((uuid) => uuid.toString().toUpperCase())
        .join(',');

    return platformName.contains('hm-10') ||
        platformName.contains('hmsoft') ||
        platformName.contains('smart clock') ||
        advertisedName.contains('hm-10') ||
        advertisedName.contains('hmsoft') ||
        advertisedName.contains('smart clock') ||
        serviceUuids.contains('FFE0');
  }

  void _startScanTimeout() {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = Timer(const Duration(seconds: 16), () {
      add(ScanTimedOutEvent());
    });
  }

  void _scheduleReconnect(String deviceId) {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (!isClosed) add(AutoConnectEvent(deviceId));
    });
  }

  @override
  Future<void> close() {
    _scanTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    return super.close();
  }
}
