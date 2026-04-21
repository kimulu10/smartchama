import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/mpesa_service.dart';

class AddContributionScreen extends StatefulWidget {
  final String organizationId;
  final String chamaId;

  const AddContributionScreen({
    super.key,
    required this.organizationId,
    required this.chamaId,
  });

  @override
  State<AddContributionScreen> createState() => _AddContributionScreenState();
}

class _AddContributionScreenState extends State<AddContributionScreen> {
  final TextEditingController amountController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  bool isLoading = false;
  bool isMpesaLoading = false;
  String chamaName = "Add Contribution";

  @override
  void initState() {
    super.initState();
    _loadChamaName();
  }

  Future<void> _loadChamaName() async {
    final chamaDoc = await firestore
        .collection("organizations")
        .doc(widget.organizationId)
        .collection("chamas")
        .doc(widget.chamaId)
        .get();
    if (chamaDoc.exists && mounted) {
      setState(() {
        chamaName = chamaDoc.data()?["name"] ?? "Add Contribution";
      });
    }
  }

  Future<void> addContribution() async {
    if (amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = auth.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      final amount = double.parse(amountController.text);
      final description = descriptionController.text.isEmpty
          ? "Monthly contribution"
          : descriptionController.text;

      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("contributions")
          .add({
        "userId": user.uid,
        "amount": amount,
        "description": description,
        "createdAt": Timestamp.now(),
        "month": DateTime.now().month,
        "year": DateTime.now().year,
        "paymentMethod": "manual",
      });

      await firestore
          .collection("organizations")
          .doc(widget.organizationId)
          .collection("chamas")
          .doc(widget.chamaId)
          .collection("transactions")
          .add({
        "userId": user.uid,
        "chamaId": widget.chamaId,
        "amount": amount,
        "type": "contribution",
        "description": description,
        "timestamp": Timestamp.now(),
        "status": "completed",
        "paymentMethod": "manual",
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Contribution added successfully")),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }

    setState(() => isLoading = false);
  }

  Future<void> payWithMpesa() async {
    if (amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter an amount")),
      );
      return;
    }

    if (phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter your phone number")),
      );
      return;
    }

    setState(() => isMpesaLoading = true);

    try {
      final user = auth.currentUser;
      if (user == null) {
        setState(() => isMpesaLoading = false);
        return;
      }

      final amount = double.parse(amountController.text);
      final description = descriptionController.text.isEmpty
          ? "Monthly contribution"
          : descriptionController.text;

      // Call M-Pesa STK Push
      final result = await MpesaService.pay(
        phone: phoneController.text,
        amount: amount,
        userId: user.uid,
        organizationId: widget.organizationId,
        chamaId: widget.chamaId,
        type: 'contribution',
      );

      if (result['success'] == true) {
        final checkoutRequestID = result['checkoutRequestID'];
        
        // Save pending contribution
        await firestore
            .collection("organizations")
            .doc(widget.organizationId)
            .collection("chamas")
            .doc(widget.chamaId)
            .collection("contributions")
            .add({
          "userId": user.uid,
          "amount": amount,
          "description": description,
          "createdAt": Timestamp.now(),
          "month": DateTime.now().month,
          "year": DateTime.now().year,
          "paymentMethod": "mpesa",
          "status": "pending",
          "checkoutRequestID": checkoutRequestID,
        });

        // Show waiting dialog
        if (!mounted) return;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(
            title: Text("M-Pesa Payment"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Please check your phone and enter your M-Pesa PIN to complete the payment."),
                SizedBox(height: 20),
                CircularProgressIndicator(),
                SizedBox(height: 10),
                Text("Waiting for payment..."),
              ],
            ),
          ),
        );

        // Poll for transaction status
        final status = await MpesaService.waitForTransactionCompletion(checkoutRequestID);
        
        if (!mounted) return;
        Navigator.pop(context); // Close waiting dialog

        if (status == 'success') {
          // Update contribution status
          final contributions = await firestore
              .collection("organizations")
              .doc(widget.organizationId)
              .collection("chamas")
              .doc(widget.chamaId)
              .collection("contributions")
              .where("checkoutRequestID", isEqualTo: checkoutRequestID)
              .get();
          
          if (contributions.docs.isNotEmpty) {
            await contributions.docs.first.reference.update({
              "status": "completed",
            });
          }

          // Add successful transaction
          await firestore
              .collection("organizations")
              .doc(widget.organizationId)
              .collection("chamas")
              .doc(widget.chamaId)
              .collection("transactions")
              .add({
            "userId": user.uid,
            "chamaId": widget.chamaId,
            "amount": amount,
            "type": "contribution",
            "description": description,
            "timestamp": Timestamp.now(),
            "status": "success",
            "paymentMethod": "mpesa",
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Payment successful!"),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Payment failed or timed out"),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${result['error']}")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }

    setState(() => isMpesaLoading = false);
  }

  @override
  void dispose() {
    amountController.dispose();
    descriptionController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("$chamaName - Contribute"),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.account_balance_wallet,
                    size: 48,
                    color: Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Add Your Contribution",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1B5E20),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Your contributions help grow the chama",
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Amount (KES)",
                prefixText: "KES ",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                prefixIcon: const Icon(Icons.attach_money),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: "Description (optional)",
                hintText: "e.g., Monthly contribution for January",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.grey[50],
                prefixIcon: const Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 32),
            
            // Manual Payment Button
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: isLoading ? null : addContribution,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Record Manually",
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // M-Pesa Payment Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone_android, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        "Pay with M-Pesa",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "Phone Number",
                      hintText: "e.g., 0712345678",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.phone),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isMpesaLoading ? null : payWithMpesa,
                      icon: isMpesaLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send),
                      label: Text(
                        isMpesaLoading ? "Processing..." : "Send STK Push",
                        style: const TextStyle(fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "You will receive an STK push on your phone",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}