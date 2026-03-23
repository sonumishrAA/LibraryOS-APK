import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../constants.dart';
import '../globals.dart';
import '../login_screen.dart';

class MessagesTab extends StatefulWidget {
  const MessagesTab({super.key});

  @override
  State<MessagesTab> createState() => MessagesTabState();
}

class MessagesTabState extends State<MessagesTab> {
  bool _isLoading = true;
  List<dynamic> _messages = [];
  final Set<String> _expandedIds = {};

  @override
  void initState() {
    super.initState();
    fetchMessages();
  }

  Future<void> fetchMessages() async {
    setState(() => _isLoading = true);
    final jwt = await storage.read(key: 'admin_jwt');

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/admin-messages'),
        headers: {'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json'},
      );

      if (res.statusCode == 401) {
        await storage.delete(key: 'admin_jwt');
        if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
        return;
      }

      if (res.statusCode == 200) {
        setState(() {
          _messages = jsonDecode(res.body);
          // Sort: unread first, then by date desc
          _messages.sort((a, b) {
            if (a['is_read'] != b['is_read']) return a['is_read'] ? 1 : -1;
            return b['created_at'].compareTo(a['created_at']);
          });
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching messages: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String id) async {
    final jwt = await storage.read(key: 'admin_jwt');
    try {
      await http.patch(
        Uri.parse('$baseUrl/admin-messages'),
        headers: {'Authorization': 'Bearer $jwt', 'Content-Type': 'application/json'},
        body: jsonEncode({'id': id, 'is_read': true}),
      );
      setState(() {
        final index = _messages.indexWhere((m) => m['id'] == id);
        if (index != -1) _messages[index]['is_read'] = true;
      });
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildShimmerLoading();

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inbox_outlined, color: adminBorderColor, size: 64),
            const SizedBox(height: 16),
            Text('No messages yet', style: GoogleFonts.plusJakartaSans(color: adminTextSecondary)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) => _buildMessageCard(_messages[index]),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: adminSurfaceColor,
      highlightColor: adminBorderColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        itemBuilder: (context, index) => Container(
          height: 80,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> msg) {
    final isExpanded = _expandedIds.contains(msg['id']);
    final isRead = msg['is_read'] == true;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isExpanded) {
            _expandedIds.remove(msg['id']);
          } else {
            _expandedIds.add(msg['id']);
            if (!isRead) _markAsRead(msg['id']);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isRead ? const Color(0xFF141414) : adminSurfaceColor,
          borderRadius: BorderRadius.circular(10),
          border: isRead ? null : const Border(left: BorderSide(color: adminAccentColor, width: 3)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(msg['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                if (!isRead) Container(width: 8, height: 8, decoration: const BoxDecoration(color: adminAccentColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(
                  DateFormat('dd MMM HH:mm').format(DateTime.parse(msg['created_at'])),
                  style: const TextStyle(color: adminTextSecondary, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(msg['phone'], style: const TextStyle(color: adminTextSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Text(
              msg['message'],
              maxLines: isExpanded ? null : 2,
              overflow: isExpanded ? null : TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
            ),
            if (msg['message'].length > 100)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  isExpanded ? "Show less" : "Read more",
                  style: const TextStyle(color: adminAccentColor, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
