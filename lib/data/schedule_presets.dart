class SchedulePreset {
  final String title;
  final String category;
  final int hour;
  final int minute;

  const SchedulePreset({
    required this.title,
    required this.category,
    required this.hour,
    this.minute = 0,
  });
}

const List<SchedulePreset> kSchedulePresets = [
  SchedulePreset(title: 'Wake up & breakfast', category: 'Preparation', hour: 7),
  SchedulePreset(title: 'Hair & makeup begins (bride)', category: 'Preparation', hour: 8),
  SchedulePreset(title: 'Hair & makeup begins (groom)', category: 'Preparation', hour: 9),
  SchedulePreset(title: 'Vendors arrive & setup', category: 'Vendor', hour: 9, minute: 30),
  SchedulePreset(title: 'Photographer arrives', category: 'Vendor', hour: 10),
  SchedulePreset(title: 'Florist delivery', category: 'Vendor', hour: 10, minute: 30),
  SchedulePreset(title: 'Bride finishes getting ready', category: 'Preparation', hour: 11, minute: 30),
  SchedulePreset(title: 'First look photos', category: 'Photography', hour: 12),
  SchedulePreset(title: 'Wedding party photos', category: 'Photography', hour: 12, minute: 30),
  SchedulePreset(title: 'Guests begin arriving', category: 'Family & Guests', hour: 13, minute: 30),
  SchedulePreset(title: 'Ceremony begins', category: 'Ceremony', hour: 14),
  SchedulePreset(title: 'Ceremony ends & cocktail hour', category: 'Ceremony', hour: 14, minute: 30),
  SchedulePreset(title: 'Family & couple portraits', category: 'Photography', hour: 15),
  SchedulePreset(title: 'Reception doors open', category: 'Reception', hour: 16),
  SchedulePreset(title: 'Grand entrance', category: 'Reception', hour: 16, minute: 30),
  SchedulePreset(title: 'First dance', category: 'Reception', hour: 17),
  SchedulePreset(title: 'Dinner is served', category: 'Reception', hour: 17, minute: 30),
  SchedulePreset(title: 'Toasts & speeches', category: 'Reception', hour: 18, minute: 30),
  SchedulePreset(title: 'Cake cutting', category: 'Reception', hour: 19),
  SchedulePreset(title: 'Dance floor opens', category: 'Reception', hour: 19, minute: 30),
  SchedulePreset(title: 'Bouquet & garter toss', category: 'Reception', hour: 21),
  SchedulePreset(title: 'Send-off', category: 'Transportation', hour: 22, minute: 30),
];
