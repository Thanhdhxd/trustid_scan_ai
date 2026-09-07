import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trustid_scan_ai/core/utils/state_provider.dart';
import 'package:trustid_scan_ai/core/theme/app_colors.dart';
import 'tabs/cycles_tab.dart';
import 'tabs/batches_tab.dart';
import 'widgets/season_form_sheet.dart';

final cycleRefreshProvider = StateProvider<int>((ref) => 0);

class CycleManagementScreen extends ConsumerWidget {
  const CycleManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: kBackgroundDark,
        appBar: AppBar(
          title: const Text('Quản lý Mùa vụ', style: TextStyle(color: kTextLight)),
          backgroundColor: kBackgroundDark,
          elevation: 0,
          iconTheme: const IconThemeData(color: kTextGray),

          bottom: const TabBar(
            labelColor: kPrimaryColor,
            unselectedLabelColor: kTextGray,
            indicatorColor: kPrimaryColor,
            tabs: [
              Tab(text: 'Danh sách mùa vụ'),
              Tab(text: 'Lô thu hoạch (Batches)'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CyclesTab(),
            BatchesTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => SeasonFormSheet(
                onSaved: () {
                  ref.read(cycleRefreshProvider.notifier).state++;
                },
              ),
            );
          },
          backgroundColor: kPrimaryColor,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.spa, color: Colors.white, size: 26),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.add, color: kPrimaryColor, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
