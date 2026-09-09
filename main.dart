import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;

const String backendUrl = 'http://localhost:3000';

void main() => runApp(const MaterialApp(home: RailPulseDashboard(), debugShowCheckedModeBanner: false));

class RailPulseDashboard extends StatefulWidget {
  const RailPulseDashboard({super.key});

  @override
  State<RailPulseDashboard> createState() => _RailPulseDashboardState();
}

class _RailPulseDashboardState extends State<RailPulseDashboard> {
  Map<String, dynamic>? _selectedTrain;
  List<dynamic> _trackedTrains = [];
  List<dynamic> _notifications = [];
  List<String> _availableLanguages = ["English", "Hindi", "Marathi", "Telugu"];
  
  String _activeTrainId = "12002";
  String _activeFilter = "All";
  String _selectedLanguage = "English";

  final Map<String, Map<String, String>> _translations = {
    "English": {
      "RAILPULSE": "RAILPULSE",
      "ETA INTELLIGENCE": "ETA INTELLIGENCE",
      "NETWORK LIVE": "NETWORK LIVE",
      "Search train  K": "Search train  K",
      "Tracked Trains": "Tracked Trains",
      "My saved routes": "My saved routes",
      "All": "All",
      "Delayed": "Delayed",
      "On Time": "On Time",
      "+ Track another train": "+ Track another train",
      "Station Timeline": "Station Timeline",
      "Operations": "Operations",
      "CONTROL ROOM": "CONTROL ROOM",
      "Current delay": "Current delay",
      "Predicted delay": "Predicted delay",
      "Confidence": "Confidence",
      "Next station": "Next station",
      "Predicted ETA": "Predicted ETA",
      "Notifications": "Notifications",
      "Predicted arrival": "Predicted arrival",
      "DELAY CONTRIBUTORS": "DELAY CONTRIBUTORS",
      "ROUTE PROGRESS": "ROUTE PROGRESS"
    },
    "Hindi": {
      "RAILPULSE": "रेलपल्स",
      "ETA INTELLIGENCE": "ईटीए इंटेलिजेंस",
      "NETWORK LIVE": "नेटवर्क लाइव",
      "Search train  K": "ट्रेन खोजें K",
      "Tracked Trains": "ट्रैक की गई ट्रेनें",
      "My saved routes": "मेरे सहेजे गए मार्ग",
      "All": "सभी",
      "Delayed": "विलंबित",
      "On Time": "समय पर",
      "+ Track another train": "+ दूसरी ट्रेन ट्रैक करें",
      "Station Timeline": "स्टेशन टाइमलाइन",
      "Operations": "परिचालन",
      "CONTROL ROOM": "नियंत्रण कक्ष",
      "Current delay": "वर्तमान देरी",
      "Predicted delay": "अनुमानित देरी",
      "Confidence": "विश्वास",
      "Next station": "अगला स्टेशन",
      "Predicted ETA": "अनुमानित समय",
      "Notifications": "सूचनाएं",
      "Predicted arrival": "अनुमानित आगमन",
      "DELAY CONTRIBUTORS": "देरी के कारक",
      "ROUTE PROGRESS": "मार्ग की प्रगति"
    }
  };

  String _t(String key) => _translations[_selectedLanguage]?[key] ?? key;
  
  final TextEditingController _searchController = TextEditingController();
  late IO.Socket _socket;

  @override
  void initState() {
    super.initState();
    _fetchDashboard(_activeTrainId);
    _fetchNotifications();
    _connectWebSocket();
  }

