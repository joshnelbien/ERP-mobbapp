import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class CustomerPayment extends StatefulWidget {
  final String customerNo;
  final String lastName;
  final String firstName;
  final String username;

  const CustomerPayment({
    Key? key,
    required this.customerNo,
    required this.lastName,
    required this.firstName,
    required this.username,
  }) : super(key: key);

  @override
  _CustomerPaymentState createState() => _CustomerPaymentState();
}

class _CustomerPaymentState extends State<CustomerPayment> {
  final TextEditingController _paymentController = TextEditingController();
  List<Map<String, dynamic>> _transactions = [];
  double _totalLoanAmount = 0;
  double _totalAmountPaid = 0;
  double _dailyDue = 0;
  double _tenDayDue = 0;

  @override
  void initState() {
    super.initState();
    _fetchTransactions(); // Fetch transactions when the screen loads
  }

  Future<void> _moveToHistory(Map<String, dynamic> transaction) async {
    try {
      final remainingBalance =
          transaction['loan_amount'] - transaction['amount_paid'];

      // Only proceed if the remaining balance is 0
      if (remainingBalance > 0) {
        print(
            'Transaction ${transaction['transaction_no']} not fully settled. Skipping transfer.');
        return;
      }

      // Insert into client_due_history
      final historyUrl = Uri.parse(
          'https://football-onto.pockethost.io/api/collections/client_dues_history/records');
      final response = await http.post(
        historyUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'client_id': transaction['client_id'],
          'last_name': transaction['last_name'],
          'first_name': transaction['first_name'],
          'loan_amount': transaction['loan_amount'],
          'due_date': transaction['due_date'],
          'date': transaction['date'],
          'time': transaction['time'],
          'amount_paid': transaction['amount_paid'],
          'processed_by': transaction['processed_by'],
          'date_accomplished': transaction['date_accomplished'],
        }),
      );

      if (response.statusCode != 200) {
        print('Failed to insert into client_due_history: ${response.body}');
        throw Exception('Failed to insert into client_due_history');
      }
      print('Transaction successfully inserted into client_due_history.');

      // Delete from client_dues
      await _deleteTransaction(transaction['transaction_no']);

      print(
          'Transaction ${transaction['transaction_no']} moved to client_dues_history.');
    } catch (error) {
      print('Error moving transaction to history: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Failed to move completed transaction to history. Please try again.'),
        ),
      );
    }
  }

