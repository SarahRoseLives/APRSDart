import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../../models/aprs_packet.dart';

/// A controller to manage the Bluetooth connection and data stream for a Mobilinkd TNC.
class MobilinkdController extends ChangeNotifier {
  final BluetoothDevice device;
  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _streamSubscription;
  Uint8List _rxBuffer = Uint8List(0);

  // List of parsed packets for the UI
  final ValueNotifier<List<AprsPacket>> aprsPackets = ValueNotifier([]);
  final List<AprsPacket> _internalPacketList = [];


  bool _isConnected = false;
  bool get isConnected => _isConnected;

  MobilinkdController({required this.device});

  /// Establishes a Bluetooth connection to the Mobilinkd device.
  Future<void> connect() async {
    if (_isConnected) return;
    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _isConnected = true;
      if (kDebugMode) {
        print('[MobilinkdController] Connected to ${device.name}');
      }
      notifyListeners();

      _streamSubscription = _connection!.input!.listen(
        _onDataReceived,
        onDone: () {
          if (kDebugMode) {
            print('[MobilinkdController] Disconnected by remote host.');
          }
          dispose();
        },
        onError: (error) {
           if (kDebugMode) {
            print('[MobilinkdController] Connection error: $error');
          }
          dispose();
        }
      );
    } catch (e) {
      if (kDebugMode) {
        print('[MobilinkdController] Cannot connect to the device: $e');
      }
      _isConnected = false;
      notifyListeners();
      rethrow;
    }
  }

  /// Buffers incoming data and attempts to process it as KISS frames.
  void _onDataReceived(Uint8List data) {
    _rxBuffer = Uint8List.fromList([..._rxBuffer, ...data]);
    _processKISSFrames();
  }

  /// Parses the KISS protocol frames from the buffer.
  void _processKISSFrames() {
    const int fend = 0xC0; // Frame End
    const int fesc = 0xDB; // Frame Escape
    const int tfend = 0xDC; // Transposed Frame End
    const int tfesc = 0xDD; // Transposed Frame Escape

    while (true) {
      int frameStart = _rxBuffer.indexOf(fend);
      if (frameStart == -1) return;

      if (frameStart > 0) {
        _rxBuffer = _rxBuffer.sublist(frameStart);
      }

      int frameEnd = _rxBuffer.indexOf(fend, 1);
      if (frameEnd == -1) return;

      final frameWithCmd = _rxBuffer.sublist(1, frameEnd);
      _rxBuffer = _rxBuffer.sublist(frameEnd + 1);

      if (frameWithCmd.isEmpty) continue;

      // We only care about command 0x00 (data frames)
      if ((frameWithCmd[0] & 0x0F) == 0) {
        final rawAx25 = frameWithCmd.sublist(1);
        final builder = BytesBuilder();
        for (int i = 0; i < rawAx25.length; i++) {
          if (rawAx25[i] == fesc) {
            i++;
            if (i < rawAx25.length) {
              if (rawAx25[i] == tfend) {
                builder.addByte(fend);
              } else if (rawAx25[i] == tfesc) {
                builder.addByte(fesc);
              }
            }
          } else {
            builder.addByte(rawAx25[i]);
          }
        }

        try {
          final newPacket = AprsPacket.fromAX25Frame(builder.toBytes());
          if (newPacket.latitude != null && newPacket.longitude != null) {
            final existingIndex = _internalPacketList.indexWhere((p) => p.source == newPacket.source);
            if (existingIndex != -1) {
              _internalPacketList[existingIndex] = newPacket;
            } else {
              _internalPacketList.add(newPacket);
            }
            if (_internalPacketList.length > 200) {
              _internalPacketList.removeAt(0);
            }
            aprsPackets.value = List.from(_internalPacketList);
          }
        } catch (e) {
          if (kDebugMode) {
            print("[MobilinkdController] Failed to parse AX.25 frame: $e");
          }
        }
      }
    }
  }

  /// Closes the connection and cleans up resources.
  @override
  void dispose() {
    if (!_isConnected && _connection == null) {
      super.dispose();
      return;
    }
    _isConnected = false;
    final connectionToClose = _connection;
    final subscriptionToCancel = _streamSubscription;
    _connection = null;
    _streamSubscription = null;
    subscriptionToCancel?.cancel();
    connectionToClose?.close();
    if (kDebugMode) {
      print('[MobilinkdController] Connection disposed.');
    }
    notifyListeners();
    super.dispose();
  }
}