  Future<void> _fetchDashboard(String trainId) async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/api/dashboard?trainId=$trainId&lang=$_selectedLanguage'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _selectedTrain = data['selected_train'];
          _trackedTrains = data['tracked_trains'] ?? [];
          _activeTrainId = trainId;
          if (data['languages'] != null) {
            _availableLanguages = List<String>.from(data['languages']);
          }
        });
      }
    } catch (e) {
      debugPrint("Fetch error: $e");
    }
  }

  Future<void> _fetchNotifications() async {
    try {
      final res = await http.get(Uri.parse('$backendUrl/api/notifications?lang=$_selectedLanguage'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _notifications = data['notifications'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Notification error: $e");
    }
  }

  Future<void> _searchTrain(String query) async {
    if (query.trim().isEmpty) return;
    try {
      final res = await http.get(Uri.parse('$backendUrl/api/search?q=$query&lang=$_selectedLanguage'));
      if (res.statusCode == 200) {
        final results = json.decode(res.body) as List<dynamic>;
        if (results.isNotEmpty) {
          _fetchDashboard(results.first['number'].toString());
        }
      }
    } catch (e) {
      debugPrint("Search error: $e");
    }
  }

  void _trackNewTrainDialog() {
    showDialog(
      context: context,
      builder: (context) => TrainSearchDialog(
        selectedLanguage: _selectedLanguage,
        onTrainSelected: (trainId) async {
          await _addNewTrackedTrain(trainId);
        },
      ),
    );
  }

  Future<void> _addNewTrackedTrain(String trainId) async {
    try {
      final res = await http.post(
        Uri.parse('$backendUrl/api/track-train'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'trainId': trainId, 'lang': _selectedLanguage}),
      );
      if (res.statusCode == 200) {
        final newTrain = json.decode(res.body);
        _fetchDashboard(newTrain['number'].toString());
      }
    } catch (e) {
      debugPrint("Add train error: $e");
    }
  }

  void _removeTrackedTrain(String trainId) {
    setState(() {
      _trackedTrains.removeWhere((t) => t['number'].toString() == trainId);
      if (_activeTrainId == trainId && _trackedTrains.isNotEmpty) {
        _activeTrainId = _trackedTrains.first['number'].toString();
        _fetchDashboard(_activeTrainId);
      }
    });
  }

  void _showNotificationPanel() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        height: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_t("Notifications"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                IconButton(icon: const Icon(Icons.close, size: 16), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _notifications.length,
                itemBuilder: (context, idx) {
                  final item = _notifications[idx];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.info_outline, color: Color(0xFF0284C7), size: 18),
                    title: Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    subtitle: Text(item['message'] ?? '', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  void _connectWebSocket() {
    _socket = IO.io(backendUrl, IO.OptionBuilder().setTransports(['websocket']).enableAutoConnect().build());
    _socket.on('dashboard_update', (data) {
      if (mounted && data['trains'] != null && data['trains'][_activeTrainId] != null) {
        setState(() {
          _selectedTrain = Map<String, dynamic>.from(data['trains'][_activeTrainId]);
        });
      }
    });
  }

  @override
  void dispose() {
    _socket.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildFilterBtn(String label, String filterKey) {
    bool isActive = _activeFilter == filterKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeFilter = filterKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(color: isActive ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(4)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? const Color(0xFF0F172A) : Colors.grey)),
        ),
      ),
    );
  }

  Widget _buildMetricBox(String title, String val, Color valColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(4)),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 7, color: Colors.grey), maxLines: 1),
            const SizedBox(height: 2),
            Text(val, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: valColor)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedTrain == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    List<dynamic> filteredTrains = _trackedTrains.where((t) {
      if (_activeFilter == "Delayed") return t['is_delayed'] == true;
      if (_activeFilter == "On Time") return t['is_delayed'] == false;
      return true;
    }).toList();

    int delayedCount = _trackedTrains.where((t) => t['is_delayed'] == true).length;
    int onTimeCount = _trackedTrains.length - delayedCount;

    final dynamic rawSpeed = _selectedTrain!['speed'];
    final String currentSpeedText = (rawSpeed != null) ? "$rawSpeed km/h" : "103 km/h";

    // Extract station timeline dynamically for painter labels
    List<dynamic> stationList = _selectedTrain!['timeline'] ?? [
      {"name": "Mumbai Central"},
      {"name": "Vadodara"},
      {"name": "Kota"},
      {"name": "New Delhi"}
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // TOP HEADER
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.white,
            child: Row(
              children: [
                Row(
                  children: [
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: const Color(0xFF0284C7), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.train, color: Colors.white, size: 18)),
                    const SizedBox(width: 8),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_t("RAILPULSE"), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Color(0xFF0284C7), letterSpacing: 0.5)),
                        Text(_t("ETA INTELLIGENCE"), style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.8)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Row(
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_t("NETWORK LIVE"), style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const Text("Last sync 10 sec ago", style: TextStyle(fontSize: 8, color: Colors.grey)),
                      ],
                    )
                  ],
                ),
                const Spacer(),
                SizedBox(
                  width: 200,
                  height: 34,
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (val) => _searchTrain(val),
                    decoration: InputDecoration(
                      hintText: _t("Search train  K"),
                      hintStyle: const TextStyle(fontSize: 11, color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, size: 16, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFF0284C7))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      isDense: true,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedLanguage = val);
                          _fetchDashboard(_activeTrainId);
                        }
                      },
                      items: _availableLanguages.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _showNotificationPanel,
                  child: Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFE2E8F0))),
                    child: const Icon(Icons.notifications_none, size: 18, color: Color(0xFF334155)),
                  ),
                ),
                const SizedBox(width: 12),
                const CircleAvatar(radius: 16, backgroundColor: Color(0xFF0F172A), child: Text("RV", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // MAIN CONTENT AREA
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. LEFT TRACKED TRAINS SIDEBAR
                Container(
                  width: 280,
                  color: const Color(0xFFF8FAFC),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("TRACKED · LIVE", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                      Text(_t("Tracked Trains"), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                      Text(_t("My saved routes"), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(6)),
                        child: Row(
                          children: [
                            _buildFilterBtn("${_t('All')} ${_trackedTrains.length}", "All"),
                            _buildFilterBtn("${_t('Delayed')} $delayedCount", "Delayed"),
                            _buildFilterBtn("${_t('On Time')} $onTimeCount", "On Time"),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: ListView(
                          children: filteredTrains.map((t) {
                            bool isSelected = t['number'].toString() == _activeTrainId;
                            if (isSelected) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF0284C7), width: 1.5),
                                ),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF0284C7),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Icon(Icons.train, color: Colors.white, size: 14),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  "${t['number']} ${t['name'] ?? ''}",
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: t['is_delayed'] == true ? Colors.red : Colors.green,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  t['delay'] ?? 'On Time',
                                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              InkWell(
                                                onTap: () => _removeTrackedTrain(t['number'].toString()),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(2.0),
                                                  child: Icon(Icons.close, size: 16, color: Colors.grey),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: const [
                                              Text("Mumbai Central", style: TextStyle(fontSize: 9, color: Colors.grey)),
                                              Text("New Delhi", style: TextStyle(fontSize: 9, color: Colors.grey)),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          LinearProgressIndicator(
                                            value: 0.6,
                                            backgroundColor: Colors.grey.shade200,
                                            color: const Color(0xFF0284C7),
                                            minHeight: 3,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              _buildMetricBox(_t("Current delay"), _selectedTrain!['status_tag'] ?? '+18 min', Colors.red),
                                              const SizedBox(width: 4),
                                              _buildMetricBox(_t("Predicted delay"), "+24 min", const Color(0xFF0F172A)),
                                              const SizedBox(width: 4),
                                              _buildMetricBox(_t("Confidence"), "87%", const Color(0xFF0F172A)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: const [
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text("Next station", style: TextStyle(fontSize: 7, color: Colors.grey)),
                                                    Text("Vadodara Junction", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                                                  ],
                                                ),
                                                Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  children: [
                                                    Text("Predicted ETA", style: TextStyle(fontSize: 7, color: Colors.grey)),
                                                    Text("18:42", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 9)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0F172A),
                                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(currentSpeedText, style: const TextStyle(color: Colors.white, fontSize: 8)),
                                          const Text("PF 3", style: TextStyle(color: Colors.white, fontSize: 8)),
                                          const Text("GPS - 10s ago", style: TextStyle(color: Colors.white, fontSize: 8)),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              );
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: ListTile(
                                dense: true,
                                onTap: () => _fetchDashboard(t['number'].toString()),
                                leading: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0F2FE),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.train, color: Color(0xFF0284C7), size: 14),
                                ),
                                title: Text("${t['number']} ${t['name'] ?? ''}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                                subtitle: Text(t['route'] ?? '', style: const TextStyle(fontSize: 8, color: Colors.grey)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: (t['is_delayed'] == true) ? Colors.orange.shade800 : Colors.green,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        t['delay'] ?? 'On Time',
                                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      icon: const Icon(Icons.close, size: 14, color: Colors.grey),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _removeTrackedTrain(t['number'].toString()),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: _trackNewTrainDialog,
                        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 32), side: const BorderSide(color: Color(0xFFCBD5E1))),
                        child: Text(_t("+ Track another train"), style: const TextStyle(fontSize: 10, color: Color(0xFF0284C7))),
                      ),
                    ],
                  ),
                ),

                // 2. MIDDLE DASHBOARD
                Expanded(
                  flex: 2,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TITLE HEADER
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("${_selectedTrain!['number']} ${_selectedTrain!['name'] ?? ''}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                Text(_selectedTrain!['corridor'] ?? 'Western Corridor (Mumbai - Delhi)', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                              ],
                            ),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(16)),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.speed, size: 14, color: Colors.cyanAccent),
                                      const SizedBox(width: 6),
                                      Text(currentSpeedText, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(12)),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.sensors, size: 12, color: Color(0xFF0284C7)),
                                      SizedBox(width: 4),
                                      Text("Live GPS", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text("Updated 10s ago", style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 12),

                        // CUSTOM CANVAS ROUTE MAP (EXACT VISUAL REPRODUCTION)
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: MapRoutePainter(stations: stationList),
                                ),
                              ),
                              Positioned(
                                top: 12,
                                left: 16,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("NETWORK LIVE", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                    const SizedBox(height: 2),
                                    Text(_selectedTrain!['corridor'] ?? 'Western Corridor (Mumbai - Delhi)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  ],
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                left: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFCBD5E1))),
                                  child: const Text("Moderate rain - Vadodara sector", style: TextStyle(fontSize: 8, color: Color(0xFF334155))),
                                ),
                              ),
                              Positioned(
                                bottom: 12,
                                right: 16,
                                child: Row(
                                  children: [
                                    Container(width: 12, height: 2, color: const Color(0xFFEF4444)),
                                    const SizedBox(width: 4),
                                    const Text("Active route", style: TextStyle(fontSize: 8, color: Colors.grey)),
                                    const SizedBox(width: 10),
                                    Container(width: 12, height: 2, color: Colors.grey.shade400),
                                    const SizedBox(width: 4),
                                    const Text("Other corridors", style: TextStyle(fontSize: 8, color: Colors.grey)),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // TIMELINE & OPERATIONS SECTION
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // STATION TIMELINE
                            Expanded(
                              flex: 3,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("ROUTE PROGRESS", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    const Text("Station Timeline", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                    const SizedBox(height: 12),
                                    ...((_selectedTrain!['timeline'] as List<dynamic>? ?? []).asMap().entries.map((entry) {
                                      int idx = entry.key;
                                      var st = entry.value;
                                      bool isDone = idx == 0;
                                      bool isNext = idx == 1;
                                      String subtitle = isDone 
                                          ? "Departed on time" 
                                          : (isNext ? "Next Stop • Platform 3" : "Upcoming Stop");

                                      return _buildTimelineRow(
                                        st['name'] ?? '',
                                        subtitle,
                                        st['actual'] ?? st['scheduled'] ?? '--:--',
                                        isDone,
                                        isNext: isNext,
                                      );
                                    }).toList()),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // CONTROL ROOM OPERATIONS
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE2E8F0))),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("CONTROL ROOM", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                                    const Text("Operations", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        _buildOpMetric("Trains monitored", "248", "410 total users"),
                                        _buildOpMetric("Active delays", "37", "3 critical"),
                                        _buildOpMetric("Avg delay", "8.4m", "- 1.2%"),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(6)),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.auto_awesome, color: Color(0xFF0284C7), size: 16),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: const [
                                                Text("Reschedule suggestion ready", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF0284C7))),
                                                Text("Platform conflict at Vadodara. Reroute impact", style: TextStyle(fontSize: 7, color: Colors.grey)),
                                              ],
                                            ),
                                          ),
                                          const Icon(Icons.chevron_right, size: 14, color: Colors.grey),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),

                // 3. RIGHT SIDEBAR (ETA INTELLIGENCE)
                Container(
                  width: 280,
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("AI PREDICTION", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text(_t("ETA INTELLIGENCE"), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Predicted arrival", style: TextStyle(fontSize: 8, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(_selectedTrain!['predicted_eta'] ?? "18:42", style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                              child: Text(_selectedTrain!['status_tag'] ?? "+18 min", style: const TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(value: 0.87, backgroundColor: Colors.grey.shade800, color: Colors.green),
                            const SizedBox(height: 2),
                            const Text("87% model confidence", style: TextStyle(fontSize: 7, color: Colors.grey)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(_t("DELAY CONTRIBUTORS"), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      _buildContributorRow("Signal hold", "Central junction", "+11m"),
                      _buildContributorRow("Weather impact", "AccuWeather feed", "+6m"),
                      _buildContributorRow("Speed restriction", "Section 402", "+3m"),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFCD34D))),
                        child: Row(
                          children: const [
                            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text("ETA calculated: Updated 12m ago due to signal hold at Vadodara Junction (+12 min)", style: TextStyle(fontSize: 8, color: Colors.black87)),
                            )
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text("Prediction accuracy", style: TextStyle(fontSize: 8, color: Colors.grey)),
                          Text("94.2%", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 30,
                        width: double.infinity,
                        child: CustomPaint(painter: SparklinePainter()),
                      ),
                      const SizedBox(height: 2),
                      const Text("Last 24 hours, 1,240 predictions", style: TextStyle(fontSize: 7, color: Colors.grey)),
                    ],
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineRow(String station, String subtitle, String time, bool isDone, {bool isNext = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : (isNext ? Icons.train : Icons.radio_button_unchecked),
            size: 16,
            color: isDone ? Colors.grey : (isNext ? const Color(0xFF0284C7) : Colors.grey.shade400),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(station, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isNext ? const Color(0xFF0284C7) : const Color(0xFF0F172A))),
                Text(subtitle, style: const TextStyle(fontSize: 8, color: Colors.grey)),
              ],
            ),
          ),
          Text(time, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildOpMetric(String label, String value, String sub) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        Text(label, style: const TextStyle(fontSize: 7, color: Colors.grey)),
        Text(sub, style: const TextStyle(fontSize: 7, color: Colors.redAccent)),
      ],
    );
  }

  Widget _buildContributorRow(String title, String subtitle, String delay) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(6)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
              Text(subtitle, style: const TextStyle(fontSize: 7, color: Colors.grey)),
            ],
          ),
          Text(delay, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.redAccent)),
        ],
      ),
    );
  }
}

