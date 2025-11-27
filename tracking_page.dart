import 'dart:async';
import 'dart:math' show cos, sqrt, asin;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geocoding/geocoding.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:geolocator/geolocator.dart';

class TrackingPage extends StatefulWidget {
  final String truckId;
  final String phone;
  final Function(Locale) setLocale;

  const TrackingPage({
    super.key,
    required this.truckId,
    required this.phone,
    required this.setLocale,
  });

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  final Completer<GoogleMapController> _controller = Completer();
  Marker? _driverMarker;
  Marker? _userMarker;
  Timer? _timer;
  LatLng _currentPosition = const LatLng(17.385044, 78.486671);
  LatLng? _userPosition;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _feedbackController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  late DatabaseReference _dbRef;
  late DatabaseReference _routeRef;
  late DatabaseReference _paymentRef;
  String _driverName = "John Doe";
  String _placeName = "";
  bool _emergencyShown = false;
  LatLng? _lastPosition;
  DateTime? _lastMoveTime;
  bool _notFoundShown = false;
  bool _mapReady = false;
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  bool _isListening = false;

  // CSV & Search
  List<Map<String, String>> _driversList = [];
  List<Map<String, String>> _filteredDrivers = [];
  OverlayEntry? _overlayEntry;

  // Payment Info
  String _ownerUpiId = "9876543210@paytm";
  String _currentTruckId = "";
  String _currentPhone = "";
  bool _isPaid = false;

  // Rating
  int _selectedRating = 0;

  // Route & Distance
  Set<Polyline> _polylines = {};
  List<LatLng> _routePoints = [];
  double _totalDistanceKm = 0.0;
  bool _isDriverActive = false;
  DateTime? _tripStartTime;
  LatLng? _tripStartLocation;
  String _driverStatus = "Inactive";
  Color _statusColor = Colors.grey;

