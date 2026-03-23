import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../constants.dart';
import '../globals.dart';
import '../login_screen.dart';

class LibrariesTab extends StatefulWidget {
  const LibrariesTab({super.key});

  @override
  State<LibrariesTab> createState() => LibrariesTabState();
}

class LibrariesTabState extends State<LibrariesTab> {
  bool _isLoading = true;
  List<dynamic> _allLibraries = [];
  List<dynamic> _filteredLibraries = [];
  int? _expandedIndex;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final Set<String> _deletingIds = {};

  @override
  void initState() {
    super.initState();
    fetchLibraries();
  }

  Future<void> fetchLibraries() async {
    setState(() => _isLoading = true);
    final jwt = await storage.read(key: 'admin_jwt');

    try {
      final res = await http.get(
        Uri.parse('$baseUrl/admin-libraries'),
        headers: {'Authorization': 'Bearer $jwt'},
      );

      if (res.statusCode == 401) {
        await storage.delete(key: 'admin_jwt');
        if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
        return;
      }

      if (res.statusCode == 200) {
        setState(() {
          _allLibraries = jsonDecode(res.body);
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching libraries: $e');
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredLibraries = _allLibraries.where((lib) {
        final matchesSearch = lib['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) || 
                             lib['city'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
        
        if (_selectedFilter == 'All') return matchesSearch;
        return matchesSearch && lib['subscription_status'].toString().toLowerCase() == _selectedFilter.toLowerCase();
      }).toList();
    });
  }

  Future<void> _deleteLibrary(String id, String name) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: adminSurfaceColor,
        title: Text('Delete $name?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Permanent. Cannot be undone. All data lost.', style: TextStyle(color: adminTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel', style: TextStyle(color: adminTextSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _deletingIds.add(id));
      final jwt = await storage.read(key: 'admin_jwt');
      try {
        final res = await http.post(
          Uri.parse('$baseUrl/delete-library'),
          headers: {'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json'},
          body: jsonEncode({'id': id}),
        );

        if (res.statusCode == 200) {
          setState(() {
            _allLibraries.removeWhere((lib) => lib['id'] == id);
            _applyFilters();
          });
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted successfully'), backgroundColor: Colors.green));
        } else {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: ${res.body}'), backgroundColor: Colors.red));
        }
      } catch (e) {
         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      } finally {
        if (mounted) setState(() => _deletingIds.remove(id));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top Controls
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                onChanged: (v) {
                  _searchQuery = v;
                  _applyFilters();
                },
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by name or city...',
                  hintStyle: const TextStyle(color: adminTextSecondary),
                  prefixIcon: const Icon(Icons.search, color: adminTextSecondary),
                  filled: true,
                  fillColor: adminSurfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Active', 'Expired', 'Inactive'].map((filter) => _buildFilterChip(filter)).toList(),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _isLoading 
            ? _buildShimmerLoading()
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredLibraries.length,
                itemBuilder: (context, index) => _buildLibraryCard(index),
              ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: adminSurfaceColor,
      highlightColor: adminBorderColor,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 5,
        itemBuilder: (context, index) => Container(
          height: 100,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
          _applyFilters();
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? adminAccentColor : adminSurfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : adminTextSecondary, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }

  Widget _buildLibraryCard(int index) {
    final lib = _filteredLibraries[index];
    final isExpanded = _expandedIndex == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: adminSurfaceColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isExpanded ? adminAccentColor : adminBorderColor),
      ),
      child: InkWell(
        onTap: () => setState(() => _expandedIndex = isExpanded ? null : index),
        child: Column(
          children: [
            // Collapsed Info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(lib['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      _buildStatusChip(lib['subscription_status']),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${lib['city']}, ${lib['state']}', style: const TextStyle(color: adminTextSecondary, fontSize: 13)),
                      _buildPlanChip(lib['subscription_plan']),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${lib['student_stats']['total']} students', style: const TextStyle(color: adminTextSecondary, fontSize: 12)),
                      Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: adminTextSecondary, size: 20),
                    ],
                  ),
                ],
              ),
            ),

            if (isExpanded) ...[
              const Divider(color: adminBorderColor, height: 1),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Owner'),
                    _buildInfoRow('Name', lib['owner_name']),
                    _buildInfoRow('Email', lib['owner_email']),
                    
                    _buildSectionHeader('Subscription'),
                    _buildInfoRow('Status', lib['subscription_status']),
                    _buildInfoRow('Start', _formatDate(lib['subscription_start'])),
                    _buildInfoRow('Ends', _formatDate(lib['subscription_end'])),
                    
                    _buildSectionHeader('Library Setup'),
                    _buildInfoRow('Seats', 'M: ${lib['male_seats']} F: ${lib['female_seats']} N: ${lib['neutral_seats']}'),
                    _buildInfoRow('Address', '${lib['address']}, ${lib['city']}'),
                    _buildInfoRow('Pincode', lib['pincode'].toString()),
                    _buildInfoRow('Onboarding', lib['onboarding_done'] == true ? '✅ Done' : '⏳ Pending'),

                    _buildSectionHeader('Staff'),
                    ...(lib['staff'] as List).isEmpty 
                        ? [const Text('No staff added', style: TextStyle(color: adminTextSecondary, fontStyle: FontStyle.italic, fontSize: 12))]
                        : (lib['staff'] as List).map((s) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(s['email'], style: const TextStyle(color: adminTextSecondary, fontSize: 11)),
                              const SizedBox(height: 8),
                            ],
                          )),

                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _deletingIds.contains(lib['id']) ? null : () => _deleteLibrary(lib['id'], lib['name']),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB91C1C), foregroundColor: Colors.white),
                        child: _deletingIds.contains(lib['id']) 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('DELETE LIBRARY', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color bg = statusInactiveBg;
    Color txt = statusInactiveText;
    if (status?.toLowerCase() == 'active') { bg = statusActiveBg; txt = statusActiveText; }
    else if (status?.toLowerCase() == 'expired') { bg = statusExpiredBg; txt = statusExpiredText; }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(status?.toUpperCase() ?? 'UNKNOWN', style: TextStyle(color: txt, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPlanChip(String? plan) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: planChipBg, borderRadius: BorderRadius.circular(4)),
      child: Text(plan?.toUpperCase() ?? 'NONE', style: const TextStyle(color: planChipText, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(title.toUpperCase(), style: const TextStyle(color: adminAccentColor, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold)),
        const Divider(color: adminBorderColor),
      ],
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: adminTextSecondary, fontSize: 13))),
          Expanded(child: Text(value?.toString() ?? 'N/A', style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }

  String _formatDate(String? date) {
    if (date == null) return 'N/A';
    return DateFormat('dd MMM yyyy').format(DateTime.parse(date));
  }
}