// FULL CANVAS MAP ROUTE PAINTER (MATCHES FIRST DESIGN)
class MapRoutePainter extends CustomPainter {
  final List<dynamic> stations;

  MapRoutePainter({required this.stations});

  @override
  void paint(Canvas canvas, Size size) {
    // Red active route line
    final linePaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startPoint = Offset(size.width * 0.20, size.height * 0.72);
    final endPoint = Offset(size.width * 0.78, size.height * 0.28);

    // Draw main red track line
    canvas.drawLine(startPoint, endPoint, linePaint);

    // Default station names if timeline array is not provided
    List<String> defaultNames = ["Mumbai", "Vadodara", "Kota", "New Delhi"];

    int stationCount = stations.isNotEmpty ? stations.length : 4;

    for (int i = 0; i < stationCount; i++) {
      double t = i / (stationCount - 1);
      double x = startPoint.dx + (endPoint.dx - startPoint.dx) * t;
      double y = startPoint.dy + (endPoint.dy - startPoint.dy) * t;
      Offset stationPos = Offset(x, y);

      String name = (i < stations.length && stations[i]['name'] != null)
          ? stations[i]['name']
          : (i < defaultNames.length ? defaultNames[i] : "Station ${i + 1}");

      // Node styling (Vadodara highlighted in red solid circle)
      final outerDot = Paint()..color = const Color(0xFFEF4444);
      final whiteInner = Paint()..color = Colors.white;

      canvas.drawCircle(stationPos, 6, outerDot);
      canvas.drawCircle(stationPos, 3, whiteInner);

      // Station Text Label below dot
      TextSpan span = TextSpan(
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
        text: name,
      );

      TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      tp.layout();

      tp.paint(canvas, Offset(x - (tp.width / 2), y + 8));
    }
  }

