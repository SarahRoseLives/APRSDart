import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/aprs_packet.dart';
import '../../tnc/benshi/radio_controller.dart';
import '../../tnc/mobilinkd/mobilinkd_controller.dart';

class PacketsScreen extends StatefulWidget {
  final ChangeNotifier controller;
  const PacketsScreen({super.key, required this.controller});

  @override
  State<PacketsScreen> createState() => _PacketsScreenState();
}

class _PacketsScreenState extends State<PacketsScreen> {
  ValueNotifier<List<AprsPacket>>? _packetNotifier;

  @override
  void initState() {
    super.initState();
    // Determine which controller is active and get its packet list notifier
    if (widget.controller is RadioController) {
      _packetNotifier = (widget.controller as RadioController).aprsPackets;
    } else if (widget.controller is MobilinkdController) {
      _packetNotifier = (widget.controller as MobilinkdController).aprsPackets;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Packet Log'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: ValueListenableBuilder<List<AprsPacket>>(
        valueListenable: _packetNotifier ?? ValueNotifier([]),
        builder: (context, packets, child) {
          if (packets.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.watch_later_outlined, size: 60, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Waiting for packets...',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          // Display the newest packets first by reversing the list
          final reversedPackets = packets.reversed.toList();
          return ListView.builder(
            itemCount: reversedPackets.length,
            itemBuilder: (context, index) {
              final packet = reversedPackets[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: const Icon(Icons.radar),
                  title: Text(packet.source, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '${packet.destination} > ${packet.path.join(',')}\n${packet.info}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    DateFormat.Hms().format(packet.timestamp.toLocal()),
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  onTap: () => _showPacketDetails(context, packet),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Shows a bottom sheet with detailed information about the selected packet.
  void _showPacketDetails(BuildContext context, AprsPacket packet) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.radar),
                title: Text(packet.source, style: Theme.of(context).textTheme.headlineSmall),
                subtitle: Text('to ${packet.destination}'),
              ),
              const Divider(),
              ListTile(
                title: const Text('Path'),
                subtitle: Text(packet.path.isEmpty ? 'Direct' : packet.path.join(' > ')),
              ),
              ListTile(
                title: const Text('Raw Info'),
                subtitle: SelectableText(packet.info),
              ),
               ListTile(
                title: const Text('Timestamp'),
                subtitle: Text(packet.timestamp.toLocal().toString()),
              ),
            ],
          ),
        );
      },
    );
  }
}