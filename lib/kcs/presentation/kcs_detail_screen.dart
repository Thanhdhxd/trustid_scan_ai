import 'package:flutter/material.dart';

// Theme Constants
const Color kPrimaryColor = Color(0xFF00875A);
const Color kBackgroundDark = Color(0xFF0F2B46);
const Color kSurfaceDark = Color(0xFF16325B);
const Color kTextLight = Color(0xFFE8EDF3);
const Color kTextGray = Color(0xFF94A3B8);
class KcsDetailScreen extends StatefulWidget {
  final String identifier; // KCS ID or username

  const KcsDetailScreen({Key? key, required this.identifier}) : super(key: key);

  @override
  _KcsDetailScreenState createState() => _KcsDetailScreenState();
}

class _KcsDetailScreenState extends State<KcsDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _statsData;

  List<dynamic> _assignedAreas = [];
  List<dynamic> _inspections = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Mocking API call for now, assuming HttpClient is available
      // final response = await HttpClient.get('/farm/kcs/${widget.identifier}/profile');
      // final areasResponse = await HttpClient.get('/farm/kcs/${widget.identifier}/assigned-areas');
      // final inspResponse = await HttpClient.get('/farm/kcs/${widget.identifier}/inspections');
      
      // Simulating data
      _profileData = {
        'fullName': 'Nguyễn Văn KCS',
        'username': widget.identifier,
        'status': 'ACTIVE'
      };
      _statsData = {
        'totalAssignedAreas': 5,
        'pendingInspections': 2
      };
      
    } catch (e) {
      debugPrint('Error loading KCS data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bộ lọc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextLight)),
              const SizedBox(height: 20),
              // Filter options would go here
              const Text('Trạng thái', style: TextStyle(color: kTextGray)),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilterChip(
                    label: const Text('Đạt', style: TextStyle(color: kTextLight)), 
                    backgroundColor: kBackgroundDark,
                    selectedColor: kPrimaryColor,
                    onSelected: (v) {}
                  ),
                  const SizedBox(width: 10),
                  FilterChip(
                    label: const Text('Không đạt', style: TextStyle(color: kTextLight)), 
                    backgroundColor: kBackgroundDark,
                    selectedColor: Colors.redAccent,
                    onSelected: (v) {}
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: kPrimaryColor),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Áp dụng', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(backgroundColor: kBackgroundDark, body: Center(child: CircularProgressIndicator(color: kPrimaryColor)));
    }

    return Scaffold(
      backgroundColor: kBackgroundDark,
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                floating: false,
                backgroundColor: kBackgroundDark,
                iconTheme: const IconThemeData(color: kTextGray),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: kBackgroundDark,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 40),
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kPrimaryColor.withOpacity(0.5), width: 2),
                          ),
                          child: const CircleAvatar(
                            radius: 40,
                            backgroundImage: NetworkImage('https://cube.elemecdn.com/3/7c/3ea6beec64369c2642b92c6726f1epng.png'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _profileData?['fullName'] ?? 'Chưa cập nhật',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kTextLight),
                        ),
                        Text(_profileData?['username'] ?? '', style: const TextStyle(color: kTextGray)),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatItem('Vùng trồng', _statsData?['totalAssignedAreas']?.toString() ?? '0'),
                            const SizedBox(width: 30),
                            _buildStatItem('Chờ duyệt', _statsData?['pendingInspections']?.toString() ?? '0', color: Colors.orange),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  labelColor: kPrimaryColor,
                  unselectedLabelColor: kTextGray,
                  indicatorColor: kPrimaryColor,
                  tabs: const [
                    Tab(text: 'Đến hạn'),
                    Tab(text: 'Vùng trồng'),
                    Tab(text: 'Lịch sử'),
                  ],
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildUpcomingTab(),
              _buildAreasTab(),
              _buildHistoryTab(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFilterBottomSheet,
        backgroundColor: kPrimaryColor,
        child: const Icon(Icons.filter_list, color: Colors.white),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color ?? kTextLight)),
        Text(label, style: const TextStyle(fontSize: 12, color: kTextGray)),
      ],
    );
  }

  Widget _buildUpcomingTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 2, // Mock count
      itemBuilder: (context, index) {
        return Card(
          color: kSurfaceDark,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withOpacity(0.1))),
          child: ListTile(
            title: const Text('Thửa số 01 - Vùng A', style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold)),
            subtitle: const Text('Trạng thái: Đang chờ', style: TextStyle(color: kTextGray)),
            trailing: const Icon(Icons.warning, color: Colors.orange),
            onTap: () {},
          ),
        );
      },
    );
  }

  Widget _buildAreasTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3, // Mock count
      itemBuilder: (context, index) {
        return Card(
          color: kSurfaceDark,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withOpacity(0.1))),
          child: const ListTile(
            title: Text('Vùng trồng GlobalGAP', style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold)),
            subtitle: Text('Diện tích: 5 ha', style: TextStyle(color: kTextGray)),
            leading: Icon(Icons.landscape, color: kPrimaryColor),
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4, // Mock count
      itemBuilder: (context, index) {
        return Card(
          color: kSurfaceDark,
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.black.withOpacity(0.1))),
          child: const ListTile(
            title: Text('Kiểm định trước thu hoạch', style: TextStyle(color: kTextLight, fontWeight: FontWeight.bold)),
            subtitle: Text('Kết quả: Đạt', style: TextStyle(color: kTextGray)),
            trailing: Icon(Icons.check_circle, color: kPrimaryColor),
          ),
        );
      },
    );
  }
}