  @override
  bool shouldRepaint(covariant MapRoutePainter oldDelegate) {
    return oldDelegate.stations != stations;
  }
}

// SPARKLINE GRAPH PAINTER
class SparklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    path.lineTo(size.width * 0.2, size.height * 0.4);
    path.lineTo(size.width * 0.4, size.height * 0.8);
    path.lineTo(size.width * 0.6, size.height * 0.2);
    path.lineTo(size.width * 0.8, size.height * 0.5);
    path.lineTo(size.width, size.height * 0.3);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// FULL TRAIN SELECTION DIALOG
class TrainSearchDialog extends StatefulWidget {
  final String selectedLanguage;
  final Function(String trainId) onTrainSelected;

  const TrainSearchDialog({super.key, required this.selectedLanguage, required this.onTrainSelected});

  @override
  State<TrainSearchDialog> createState() => _TrainSearchDialogState();
}

class _TrainSearchDialogState extends State<TrainSearchDialog> {
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, String>> _defaultTrains = [
    {"number": "00961", "name": "VALLEY QUEEN SPL", "route": "Express Route"},
    {"number": "00962", "name": "VALLEY QUEEN SPL", "route": "Express Route"},
    {"number": "01007", "name": "LTT LUR SPL", "route": "Express Route"},
    {"number": "01008", "name": "LUR LTT SPL", "route": "Express Route"},
    {"number": "01009", "name": "LTT DNR SF SPL", "route": "Express Route"},
    {"number": "12002", "name": "SHATABDI EXPRESS", "route": "New Delhi - Bhopal Junction"},
    {"number": "12951", "name": "MUMBAI RAJDHANI", "route": "Mumbai Central - New Delhi"},
    {"number": "12952", "name": "NDLS TEJAS RAJ", "route": "New Delhi - Mumbai Central"},
    {"number": "12009", "name": "SHATABDI EXPRESS", "route": "Mumbai Central - Ahmedabad"},
  ];

