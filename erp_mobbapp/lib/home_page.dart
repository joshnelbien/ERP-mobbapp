import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/transaction.dart';
import 'package:http/http.dart' as http;

import 'customer_payment.dart'; // Import the new page

class HomePage extends StatefulWidget {
  final String username;

  const HomePage({super.key, required this.username});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // PocketBase server URL
  final String pocketBaseUrl = 'http://football-onto.pockethost.io';

  // List to store customer data from PocketBase
  List<Map<String, String>> _customers = [];

  // Variables to store logged-in user's details
  String _lastName = '';
  String _firstName = '';
  String _cluster = '';

  @override
  void initState() {
    super.initState();
    _fetchCustomerData();
    _fetchUserDetails(); // Fetch user details
  }

  // Fetch customer data from PocketBase
  Future<void> _fetchCustomerData() async {
    try {
      final response = await http.get(
          Uri.parse('$pocketBaseUrl/api/collections/customer_details/records'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List;

        setState(() {
          _customers = items.where((item) {
            // Only include customers whose cluster matches the logged-in user's cluster
            return item['cluster'] == _cluster;
          }).map((item) {
            return {
              'id': item['id'] as String,
              'last_name': item['last_name'] as String,
              'first_name': item['first_name'] as String,
              'address': item['address'] as String,
              'cluster': item['cluster'] as String,
            };
          }).toList();
        });
      } else {
        _showSnackBar('Failed to fetch customer data');
      }
    } catch (e) {
      _showSnackBar('Error fetching data: $e');
    }
  }

  // Fetch logged-in user details
  Future<void> _fetchUserDetails() async {
    try {
      final response = await http.get(Uri.parse(
          '$pocketBaseUrl/api/collections/login/records?filter=username="${widget.username}"'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['items'] as List;

        if (items.isNotEmpty) {
          final user = items.first;
          setState(() {
            _lastName = user['last_name'] ?? '';
            _firstName = user['first_name'] ?? '';
            _cluster = user['cluster'] ?? '';
          });
        }
      } else {
        _showSnackBar('Failed to fetch user details');
      }
    } catch (e) {
      _showSnackBar('Error fetching user details: $e');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home Page'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            iconSize: 40.0, // Transaction icon
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TransactionPage(
                    username: widget.username,
                    transactions: const [],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: <Widget>[
            UserAccountsDrawerHeader(
              accountName: Text('$_firstName $_lastName'), // Display full name
              accountEmail: Text('Cluster: $_cluster'), // Display cluster

              decoration: const BoxDecoration(
                color: Color(0xFF00BF63),
              ),
            ),
            const Expanded(
              child: SizedBox(),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 20.0), // Add top padding
              child: Image.asset(
                'lib/pic/logoresized.png', // Replace with your logo path
                width: 150, // Adjust logo size
                height: 150,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30.0),
                topRight: Radius.circular(30.0),
              ),
              child: Container(
                color: const Color(0xFF00BF63), // Green background
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical, // Allow vertical scrolling
                  child: SingleChildScrollView(
                    scrollDirection:
                        Axis.horizontal, // Allow horizontal scrolling
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Client ID')),
                        DataColumn(label: Text('Last Name')),
                        DataColumn(label: Text('First Name')),
                        DataColumn(label: Text('Address')),
                        DataColumn(
                            label: Text('Cluster')), // Added Cluster column
                      ],
                      rows: _customers.map<DataRow>((customer) {
                        return DataRow(cells: [
                          DataCell(Text(customer['id']!), onTap: () {
                            _navigateToCustomerPayment(
                              context,
                              customer['id'].toString(),
                              customer['last_name'].toString(),
                              customer['first_name'].toString(),
                            );
                          }),
                          DataCell(Text(customer['last_name'].toString())),
                          DataCell(Text(customer['first_name'].toString())),
                          DataCell(Text(customer['address'].toString())),
                          DataCell(Text(customer['cluster']?.toString() ??
                              'N/A')), // Display Cluster
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchCustomerData,
        child: const Icon(Icons.refresh),
      ),
    );
  }

  void _navigateToCustomerPayment(BuildContext context, String customerId,
      String lastName, String firstName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomerPayment(
          customerNo: customerId,
          lastName: lastName,
          firstName: firstName,
          username: widget.username, // Pass username to CustomerPayment
        ),
      ),
    );
  }
}