  // Dark Uber-style Map Theme
  static final String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#1a1a1a"}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#1a1a1a"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2c2c2c"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _currentTruckId = widget.truckId;
    _currentPhone = widget.phone;
    _dbRef = FirebaseDatabase.instance.ref('trucks/$_currentTruckId');
    _routeRef = FirebaseDatabase.instance.ref('routes/$_currentTruckId/${_getTodayDate()}');
    _paymentRef = FirebaseDatabase.instance.ref('payments/$_currentTruckId/${_getCurrentMonth()}');
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _initTts();
    _loadDriversFromCSV();
    _fetchDriverDetails();
    _fetchTodayRoute();
    _fetchDriverStatus();
    _fetchLocation();
    _fetchPaymentStatus();
    _getUserLocation();

    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchLocation();
      _fetchDriverStatus();
      _getUserLocation();
    });

    _searchController.addListener(_onSearchChanged);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _removeOverlay();
    });
  }

  String _getTodayDate() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  String _getCurrentMonth() {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}";
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final userPos = LatLng(position.latitude, position.longitude);
      
      final BitmapDescriptor userIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(40, 40)),
        'assets/user_icon.png',
      ).catchError((_) => BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue));

      setState(() {
        _userPosition = userPos;
        _userMarker = Marker(
          markerId: const MarkerId('user_location'),
          position: userPos,
          icon: userIcon,
          infoWindow: InfoWindow(
            title: "Your Location",
            snippet: "Phone: ${widget.phone}",
          ),
        );
      });
    } catch (e) {
      debugPrint("Error getting user location: $e");
    }
  }

  Future<void> _fetchPaymentStatus() async {
    try {
      final snapshot = await _paymentRef.get();
      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _isPaid = data['paid'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching payment: $e");
    }
  }

  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371;
    double lat1 = start.latitude * (3.141592653589793 / 180);
    double lat2 = end.latitude * (3.141592653589793 / 180);
    double lon1 = start.longitude * (3.141592653589793 / 180);
    double lon2 = end.longitude * (3.141592653589793 / 180);
    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;
    double a = (1 - cos(dLat)) / 2 + cos(lat1) * cos(lat2) * (1 - cos(dLon)) / 2;
    double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  Future<void> _fetchDriverStatus() async {
    try {
      final statusSnapshot = await _dbRef.child('status').get();
      final statusData = statusSnapshot.value as Map<dynamic, dynamic>?;
      if (statusData != null) {
        bool isActive = statusData['isActive'] ?? false;
        String status = statusData['status'] ?? 'Inactive';
        setState(() {
          _isDriverActive = isActive;
          _driverStatus = status;
          _statusColor = isActive ? Colors.green : Colors.red;
        });
      }
    } catch (e) {
      debugPrint("Error fetching status: $e");
    }
  }

  Future<void> _fetchTodayRoute() async {
    try {
      final routeSnapshot = await _routeRef.get();
      final routeData = routeSnapshot.value as Map<dynamic, dynamic>?;

      if (routeData != null && routeData.isNotEmpty) {
        List<LatLng> points = [];
        double totalDistance = 0.0;
        List<dynamic> sortedKeys = routeData.keys.toList()..sort();

        for (var key in sortedKeys) {
          final point = routeData[key] as Map<dynamic, dynamic>;
          double lat = (point['lat'] as num).toDouble();
          double lng = (point['lng'] as num).toDouble();
          points.add(LatLng(lat, lng));
        }

        for (int i = 1; i < points.length; i++) {
          totalDistance += _calculateDistance(points[i - 1], points[i]);
        }

        setState(() {
          _routePoints = points;
          _totalDistanceKm = totalDistance;
          _tripStartLocation = points.first;
          _tripStartTime = DateTime.now();

          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: const Color(0xFF00BFFF),
              width: 6,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              geodesic: true,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          };
        });

        if (points.length > 1 && _mapReady && _controller.isCompleted) {
          _fitRouteToBounds(points);
        }
      } else {
        _createDefaultPolyline();
      }
    } catch (e) {
      debugPrint("Error fetching route: $e");
      _createDefaultPolyline();
    }
  }

  void _createDefaultPolyline() {
    List<LatLng> sample = [
      _currentPosition,
      LatLng(_currentPosition.latitude + 0.01, _currentPosition.longitude + 0.01),
      LatLng(_currentPosition.latitude + 0.02, _currentPosition.longitude - 0.01),
    ];
    setState(() {
      _routePoints = sample;
      _polylines = {
        Polyline(
          polylineId: const PolylineId('default'),
          points: sample,
          color: const Color(0xFF00BFFF).withOpacity(0.6),
          width: 5,
          geodesic: true,
        ),
      };
    });
  }

  Future<void> _fitRouteToBounds(List<LatLng> points) async {
    if (points.isEmpty || !_controller.isCompleted) return;
    double minLat = points.first.latitude, maxLat = minLat;
    double minLng = points.first.longitude, maxLng = minLng;
    for (var p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(minLat, minLng), northeast: LatLng(maxLat, maxLng)),
      80,
    ));
  }

  Future<void> _saveRoutePoint(LatLng position) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      await _routeRef.child(timestamp.toString()).set({
        'lat': position.latitude,
        'lng': position.longitude,
        'timestamp': timestamp,
      });
    } catch (e) {
      debugPrint("Error saving point: $e");
    }
  }

  void _showDistanceDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Today\'s Journey', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('TM No: $_currentTruckId', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            Text('${_totalDistanceKm.toStringAsFixed(2)} km', style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Color(0xFF00BFFF))),
            const Text('Distance Covered', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    const Icon(Icons.play_circle, color: Colors.green, size: 28),
                    const Text('Start', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      _tripStartTime != null ? '${_tripStartTime!.hour}:${_tripStartTime!.minute.toString().padLeft(2, '0')}' : '--:--',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const Text(' to ', style: TextStyle(color: Colors.white, fontSize: 18)),
                Column(
                  children: [
                    const Icon(Icons.location_on, color: Colors.red, size: 28),
                    const Text('Current', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    Text(
                      '${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF00BFFF))),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog() {
    setState(() {
      _selectedRating = 0;
      _feedbackController.clear();
    });

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Rate Our App', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, size: 60, color: Colors.amber),
              const SizedBox(height: 16),
              const Text('How was your experience?', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => setDialogState(() => _selectedRating = i + 1),
                  child: Icon(
                    i < _selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 45,
                    color: i < _selectedRating ? Colors.amber : Colors.grey,
                  ),
                )),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _feedbackController,
                maxLines: 4,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Tell us about your experience (optional)',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey[800],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.white)))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedRating > 0 ? () { Navigator.pop(context); _submitRating(); } : null,
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00BFFF)),
                      child: const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitRating() {
    String feedback = _feedbackController.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Thank you for your feedback!'), backgroundColor: Colors.green),
    );
    try {
      FirebaseDatabase.instance.ref('ratings').push().set({
        'rating': _selectedRating,
        'feedback': feedback,
        'userId': _currentPhone,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint("Error saving rating: $e");
    }
  }

  Future<void> _fetchDriverDetails() async {
    try {
      final snapshot = await _dbRef.get();
      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _driverName = data['name'] ?? _driverName;
          _placeName = data['placeName'] ?? 'Unknown Place';
        });
      }
    } catch (e) {
      debugPrint("Error fetching details: $e");
    }
  }

  Future<void> _fetchLocation() async {
    try {
      final snapshot = await _dbRef.get();
      final data = snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        final lat = (data['lat'] as num?)?.toDouble() ?? 17.385044;
        final lng = (data['long'] as num?)?.toDouble() ?? 78.486671;
        final newPosition = LatLng(lat, lng);

        if (_lastPosition != null && _lastPosition != newPosition) {
          double dist = _calculateDistance(_lastPosition!, newPosition);
          if (dist > 0.05) {
            setState(() {
              _routePoints.add(newPosition);
              _totalDistanceKm += dist;
              _polylines = {
                Polyline(
                  polylineId: const PolylineId('route'),
                  points: _routePoints,
                  color: const Color(0xFF00BFFF),
                  width: 6,
                  patterns: [PatternItem.dash(20), PatternItem.gap(10)],
                ),
              };
            });
            _saveRoutePoint(newPosition);
          }
        } else if (_lastPosition == null && _isDriverActive) {
          setState(() {
            _routePoints = [newPosition];
            _tripStartLocation = newPosition;
            _tripStartTime = DateTime.now();
          });
          _saveRoutePoint(newPosition);
        }

        _lastPosition = newPosition;
        _lastMoveTime = DateTime.now();

        try {
          final placemarks = await placemarkFromCoordinates(lat, lng);
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final parts = [p.locality, p.subLocality, p.administrativeArea, p.country]
                .where((e) => e != null && e.isNotEmpty)
                .toList();
            _placeName = parts.isEmpty ? (p.name ?? 'Unknown') : parts.join(", ");
          }
        } catch (_) {
          _placeName = 'Unknown Place';
        }

        final BitmapDescriptor icon = await BitmapDescriptor.fromAssetImage(
          const ImageConfiguration(size: Size(50, 50)),
          'assets/truck_icon.png',
        ).catchError((_) => BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed));

        setState(() {
          _currentPosition = newPosition;
          _driverMarker = Marker(
            markerId: MarkerId(_currentTruckId),
            position: newPosition,
            icon: icon,
            infoWindow: InfoWindow(
              title: "$_currentTruckId - $_driverName",
              snippet:
                  "Phone: $_currentPhone\nLocation: $_placeName\nDistance: ${_totalDistanceKm.toStringAsFixed(1)} km\nStatus: $_driverStatus",
            ),
          );
        });

        if (_mapReady && _controller.isCompleted) {
          final controller = await _controller.future;
          controller.animateCamera(CameraUpdate.newLatLngZoom(newPosition, 15));
        }
      }
    } catch (e) {
      debugPrint("Error fetching location: $e");
    }
  }

  void _shareLocation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share Location',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.message, color: Colors.green),
              title: const Text('WhatsApp', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                final text = """
🚛 *Live Truck Location*

Driver: $_driverName
📞 Phone: $_currentPhone
🚚 TM No: $_currentTruckId
📍 Location: $_placeName
📏 Distance: ${_totalDistanceKm.toStringAsFixed(1)} km
⏱️ Status: $_driverStatus

🗺️ View on Map:
https://maps.google.com/?q=${_currentPosition.latitude},${_currentPosition.longitude}
                """.trim();
                Share.share(text);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Other Apps', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                final text = """
Driver: $_driverName
Phone: $_currentPhone
TM No: $_currentTruckId
Location: $_placeName
Distance: ${_totalDistanceKm.toStringAsFixed(1)} km
Status: $_driverStatus
Map: https://maps.google.com/?q=${_currentPosition.latitude},${_currentPosition.longitude}
                """.trim();
                Share.share(text);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);
      _speech.listen(onResult: (result) {
        setState(() => _searchController.text = result.recognizedWords);
        _tts.speak(result.recognizedWords);
      });
    }
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  void _showQRCodeDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Pay Driver Salary', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Scan QR Code to Pay',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: 'upi://pay?pa=$_ownerUpiId&pn=Driver-${_driverName.replaceAll(' ', '')}&am=&cu=INR&tn=Salary-$_currentTruckId',
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Driver: $_driverName',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TM No: $_currentTruckId',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'UPI: $_ownerUpiId',
                    style: const TextStyle(color: Color(0xFF00BFFF), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  _isPaid ? Icons.check_circle : Icons.cancel,
                  color: _isPaid ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isPaid ? 'Salary Paid' : 'Payment Pending',
                  style: TextStyle(
                    color: _isPaid ? Colors.green : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Color(0xFF00BFFF))),
          ),
          if (!_isPaid)
            ElevatedButton(
              onPressed: () {
                _markAsPaid();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Mark as Paid'),
            ),
        ],
      ),
    );
  }

  Future<void> _markAsPaid() async {
    try {
      await _paymentRef.set({
        'paid': true,
        'paidOn': DateTime.now().toIso8601String(),
        'driverName': _driverName,
        'truckId': _currentTruckId,
        'month': _getCurrentMonth(),
      });
      setState(() => _isPaid = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment marked as paid'), backgroundColor: Colors.green),
      );
    } catch (e) {
      debugPrint("Error marking payment: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error updating payment'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-IN');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(0.5);
  }

  Future<void> _loadDriversFromCSV() async {
    try {
      final rawData = await rootBundle.loadString('assets/Driver_List_Attendance.csv');
      List<List<dynamic>> listData = const CsvToListConverter().convert(rawData);
      for (int i = 1; i < listData.length; i++) {
        if (listData[i].length >= 4) {
          _driversList.add({
            'sNo': listData[i][0].toString(),
            'name': listData[i][1].toString().trim(),
            'tmNo': listData[i][2].toString().trim(),
            'phone': listData[i][3].toString().trim(),
          });
        }
      }
    } catch (e) {
      _createSampleDriversData();
    }
  }

  void _createSampleDriversData() {
    _driversList = [
      {'sNo': '1', 'name': 'Sanjay', 'tmNo': '9877', 'phone': '8591126176'},
      {'sNo': '2', 'name': 'Abdul Kuim', 'tmNo': '9878', 'phone': '8011054324'},
      {'sNo': '3', 'name': 'Raja', 'tmNo': '3052', 'phone': '6026911206'},
      {'sNo': '4', 'name': 'Miraj Ali', 'tmNo': '1654', 'phone': '6303678937'},
      {'sNo': '5', 'name': 'Siraj Ali', 'tmNo': '9876', 'phone': '6301418034'},
    ];
  }

  void _onSearchChanged() {
    String query = _searchController.text.toLowerCase().trim();
    if (query.isEmpty) {
      _removeOverlay();
      setState(() => _filteredDrivers = []);
      return;
    }
    _filteredDrivers = _driversList.where((d) {
      return (d['name']?.toLowerCase().contains(query) ?? false) ||
             (d['phone']?.contains(query) ?? false) ||
             (d['tmNo']?.contains(query) ?? false);
    }).toList();
    setState(() {});
    if (_filteredDrivers.isNotEmpty && _focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = OverlayEntry(
      builder: (_) => Positioned(
        width: 300,
        child: CompositedTransformFollower(
          link: _layerLink,
          offset: const Offset(0, 56),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _filteredDrivers.length,
              itemBuilder: (_, i) {
                final driver = _filteredDrivers[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(driver['name']?[0] ?? 'D')),
                  title: Text(driver['name'] ?? ''),
                  subtitle: Text('TM: ${driver['tmNo']} | ${driver['phone']}'),
                  onTap: () => _selectDriver(driver),
                );
              },
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectDriver(Map<String, String> driver) {
    _removeOverlay();
    setState(() {
      _searchController.text = driver['name'] ?? '';
      _driverName = driver['name'] ?? '';
      _currentPhone = driver['phone'] ?? '';
      _currentTruckId = driver['tmNo'] ?? '';
      _routePoints = [];
      _polylines = {};
      _totalDistanceKm = 0.0;
      _isPaid = false;
    });

    _dbRef = FirebaseDatabase.instance.ref('trucks/$_currentTruckId');
    _routeRef = FirebaseDatabase.instance.ref('routes/$_currentTruckId/${_getTodayDate()}');
    _paymentRef = FirebaseDatabase.instance.ref('payments/$_currentTruckId/${_getCurrentMonth()}');

    _notFoundShown = false;
    _emergencyShown = false;
    _lastPosition = null;
    _lastMoveTime = null;

    _fetchTodayRoute();
    _fetchDriverStatus();
    _fetchLocation();
    _fetchPaymentStatus();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    Set<Marker> markers = {};
    if (_driverMarker != null) markers.add(_driverMarker!);
    if (_userMarker != null) markers.add(_userMarker!);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Track Truck', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(width: 10),
            SizedBox(
              width: 300,
              child: CompositedTransformTarget(
                link: _layerLink,
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Search driver, phone, TM...',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                            _searchController.clear();
                            _removeOverlay();
                            setState(() => _filteredDrivers = []);
                          })
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _removeOverlay(),
                ),
              ),
            ),
            IconButton(
              icon: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
              onPressed: _isListening ? _stopListening : _startListening,
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1A1A1A),
        actions: [
          IconButton(icon: const Icon(Icons.route, color: Colors.white), onPressed: _showDistanceDialog),
          IconButton(icon: const Icon(Icons.star, color: Colors.amber), onPressed: _showRatingDialog),
          IconButton(icon: const Icon(Icons.qr_code_scanner, color: Colors.white), onPressed: _showQRCodeDialog),
          IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: _shareLocation),
        ],
        toolbarHeight: 70,
      ),
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 12),
            myLocationEnabled: true,
            markers: markers,
            polylines: _polylines,
            onMapCreated: (controller) async {
              if (!_controller.isCompleted) {
                _controller.complete(controller);
                setState(() => _mapReady = true);
                controller.setMapStyle(_darkMapStyle);
              }
            },
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _statusColor, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(_isDriverActive ? Icons.circle : Icons.circle_outlined, color: _statusColor, size: 14),
                  const SizedBox(width: 6),
                  Text(_driverStatus, style: TextStyle(color: _statusColor, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          if (_totalDistanceKm > 0)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Icons.timeline, color: Color(0xFF00BFFF), size: 16),
                    const SizedBox(width: 6),
                    Text('${_totalDistanceKm.toStringAsFixed(1)} km', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 60,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isPaid ? Colors.green : Colors.red, width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(_isPaid ? Icons.check_circle : Icons.money_off, color: _isPaid ? Colors.green : Colors.red, size: 14),
                  const SizedBox(width: 6),
                  Text(_isPaid ? 'Paid' : 'Unpaid', style: TextStyle(color: _isPaid ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_routePoints.length > 1)
            FloatingActionButton(
              heroTag: 'route',
              mini: true,
              backgroundColor: Colors.black87,
              onPressed: () => _fitRouteToBounds(_routePoints),
              child: const Icon(Icons.route, color: Color(0xFF00BFFF)),
            ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'locate',
            backgroundColor: Colors.black87,
            onPressed: () async {
              if (_driverMarker != null && _controller.isCompleted) {
                final c = await _controller.future;
                c.animateCamera(CameraUpdate.newLatLngZoom(_driverMarker!.position, 16));
              }
            },
            child: const Icon(Icons.my_location, color: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    _feedbackController.dispose();
    _focusNode.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }
}