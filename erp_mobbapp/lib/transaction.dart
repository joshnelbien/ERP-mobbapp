import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class TransactionPage extends StatefulWidget {
  final String username;

  const TransactionPage({
    super.key,
    required this.username,
    required List transactions,
  });

  @override
  _TransactionPageState createState() => _TransactionPageState();
}

class _TransactionPageState extends State<TransactionPage> {
  late Future<List<Map<String, String>>> transactions;
  String selectedFilter = 'For Today';

  @override
  void initState() {
    super.initState();
    transactions = fetchTransactions();
  }

  Future<List<Map<String, String>>> fetchTransactions() async {
    final url =
        'https://football-onto.pockethost.io/api/collections/client_transaction/records';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      List data = json.decode(response.body)['items'];
      return data.map<Map<String, String>>((transaction) {
        return {
          'id': transaction['id'].toString(),
          'client_id': transaction['client_id'].toString(),
          'last_name': transaction['last_name'].toString(),
          'first_name': transaction['first_name'].toString(),
          'date': transaction['date'].toString(),
          'time': transaction['time'].toString(),
          'amount_paid': transaction['amount_paid'].toString(),
          'proccessed_by': transaction['proccessed_by'].toString(),
        };
      }).toList();
    } else {
      throw Exception('Failed to load transactions');
    }
  }

  double calculateTotalAmountPaid(List<Map<String, String>> transactions) {
    double totalAmountPaid = 0.0;
    for (var transaction in transactions) {
      totalAmountPaid += double.tryParse(transaction['amount_paid']!) ?? 0.0;
    }
    return totalAmountPaid;
  }

  List<Map<String, String>> filterTransactions(
      List<Map<String, String>> transactions) {
    DateTime today = DateTime.now();
    switch (selectedFilter) {
      case 'For Today':
        return transactions.where((transaction) {
          DateTime transactionDate = DateTime.parse(transaction['date']!);
          return transactionDate.day == today.day &&
              transactionDate.month == today.month &&
              transactionDate.year == today.year;
        }).toList();
      case 'For Past 7 Days':
        return transactions.where((transaction) {
          DateTime transactionDate = DateTime.parse(transaction['date']!);
          return today.difference(transactionDate).inDays <= 7;
        }).toList();
      case 'For This Month':
        return transactions.where((transaction) {
          DateTime transactionDate = DateTime.parse(transaction['date']!);
          return today.month == transactionDate.month &&
              today.year == transactionDate.year;
        }).toList();
      case 'For All Transaction':
        return transactions;
      default:
        return transactions;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Transactions"),
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: transactions,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No transactions found.'));
          }

          final transactions = snapshot.data!;

          final filteredTransactions = transactions.where((transaction) {
            return transaction['proccessed_by'] == widget.username;
          }).toList();

          if (filteredTransactions.isEmpty) {
            return Center(
                child:
                    Text('No transactions processed by ${widget.username}.'));
          }

          final finalFilteredTransactions =
              filterTransactions(filteredTransactions);

          final totalAmountPaid =
              calculateTotalAmountPaid(finalFilteredTransactions);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User: ${widget.username}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.normal,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(width: 5),
                        DropdownButton<String>(
                          value: selectedFilter,
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedFilter = newValue!;
                            });
                          },
                          items: [
                            'For Today',
                            'For Past 7 Days',
                            'For This Month',
                            'For All Transaction'
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                    SizedBox(height: 5),
                    Text(
                      '₱${NumberFormat('#,###.00').format(totalAmountPaid)}',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: 10),
                  ],
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30.0),
                    topRight: Radius.circular(30.0),
                  ),
                  child: Container(
                    color: const Color(0xFF00BF63),
                    constraints:
                        BoxConstraints.expand(), // Ensure full coverage
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Transaction ID')),
                            DataColumn(label: Text('Customer ID')),
                            DataColumn(label: Text('Last Name')),
                            DataColumn(label: Text('First Name')),
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Time')),
                            DataColumn(label: Text('Amount Paid')),
                            DataColumn(label: Text('Processed By')),
                          ],
                          rows: finalFilteredTransactions.map((transaction) {
                            return DataRow(cells: [
                              DataCell(Text(transaction['id']!)),
                              DataCell(Text(transaction['client_id']!)),
                              DataCell(Text(transaction['last_name']!)),
                              DataCell(Text(transaction['first_name']!)),
                              DataCell(Text(transaction['date']!)),
                              DataCell(Text(transaction['time']!)),
                              DataCell(Text(transaction['amount_paid']!)),
                              DataCell(Text(transaction['proccessed_by']!)),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
