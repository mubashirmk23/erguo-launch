import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:erguo/screens/client/home_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import 'package:erguo/constants/api_constants.dart';

final String supabaseKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ1cHBzdGR6enp3b3V2dnNvb3liIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzkzNzQyNDMsImV4cCI6MjA1NDk1MDI0M30.uHM2cNuXUvY2qUsi9l752I3njP62K79RKO_SNVRPKEU";

class PaymentScreen extends StatefulWidget {
  final double amount;
  final String requestId;

  PaymentScreen({required this.requestId, required this.amount});
  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool isLoading = false;
  final CFPaymentGatewayService _service = CFPaymentGatewayService();

  @override
  void initState() {
    super.initState();
    _service.setCallback(_onSuccess, _onError);
  }

  void _onError(CFErrorResponse error, String orderId) {
    _show('❌ Payment Failed: ${error.getMessage()}', isError: true);
  }

  Future<void> initiatePayment() async {
    setState(() => isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _show('User not logged in', isError: true);
      setState(() => isLoading = false);
      return;
    }

    // 🔍 Fetch user details from Firestore
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (!doc.exists) {
      _show('User info not found in database', isError: true);
      setState(() => isLoading = false);
      return;
    }

    final userData = doc.data()!;
    final name = userData['firstName'] ?? 'Customer';
    final email = userData['email'] ?? 'noemail@example.com';
    final rawPhone = userData['phone'] ?? '0000000000';
    final phone = rawPhone.toString().replaceAll('+', '');

    final res = await http.post(
      Uri.parse(paymentFunctionEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $supabaseKey',
      },
      body: jsonEncode({
        "amount": widget.amount,
        "customerName": name,
        "customerEmail": email,
        "customerPhone": phone,
      }),
    );

    setState(() => isLoading = false);
    if (res.statusCode != 200) {
      _show('Payment initiation failed: ${res.body}', isError: true);
      return;
    }

    final data = jsonDecode(res.body);
    final oid = data['order_id'];
    final psid = data['payment_session_id'];
    if (oid == null || psid == null) {
      _show('Missing order or session ID', isError: true);
      return;
    }

    _startPayment(oid, psid);
  }

  void _startPayment(String orderId, String paymentSessionId) {
    final session = CFSessionBuilder()
        .setOrderId(orderId)
        .setPaymentSessionId(paymentSessionId)
        .setEnvironment(CFEnvironment.SANDBOX)
        .build();
    final payment = CFWebCheckoutPaymentBuilder().setSession(session).build();

    _service.doPayment(payment);
  }

  void _onSuccess(String orderId) async {
    try {
      final requestRef = FirebaseFirestore.instance
          .collection('service_requests')
          .doc(widget.requestId); // ✅ Use actual requestId
      await requestRef.update({'status': 'bill paid'});

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (route) => false,
        );
      }

      _show('✅ Payment Success: $orderId');
    } catch (e) {
      _show('✅ Payment received, but failed to update status.', isError: true);
    }
  }

  void _show(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payment',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.payment_rounded,
                  size: 80, color: Colors.black87),
              const SizedBox(height: 20),
              const Text(
                "Confirm your payment",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Amount to pay: ₹${widget.amount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 40),
              isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: initiatePayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          "Pay Now",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
