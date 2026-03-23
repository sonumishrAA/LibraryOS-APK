import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final supabase = Supabase.instance.client;
const storage = FlutterSecureStorage();

String currentLibraryId = '';
String currentRole = '';
String currentUserName = ''; // Added for tracking
DateTime subscriptionEnd = DateTime.now();
String subscriptionStatus = '';
String libraryName = '';
String libraryPhone = '';
final ValueNotifier<int> cacheUpdateNotifier = ValueNotifier(0);
