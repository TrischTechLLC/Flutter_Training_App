import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_database/firebase_database.dart';
import 'welcome_page.dart';
import 'login_page.dart';
import 'ai_assistant_page.dart';
import 'package:flutter_application_3/generated/app_localizations.dart';

class Driver {
  final String serialNo;
  final String name;
  final String truckId;
  final String mobNo;
  bool isPaid;

  Driver({
    required this.serialNo,
    required this.name,
    required this.truckId,
    required this.mobNo,
    this.isPaid = false,
  });
}

class OptionsPage extends StatefulWidget {
  final Function(Locale) setLocale;

  const OptionsPage({super.key, required this.setLocale});

  @override
  State<OptionsPage> createState() => _OptionsPageState();
}

class _OptionsPageState extends State<OptionsPage> {
  // HARDCODED DRIVER DATA - ALL 15 DRIVERS
  final List<Driver> drivers = [
    Driver(serialNo: '1', name: 'Sanjay', truckId: '9877', mobNo: '8591126176'),
    Driver(serialNo: '2', name: 'Abdul Kuim', truckId: '9878', mobNo: '8011054324'),
    Driver(serialNo: '3', name: 'Raja', truckId: '3052', mobNo: '6026911206'),
    Driver(serialNo: '4', name: 'Miraj Ali', truckId: '1654', mobNo: '6303678937'),
    Driver(serialNo: '5', name: 'Siraj Ali', truckId: '9876', mobNo: '6301418034'),
    Driver(serialNo: '6', name: 'Matibur Rehman', truckId: '9875', mobNo: '6900465525'),
    Driver(serialNo: '7', name: 'Abul 6020', truckId: '6020', mobNo: '9429292518'),
    Driver(serialNo: '8', name: 'Asamuddin', truckId: '8908', mobNo: '8008190411'),
    Driver(serialNo: '9', name: 'Vijay Mahto', truckId: '4400', mobNo: '9102111376'),
    Driver(serialNo: '10', name: 'Babul Hussain', truckId: '6266', mobNo: '9395399193'),
    Driver(serialNo: '11', name: 'Raju Yadav', truckId: '1486', mobNo: '8019735390'),
    Driver(serialNo: '12', name: 'Romij', truckId: '6037', mobNo: '6002645916'),
    Driver(serialNo: '13', name: 'Bachhu Hussain', truckId: '6412', mobNo: '8897206172'),
    Driver(serialNo: '14', name: 'Shabaj', truckId: '9248', mobNo: '7399239714'),
    Driver(serialNo: '15', name: 'New Siddiki Ahmed', truckId: '9508', mobNo: '8341552695'),
  ];

  void openDriverDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverDetailsPage(drivers: drivers, setLocale: widget.setLocale),
      ),
    );
  }

  void openEmergencyAlerts() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmergencyAlertsPage(setLocale: widget.setLocale),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        title: Row(
          children: [
            Image.asset('assets/truck_icon.png', height: 24, width: 24),
            const SizedBox(width: 8),
            Text(
              AppLocalizations.of(context)!.fleet,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.grey[200],
        child: GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12.0,
          mainAxisSpacing: 12.0,
          padding: const EdgeInsets.all(16.0),
          childAspectRatio: 1.0,
          children: [
            _buildOptionCard(
              icon: Icons.login,
              label: AppLocalizations.of(context)!.login,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginPage(setLocale: widget.setLocale))),
            ),
            _buildOptionCard(
              icon: Icons.mic,
              label: AppLocalizations.of(context)!.aiAssistant,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VoiceAssistantScreen(setLocale: widget.setLocale))),
            ),
            _buildOptionCard(icon: Icons.warning, label: AppLocalizations.of(context)!.emergencyAlerts, onTap: openEmergencyAlerts),
            _buildOptionCard(icon: Icons.person, label: AppLocalizations.of(context)!.driverDetails, onTap: openDriverDetails),
            _buildOptionCard(
              icon: Icons.home,
              label: AppLocalizations.of(context)!.home,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WelcomePage(setLocale: widget.setLocale))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({required IconData icon, required String label, required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: Colors.blue[800]),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: Colors.grey[700])),
            ],
          ),
        ),
      ),
    );
  }
}

class DriverDetailsPage extends StatefulWidget {
  final List<Driver> drivers;
  final Function(Locale) setLocale;

  const DriverDetailsPage({super.key, required this.drivers, required this.setLocale});

  @override
  State<DriverDetailsPage> createState() => _DriverDetailsPageState();
}