  List<Map<String, String>> _filteredTrains = [];

  @override
  void initState() {
    super.initState();
    _filteredTrains = List.from(_defaultTrains);
  }

  void _filterList(String query) {
    setState(() {
      if (query.trim().isEmpty) {
        _filteredTrains = List.from(_defaultTrains);
      } else {
        _filteredTrains = _defaultTrains.where((train) {
          final numberMatch = train['number']!.contains(query);
          final nameMatch = train['name']!.toLowerCase().contains(query.toLowerCase());
          return numberMatch || nameMatch;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 480,
        height: 520,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Select a Train to Track", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: _filterList,
              decoration: InputDecoration(
                hintText: "Search train...",
                hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                prefixIcon: const Icon(Icons.search, size: 18, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _filteredTrains.isEmpty
                  ? const Center(child: Text("No trains found", style: TextStyle(color: Colors.grey, fontSize: 12)))
                  : ListView.separated(
                      itemCount: _filteredTrains.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      itemBuilder: (context, index) {
                        final train = _filteredTrains[index];
                        return ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.train, color: Color(0xFF0284C7), size: 16),
                          ),
                          title: Text("${train['number']} ${train['name']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A))),
                          subtitle: Text(train['route'] ?? "Express Route", style: const TextStyle(fontSize: 9, color: Colors.grey)),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0284C7), size: 20),
                            onPressed: () {
                              Navigator.of(context).pop();
                              widget.onTrainSelected(train['number']!);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}