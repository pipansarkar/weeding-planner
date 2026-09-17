import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const List<(String, String)> _faqs = [
    (
      'How do I switch between weddings?',
      'Open the drawer (menu icon) and tap a wedding under "Weddings", or tap "Add Wedding" to create a new one.',
    ),
    (
      'How do I add a wedding-day schedule?',
      'Open the drawer and tap "Wedding Schedule". Tap the + button to add an item, or use the preset-schedule button to quickly add common events like hair & makeup, ceremony, and reception.',
    ),
    (
      'How do plus-ones affect guest counts?',
      'Each guest can have plus-ones added when editing them. "Total Guests" and RSVP counts on the Home and Analyze screens include plus-ones automatically.',
    ),
    (
      'How do I change the currency?',
      'Currency is set per wedding when it is created. Budget and vendor amounts are formatted using that wedding\'s currency.',
    ),
    (
      'How do I back up my data?',
      'Open the drawer and tap "Backup & Restore" to save a snapshot of all your data on this device, or "Export Data" to share a copy as a file.',
    ),
    (
      'Can I recover deleted data?',
      'Deletions are immediate and cannot be undone from within the app. Restoring a prior backup from "Backup & Restore" is the only way to recover data after a deletion.',
    ),
    (
      'What does the Analyze screen show?',
      'A quick overview of checklist progress, budget spent vs. estimated, guest RSVP breakdown, and vendor booking status.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Frequently Asked Questions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ..._faqs.map((faq) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  title: Text(faq.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(faq.$2)],
                ),
              )),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.favorite, color: Colors.pink),
              title: const Text('Wedding Planner'),
              subtitle: const Text('Plan your big day, all in one place.'),
            ),
          ),
        ],
      ),
    );
  }
}
