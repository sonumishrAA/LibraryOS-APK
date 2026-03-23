import 'package:flutter/material.dart';

const String baseUrl = 'https://zlhivlrapbhhkyrljueg.supabase.co/functions/v1';

const String razorpayKeyId = 'rzp_live_SRSc8DqXsmduW6';

// Edge function base URL
const String edgeBaseUrl = '$baseUrl/functions/v1';

// Endpoints
const String epCreatePaymentOrder = '$baseUrl/create-payment-order';
const String epVerifyPayment = '$baseUrl/verify-payment';
const String epPricing = '$baseUrl/update-pricing';
const String epCheckEmail = '$baseUrl/check-email';
const String epResetStaffPassword = '$baseUrl/reset-staff-password';
const String epDeleteStaff = '$baseUrl/delete-staff';
const String epAddStaff = '$baseUrl/add-staff';

// Theme Colors
const Color primaryColor = Color(0xFF1E2D6B); // Navy
const Color primaryLight = Color(0xFFEEF1FB);
const Color greyTrack = Color(0xFFE5E7EB);
const Color textMuted = Color(0xFF6B7280);
const Color adminBgColor = Color(0xFF0D0D0D);
const Color adminSurfaceColor = Color(0xFF1A1A1A);
const Color adminAccentColor = Color(0xFFE85D04);
const Color adminBorderColor = Color(0xFF2A2A2A);
const Color adminTextPrimary = Colors.white;
const Color adminTextSecondary = Color(0xFF888888);

// Status Colors
const Color statusActiveBg = Color(0xFF1A3D2B);
const Color statusActiveText = Color(0xFF22C55E);
const Color statusExpiredBg = Color(0xFF3D1A1A);
const Color statusExpiredText = Color(0xFFEF4444);
const Color statusInactiveBg = Color(0xFF2A2A2A);
const Color statusInactiveText = Color(0xFF888888);
const Color planChipBg = Color(0xFF1E2D4A);
const Color planChipText = Color(0xFF60A5FA);
