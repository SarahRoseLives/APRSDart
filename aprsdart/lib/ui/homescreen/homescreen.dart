import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../../tnc/benshi/radio_controller.dart';
import '../../tnc/mobilinkd/mobilinkd_controller.dart';
import '../map/map.dart';
import '../packets/packets.dart'; // <-- Import the new packets screen

// Enum to manage connection state for clarity
enum ConnectionStatus { disconnected, connecting, connected }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ConnectionStatus _status = ConnectionStatus.disconnected;
  BluetoothDevice? _selectedDevice;
  ChangeNotifier? _activeController; // Can hold either RadioController or MobilinkdController

  @override
  void dispose() {
    _disconnect();
    super.dispose();
  }

  /// Shows a dialog to select a bonded Bluetooth device and then connects to it.
  Future<void> _selectAndConnect() async {
    // Show device selection dialog
    final BluetoothDevice? device = await showDialog<BluetoothDevice>(
      context: context,
      builder: (context) {
        return FutureBuilder<List<BluetoothDevice>>(
          future: FlutterBluetoothSerial.instance.getBondedDevices(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SimpleDialog(
                title: Text('Searching for Devices...'),
                children: [Center(child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ))],
              );
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return SimpleDialog(
                title: const Text('No Paired Devices Found'),
                children: [
                  const ListTile(
                    subtitle: Text('Please pair your TNC in your phone\'s Bluetooth settings first.'),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('OK')),
                  )
                ],
              );
            }

            return SimpleDialog(
              title: const Text('Choose Bluetooth TNC'),
              children: snapshot.data!.map((device) {
                return SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context, device);
                  },
                  child: Text('${device.name ?? 'Unknown Device'} (${device.address})'),
                );
              }).toList(),
            );
          },
        );
      },
    );

    if (device == null) return; // User cancelled the dialog

    setState(() {
      _status = ConnectionStatus.connecting;
      _selectedDevice = device;
      // Disconnect any previous connection before starting a new one
      _activeController?.dispose();
      _activeController = null;
    });

    try {
      final deviceName = device.name ?? '';
      // Identify the device and initialize the appropriate controller
      if (deviceName.contains('Mobilinkd TNC')) {
        debugPrint('Device identified as Mobilinkd. Initializing MobilinkdController...');
        final controller = MobilinkdController(device: device);
        await controller.connect();
        _activeController = controller;
      } else if (deviceName.contains('VR-N76')) {
        debugPrint('Device identified as Benshi (VR-N76). Initializing RadioController...');
        final controller = RadioController(device: device);
        await controller.connect();
        _activeController = controller;
      } else {
        throw Exception('Unsupported device: $deviceName');
      }

      setState(() {
        _status = ConnectionStatus.connected;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully connected to ${device.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      debugPrint('Connection failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      _disconnect(); // Reset state on failure
    }
  }

  /// Disconnects from the active device and resets the UI state.
  void _disconnect() {
    _activeController?.dispose();
    setState(() {
      _status = ConnectionStatus.disconnected;
      _selectedDevice = null;
      _activeController = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Branding header
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.primaryContainer,
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.radio, size: 72, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(
                  'APRSDart',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Modern APRS for Dart & Flutter',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildStatusCard(),
          const SizedBox(height: 16),

          // Main navigation buttons
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(24),
              mainAxisSpacing: 24,
              crossAxisSpacing: 24,
              children: [
                _HomeNavButton(
                  icon: Icons.map,
                  label: 'Map',
                  onTap: () {
                    if (_status == ConnectionStatus.connected && _activeController != null) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => MapScreen(controller: _activeController!),
                      ));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please connect to a TNC first.')),
                      );
                    }
                  },
                ),
                _HomeNavButton(
                  icon: Icons.message,
                  label: 'Messages',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Messages pressed (Not implemented)')),
                    );
                  },
                ),
                _HomeNavButton(
                  icon: Icons.settings,
                  label: 'Settings',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings pressed (Not implemented)')),
                    );
                  },
                ),
                // ---- KEY CHANGE: "About" button is now "Packets" button ----
                _HomeNavButton(
                  icon: Icons.list_alt_rounded,
                  label: 'Packets',
                  onTap: () {
                    if (_status == ConnectionStatus.connected && _activeController != null) {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => PacketsScreen(controller: _activeController!),
                      ));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please connect to a TNC first.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the TNC status card based on the current connection state.
  Widget _buildStatusCard() {
    String subtitle;
    Icon leadingIcon;
    Widget trailingButton;

    switch (_status) {
      case ConnectionStatus.disconnected:
        subtitle = 'Disconnected';
        leadingIcon = Icon(Icons.bluetooth_disabled, color: Colors.grey);
        trailingButton = ElevatedButton.icon(
          icon: const Icon(Icons.power_settings_new),
          label: const Text('Connect'),
          onPressed: _selectAndConnect,
        );
        break;
      case ConnectionStatus.connecting:
        subtitle = 'Connecting to ${_selectedDevice?.name ?? '...'}';
        leadingIcon = const Icon(Icons.bluetooth_searching, color: Colors.orange);
        trailingButton = const ElevatedButton(
          onPressed: null,
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        );
        break;
      case ConnectionStatus.connected:
        subtitle = 'Connected to ${_selectedDevice?.name ?? 'device'}';
        leadingIcon = Icon(Icons.bluetooth_connected, color: Theme.of(context).primaryColor);
        trailingButton = ElevatedButton.icon(
          icon: const Icon(Icons.cancel_outlined),
          label: const Text('Disconnect'),
          onPressed: _disconnect,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
        );
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: leadingIcon,
        title: const Text('TNC Status:'),
        subtitle: Text(subtitle),
        trailing: trailingButton,
      ),
    );
  }
}

/// A reusable navigation button widget for the home screen grid.
class _HomeNavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _HomeNavButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Theme.of(context).colorScheme.onSecondaryContainer),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}