class _DriverDetailsPageState extends State<DriverDetailsPage> {
  String searchQuery = '';
  bool isSearching = false;
  final TextEditingController searchController = TextEditingController();
  Map<String, bool> paymentStatus = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPaymentStatus();
  }

  Future<void> _loadPaymentStatus() async {
    try {
      final currentMonth = _getCurrentMonth();
      for (var driver in widget.drivers) {
        final ref = FirebaseDatabase.instance.ref('payments/${driver.truckId}/$currentMonth');
        final snapshot = await ref.get();
        final data = snapshot.value as Map<dynamic, dynamic>?;
        paymentStatus[driver.truckId] = data?['paid'] ?? false;
      }
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading payment status: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  String _getCurrentMonth() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(Driver driver) {
    final query = searchQuery.toLowerCase();
    return driver.name.toLowerCase().contains(query) ||
           driver.mobNo.contains(query) ||
           driver.truckId.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        title: isSearching
            ? TextField(
                controller: searchController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search by name, phone, TM...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
              )
            : Text(
                AppLocalizations.of(context)!.driverDetails,
                style: const TextStyle(color: Colors.white),
              ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isSearching ? Icons.close : Icons.search,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                if (isSearching) {
                  searchQuery = '';
                  searchController.clear();
                }
                isSearching = !isSearching;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              _loadPaymentStatus();
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : widget.drivers.isEmpty
              ? const Center(
                  child: Text(
                    "No drivers found",
                    style: TextStyle(fontSize: 18, color: Colors.red),
                  ),
                )
              : Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.3),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[800],
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Driver Details',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          // Data Table
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowColor: MaterialStateProperty.all(Colors.blue[100]),
                              border: TableBorder.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'S No',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Driver Name',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'TM No.',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Mob No.',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'Salary Status',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                              ],
                              rows: widget.drivers.map((driver) {
                                bool isHighlighted = searchQuery.isNotEmpty && _matchesSearch(driver);
                                bool isPaid = paymentStatus[driver.truckId] ?? false;

                                return DataRow(
                                  color: MaterialStateProperty.all(
                                    isHighlighted ? Colors.yellow[200] : Colors.white,
                                  ),
                                  cells: [
                                    DataCell(
                                      Text(
                                        driver.serialNo,
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        driver.name,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                                          color: isHighlighted ? Colors.blue[900] : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        driver.truckId,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isHighlighted && driver.truckId.contains(searchQuery) 
                                              ? FontWeight.bold 
                                              : FontWeight.normal,
                                          color: isHighlighted && driver.truckId.contains(searchQuery)
                                              ? Colors.blue[900]
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        driver.mobNo,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isHighlighted && driver.mobNo.contains(searchQuery)
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: isHighlighted && driver.mobNo.contains(searchQuery)
                                              ? Colors.blue[900]
                                              : Colors.black87,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isPaid ? Colors.green[100] : Colors.red[100],
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              isPaid ? Icons.check_circle : Icons.cancel,
                                              color: isPaid ? Colors.green[700] : Colors.red[700],
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              isPaid ? 'Paid' : 'Unpaid',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: isPaid ? Colors.green[700] : Colors.red[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}

class EmergencyAlertsPage extends StatelessWidget {
  final Function(Locale) setLocale;

  const EmergencyAlertsPage({super.key, required this.setLocale});

  final String ownerPhone = "1234567890"; // CHANGE THIS

  Future<void> _sendSMS(String message) async {
    final Uri smsUri = Uri(scheme: 'sms', path: ownerPhone, queryParameters: {'body': message});
    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }

  void _shareEmergency(BuildContext context, String title, String message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Share Emergency Alert',
              style: TextStyle(
                color: Colors.blue[800],
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.green, size: 32),
              title: const Text('WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                final text = """
🚨 *EMERGENCY ALERT* 🚨

Alert Type: $title
Message: $message

Owner Contact: $ownerPhone
Time: ${DateTime.now().toString().substring(0, 16)}

Please respond immediately!
                """.trim();
                Share.share(text);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.sms, color: Colors.blue, size: 32),
              title: const Text('SMS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _sendSMS("🚨 EMERGENCY: $title - $message");
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.orange, size: 32),
              title: const Text('Other Apps', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                final text = """
🚨 EMERGENCY ALERT 🚨
Type: $title
Message: $message
Owner: $ownerPhone
Time: ${DateTime.now().toString().substring(0, 16)}
                """.trim();
                Share.share(text);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        title: Text(
          AppLocalizations.of(context)!.emergencyAlerts,
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _alertSection(
                context: context,
                icon: Icons.traffic,
                title: "Heavy Traffic",
                message: "Late due to heavy traffic",
              ),
              const SizedBox(height: 40),
              _alertSection(
                context: context,
                icon: Icons.local_gas_station,
                title: "Petrol Requirement",
                message: "Need petrol",
              ),
              const SizedBox(height: 40),
              _alertSection(
                context: context,
                icon: Icons.fastfood,
                title: "Food Purpose",
                message: "Need food break",
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _alertSection({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Column(
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 180,
              child: ElevatedButton.icon(
                onPressed: () => _sendSMS(message),
                icon: Icon(icon, color: Colors.white),
                label: const Text("Send SMS", style: TextStyle(color: Colors.white, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 120,
              child: ElevatedButton.icon(
                onPressed: () => _shareEmergency(context, title, message),
                icon: const Icon(Icons.share, color: Colors.white, size: 20),
                label: const Text("Share", style: TextStyle(color: Colors.white, fontSize: 14)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange[700],
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}