import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/app_scaffold.dart';

class AttendanceDashboardScreen extends StatefulWidget {
  final String eventId;
  final String eventName;

  const AttendanceDashboardScreen({super.key, required this.eventId, required this.eventName});

  @override
  State<AttendanceDashboardScreen> createState() => _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState extends State<AttendanceDashboardScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _registrations = [];
  bool _isLoading = true;
  String _filterStatus = 'All'; // All, Attended, Pending, Cancelled

  @override
  void initState() {
    super.initState();
    _fetchData();
    _setupRealtime();
  }

  Future<void> _fetchData() async {
    try {
      final response = await _supabase
          .from('event_registrations')
          .select('id, status, registered_at, profiles(nim, full_name, major)')
          .eq('event_id', widget.eventId)
          .order('registered_at', ascending: false);

      if (mounted) {
        setState(() {
          _registrations = List<Map<String, dynamic>>.from(response as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _setupRealtime() {
    _supabase
        .channel('public:event_registrations')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'event_registrations',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'event_id', value: widget.eventId),
          callback: (payload) {
            _fetchData(); // Refresh data when changes occur
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _supabase.removeAllChannels();
    super.dispose();
  }

  Future<void> _exportCsv() async {
    try {
      List<List<dynamic>> rows = [
        ['NIM', 'Nama Lengkap', 'Prodi', 'Status Kehadiran', 'Waktu Mendaftar'],
      ];

      for (var reg in _registrations) {
        final profile = reg['profiles'] ?? {};
        rows.add([
          profile['nim'] ?? '-',
          profile['full_name'] ?? '-',
          profile['major'] ?? '-',
          reg['status'] ?? '-',
          reg['registered_at'] ?? '-',
        ]);
      }

      String csvData = const ListToCsvConverter().convert(rows);
      
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/Kehadiran_${widget.eventName.replaceAll(" ", "_")}.csv';
      final file = File(path);
      await file.writeAsString(csvData);

      // ignore: deprecated_member_use
      await Share.shareXFiles([XFile(path)], text: 'Export Kehadiran Event: ${widget.eventName}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal export CSV: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = _filterStatus == 'All' 
        ? _registrations 
        : _registrations.where((r) => (r['status'] as String).toLowerCase() == _filterStatus.toLowerCase()).toList();

    final totalRegistrants = _registrations.length;
    final totalAttended = _registrations.where((r) => r['status'] == 'attended').length;
    final totalPending = _registrations.where((r) => r['status'] == 'pending' || r['status'] == 'confirmed').length;

    return AppScaffold(
      appBar: AppBar(
        title: const Text('Dashboard Kehadiran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: _registrations.isEmpty ? null : _exportCsv,
            tooltip: 'Export CSV',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatCard('Total', totalRegistrants, Colors.blue),
                      _buildStatCard('Hadir', totalAttended, AppColors.success),
                      _buildStatCard('Belum/Pending', totalPending, AppColors.warning),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: DropdownButtonFormField<String>(
                    initialValue: _filterStatus,
                    decoration: InputDecoration(
                      labelText: 'Filter Status',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    items: ['All', 'Attended', 'Confirmed', 'Pending', 'Cancelled']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _filterStatus = val);
                    },
                  ),
                ),
                Expanded(
                  child: filteredData.isEmpty
                      ? const Center(child: Text('Tidak ada data'))
                      : ListView.builder(
                          itemCount: filteredData.length,
                          itemBuilder: (context, index) {
                            final data = filteredData[index];
                            final profile = data['profiles'] ?? {};
                            final status = data['status'] as String;
                            
                            Color statusColor = Colors.grey;
                            if (status == 'attended') statusColor = AppColors.success;
                            if (status == 'confirmed') statusColor = Colors.blue;
                            if (status == 'cancelled') statusColor = AppColors.error;

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: statusColor.withValues(alpha: 0.2),
                                child: Icon(
                                  status == 'attended' ? Icons.check : Icons.person,
                                  color: statusColor,
                                ),
                              ),
                              title: Text(profile['full_name'] ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${profile['nim'] ?? '-'} • ${profile['major'] ?? '-'}'),
                              trailing: Chip(
                                label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                                backgroundColor: statusColor,
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color) {
    return Column(
      children: [
        Text(value.toString(), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