// Helper function for deletion with retry logic
  Future<void> _deleteTransaction(String transactionId) async {
    const maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        final deleteUrl = Uri.parse(
            'https://football-onto.pockethost.io/api/collections/client_dues/records/$transactionId');

        final deleteResponse = await http.delete(
          deleteUrl,
          headers: {'Content-Type': 'application/json'},
        );

        if (deleteResponse.statusCode == 204) {
          print('Transaction with ID $transactionId successfully deleted.');
          return;
        } else {
          print(
              'Failed to delete: ${deleteResponse.statusCode}, ${deleteResponse.body}');
          throw Exception(
              'Delete failed with status code ${deleteResponse.statusCode}');
        }
      } catch (error) {
        print('Error deleting transaction with ID $transactionId: $error');
        retryCount++;
      }

      if (retryCount == maxRetries) {
        throw Exception(
            'Failed to delete transaction with ID $transactionId after $maxRetries attempts.');
      }
    }
  }

  Future<void> _fetchTransactions() async {
    try {
      final url = Uri.parse(
          'https://football-onto.pockethost.io/api/collections/client_dues/records');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['items'];
        setState(() {
          _transactions = data
              .map((item) => {
                    'transaction_no': item['id'] ?? '',
                    'client_id': item['client_id'] ?? '',
                    'last_name': item['last_name'] ?? '',
                    'first_name': item['first_name'] ?? '',
                    'loan_amount': (item['loan_amount'] ?? 0).toDouble(),
                    'due_date': item['due_date'] ?? '',
                    'date': item['date'] ?? '',
                    'time': item['time'] ?? '',
                    'amount_paid': (item['amount_paid'] ?? 0).toDouble(),
                    'processed_by': item['processed_by'] ?? '',
                    'date_accomplished': item['date_accomplished'] ?? '',
                    'status': _calculateStatus(
                        item['due_date'], item['date_accomplished'])
                  })
              .where((transaction) =>
                  transaction['client_id'] == widget.customerNo)
              .toList();

          _totalLoanAmount = _transactions.fold(
              0,
              (sum, transaction) =>
                  sum + (transaction['loan_amount'] as double));
          _totalAmountPaid = _transactions.fold(
              0,
              (sum, transaction) =>
                  sum + (transaction['amount_paid'] as double));
        });
        _dailyDue = _totalLoanAmount / 100; // Assuming 100 days
        _tenDayDue = _totalLoanAmount / 10;

        final remainingBalance = _totalLoanAmount - _totalAmountPaid;
        if (remainingBalance <= 0) {
          print(
              'Remaining balance is zero. Moving all transactions to history.');
          for (var transaction in _transactions) {
            await _moveToHistory(transaction);
          }
        }
      } else {
        throw Exception('Failed to load transactions');
      }
    } catch (error) {
      print('Error fetching transactions: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Failed to fetch transactions. Please check your connection or API status.'),
        ),
      );
    }
  }

  void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Text("Processing..."),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _insertClientTransaction(
      Map<String, dynamic> transaction) async {
    final transactionInsertUrl = Uri.parse(
        'https://football-onto.pockethost.io/api/collections/client_transaction/records');

    final response = await http.post(
      transactionInsertUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'client_id': widget.customerNo,
        'last_name': widget.lastName,
        'first_name': widget.firstName,
        'date': DateTime.now().toIso8601String().split('T').first,
        'time': DateFormat('HH:mm:ss').format(DateTime.now()),
        'amount_paid': transaction['amount_paid'],
        'proccessed_by': widget.username,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to insert transaction into client_transaction');
    }
  }

  void _addPayment() async {
    final paymentAmountText = _paymentController.text;
    final double paymentAmount = double.tryParse(paymentAmountText) ?? 0;

    if (paymentAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid payment amount.'),
        ),
      );
      return;
    }

    // Validate against daily due and remaining balance
    final double remainingBalance = _totalLoanAmount - _totalAmountPaid;

    if (paymentAmount < _dailyDue) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Payment amount cannot be less than the daily due of ₱${_dailyDue.toStringAsFixed(2)}.'),
        ),
      );
      return;
    }

    if (paymentAmount > remainingBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Payment amount exceeds the remaining balance of ₱${remainingBalance.toStringAsFixed(2)}.'),
        ),
      );
      return;
    }

    // Proceed with payment processing
    showLoadingDialog(context); // Show loading dialog

    try {
      final currentDate = DateTime.now();
      final currentDateString = currentDate.toIso8601String().split('T').first;

      double remainingPayment = paymentAmount;

      for (var transaction in _transactions) {
        double dueAmount =
            transaction['loan_amount'] - transaction['amount_paid'];

        if (remainingPayment <= 0) break; // Exit if payment is fully used

        // Fetch current transaction details to verify 'date_accomplished'
        final checkUrl = Uri.parse(
            'https://football-onto.pockethost.io/api/collections/client_dues/records/${transaction['transaction_no']}');

        final checkResponse = await http.get(checkUrl, headers: {
          'Content-Type': 'application/json',
        });

        if (checkResponse.statusCode != 200) {
          throw Exception('Failed to retrieve transaction details');
        }

        final transactionData = jsonDecode(checkResponse.body);
        if (transactionData['date_accomplished'] != null &&
            transactionData['date_accomplished'].toString().isNotEmpty) {
          continue;
        }

        // Calculate the portion of payment for this transaction
        double paymentForThisTransaction =
            remainingPayment < dueAmount ? remainingPayment : dueAmount;

        // Insert the exact payment portion into client_transaction
        await _insertClientTransaction({
          'amount_paid': paymentForThisTransaction,
        });

        // Update client_dues with cumulative logic
        if (remainingPayment < dueAmount) {
          transaction['amount_paid'] += remainingPayment;
          remainingPayment = 0;

          // Update only the amount_paid field
          final response = await http.patch(
            checkUrl,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'amount_paid': transaction['amount_paid'],
            }),
          );

          if (response.statusCode != 200) {
            throw Exception('Failed to update transaction');
          }
        } else {
          transaction['amount_paid'] += dueAmount;
          remainingPayment -= dueAmount;

          // Update both amount_paid and date_accomplished fields
          final response = await http.patch(
            checkUrl,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'amount_paid': transaction['amount_paid'],
              'date_accomplished': currentDateString,
            }),
          );

          if (response.statusCode != 200) {
            throw Exception('Failed to update transaction');
          }
        }
      }

      Navigator.pop(context); // Dismiss loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Payment of ₱${paymentAmount.toStringAsFixed(2)} successful for ${widget.lastName}, ${widget.firstName}.'),
        ),
      );

      _paymentController.clear();
      await _fetchTransactions(); // Refresh transactions
    } catch (error) {
      Navigator.pop(context); // Dismiss loading dialog
      print('Error adding payment: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Failed to add payment. Please check your connection or API status.'),
        ),
      );
    }
  }

  String _calculateStatus(String dueDate, String? dateAccomplished) {
    if (dateAccomplished == null || dateAccomplished.isEmpty) {
      return 'Processing';
    }

    DateTime due = DateTime.parse(dueDate);
    DateTime accomplished = DateTime.parse(dateAccomplished);

    if (accomplished.isBefore(due) || accomplished.isAtSameMomentAs(due)) {
      return 'Paid On Time';
    } else {
      return 'Late';
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainingBalance = _totalLoanAmount - _totalAmountPaid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Payment Details'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding:
              const EdgeInsets.all(16.0), // Padding for content inside the body
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Customer Information
              Text(
                'Customer ID: ${widget.customerNo}\nLast Name: ${widget.lastName}\nFirst Name: ${widget.firstName}\nCollector Name: ${widget.username}',
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),

              // Payment Amount Input
              TextField(
                controller: _paymentController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Enter Payment Amount',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Add Payment Button
              ElevatedButton(
                onPressed: _addPayment,
                style: ElevatedButton.styleFrom(
                  primary: Color(
                      0xFF00BF63), // Set the background color to your custom green
                  onPrimary: Colors.black, // Set the text color to black
                ),
                child: const Text('Add Payment'),
              ),
              const SizedBox(height: 30),

              // Total Loan Amount and Daily Due Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Loan Amount:',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₱${_totalLoanAmount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Due Amount:    ',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₱${_dailyDue.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),

              // Total Amount Paid and 10-Day Due Amount
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Total Amount Paid:',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₱${_totalAmountPaid.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '10-Day Due Amount: ',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '₱${_tenDayDue.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),

              // Remaining Balance
              const Text(
                'Remaining Balance:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                '₱${remainingBalance.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 14),
              ),

              const SizedBox(height: 20),

              // Transaction History Section
              const Text(
                'CLIENT DUE TABLE:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),

              // Apply green background only to the DataTable
              Container(
                decoration: BoxDecoration(
                  color: Color(
                      0xFF00BF63), // Set the green background for the table
                  borderRadius:
                      BorderRadius.circular(8), // Optional rounded corners
                ),
                child: SingleChildScrollView(
                  scrollDirection:
                      Axis.horizontal, // Enable horizontal scrolling
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Transaction No')),
                      DataColumn(label: Text('Amount Due')),
                      DataColumn(label: Text('Due Date')),
                      DataColumn(label: Text('Amount Paid')),
                      DataColumn(label: Text('Date Accomplished')),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: _transactions.map((transaction) {
                      return DataRow(cells: [
                        DataCell(Text(transaction['transaction_no'] ?? 'N/A')),
                        DataCell(Text(
                            '₱${(transaction['loan_amount'] ?? 0).toStringAsFixed(2)}')),
                        DataCell(Text(transaction['due_date'] ?? 'N/A')),
                        DataCell(Text(
                            '₱${(transaction['amount_paid'] ?? 0).toStringAsFixed(2)}')),
                        DataCell(Text(transaction['date_accomplished'] ?? '')),
                        DataCell(Text(transaction['status'] ?? 'N/A')),
                      ]);
                    }).toList(),
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
