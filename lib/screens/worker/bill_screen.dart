import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:erguo/screens/worker/thankyou_screen.dart';
import 'package:flutter/material.dart';

class BillScreen extends StatefulWidget {
  final String requestId;
  final int totalSeconds;

  const BillScreen({super.key, required this.requestId, required this.totalSeconds});

  @override
  _BillScreenState createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  final List<Map<String, dynamic>> billItems = [];
  bool isSubmitted = false;
  final int ratePerHour = 1000; // Rs per hour
  final TextEditingController itemController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
void _editItem(int index) {
  final item = billItems[index];
  itemController.text = item['itemName'];
  quantityController.text = item['quantity'].toString();
  priceController.text = item['unitPrice'].toString();

  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text("Edit Item"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: itemController, decoration: const InputDecoration(labelText: "Item Name")),
          TextField(controller: quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Quantity")),
          TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Price per Unit")),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          onPressed: () {
            final String newItemName = itemController.text;
            final int newQuantity = int.tryParse(quantityController.text) ?? 0;
            final int newPrice = int.tryParse(priceController.text) ?? 0;

            if (newItemName.isNotEmpty && newQuantity > 0 && newPrice > 0) {
              setState(() {
                billItems[index] = {
                  'itemName': newItemName,
                  'quantity': newQuantity,
                  'unitPrice': newPrice,
                  'totalPrice': newQuantity * newPrice,
                };
              });
            }

            Navigator.pop(context);
          },
          child: const Text("Save"),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final int hours = widget.totalSeconds ~/ 3600;
    final int minutes = (widget.totalSeconds % 3600) ~/ 60;
    final int timeCharge = ((widget.totalSeconds / 3600) * ratePerHour).round();
    final int totalItemPrice = billItems.fold(0, (sum, item) => sum + (item['totalPrice'] as int));
    final int totalPrice = timeCharge + totalItemPrice; // Total price includes both item and time charge

    return Scaffold(
      appBar: AppBar(
        title: const Text("Bill Summary", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1.0),
          child: Divider(height: 1, thickness: 1, color: Colors.black),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time Worked & Earnings
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Hours Worked: ${hours}h ${minutes}m",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    "₹$timeCharge",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bill Items List
            Expanded(
              child: billItems.isEmpty
                  ? const Center(child: Text("No items added yet!", style: TextStyle(fontSize: 16, color: Colors.grey)))
                  : ListView.builder(
                      itemCount: billItems.length,
                      itemBuilder: (context, index) {
                        final item = billItems[index];
                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ListTile(
                            leading: const Icon(Icons.shopping_bag, color: Colors.black),
                            title: Text("${item['itemName']} (x${item['quantity']})",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            subtitle: Text("₹${item['totalPrice']}", style: const TextStyle(fontSize: 14, color: Colors.black54)),
                            trailing: isSubmitted
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.blue),
                                    onPressed: () => _editItem(index),
                                  ),
                          ),
                        );
                      },
                    ),
            ),

            // Add Item Button
            if (!isSubmitted)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _addItemDialog,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text("Add Item", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),

            const SizedBox(height: 20),

            // Total Price Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Total Price:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text("₹$totalPrice", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Submit or Edit Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (isSubmitted)
                  ElevatedButton(
                    onPressed: () => setState(() => isSubmitted = false),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text("Edit Bill"),
                  ),
                ElevatedButton(
                  onPressed: isSubmitted ? _finalSubmitBill : _submitBill,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: Text(isSubmitted ? "Submit Final" : "Submit Bill"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Function to show add item dialog
  void _addItemDialog() {
    itemController.clear();
    quantityController.clear();
    priceController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Item"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: itemController, decoration: const InputDecoration(labelText: "Item Name")),
            TextField(controller: quantityController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Quantity")),
            TextField(controller: priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Price per Unit")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              _addItem();
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  // Function to add item to the bill
  void _addItem() {
    final String itemName = itemController.text;
    final int quantity = int.tryParse(quantityController.text) ?? 0;
    final int price = int.tryParse(priceController.text) ?? 0;

    if (itemName.isNotEmpty && quantity > 0 && price > 0) {
      setState(() {
        billItems.add({
          'itemName': itemName,
          'quantity': quantity,
          'unitPrice': price,
          'totalPrice': quantity * price,
        });
      });
    }
  }

  // Function to submit bill (locks editing)
  void _submitBill() {
    setState(() => isSubmitted = true);
  }

  // Function to submit the final bill to Firestore
void _finalSubmitBill() async {
  final int timeCharge = ((widget.totalSeconds / 3600) * ratePerHour).round();
  final int totalItemPrice = billItems.fold(0, (sum, item) => sum + (item['totalPrice'] as int));
  final int totalPrice = timeCharge + totalItemPrice; // Calculate total price

  final billData = {
    'requestId': widget.requestId,
    'timeWorked': widget.totalSeconds,
    'billItems': billItems,
    'totalPrice': totalPrice, // Use the calculated totalPrice
    'timestamp': Timestamp.now(),
  };

  try {
    // Save bill to Firestore
    await FirebaseFirestore.instance.collection('bills').doc(widget.requestId).set(billData);

    // Update request status to "Bill Ready"
    await FirebaseFirestore.instance.collection('service_requests').doc(widget.requestId).update({
      'status': 'bill ready',
    });

    // Navigate to Thank You Screen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ThankYouScreen(totalPrice: totalPrice,requestId: widget.requestId,),
      ),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
  }
}

}
