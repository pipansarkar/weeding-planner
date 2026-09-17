import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'wedding_planner.db');
    return openDatabase(
      path,
      version: 9,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE weddings (
            id TEXT PRIMARY KEY,
            brideName TEXT NOT NULL,
            groomName TEXT NOT NULL,
            weddingDate TEXT,
            currencyCode TEXT NOT NULL DEFAULT 'INR',
            createdAt TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE checklist_items (
            id TEXT PRIMARY KEY,
            weddingId TEXT NOT NULL,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            date TEXT,
            note TEXT,
            status TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE budget_items (
            id TEXT PRIMARY KEY,
            weddingId TEXT NOT NULL,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            estimatedAmount REAL NOT NULL,
            actualAmount REAL NOT NULL,
            note TEXT,
            dueDate TEXT,
            paymentMethod TEXT,
            paidBy TEXT,
            paymentStatus TEXT NOT NULL DEFAULT 'unpaid'
          )
        ''');
        await db.execute('''
          CREATE TABLE guests (
            id TEXT PRIMARY KEY,
            weddingId TEXT NOT NULL,
            name TEXT NOT NULL,
            gender TEXT NOT NULL,
            phone TEXT,
            address TEXT,
            note TEXT,
            category TEXT NOT NULL,
            events TEXT,
            rsvpByEvent TEXT,
            plusOnes INTEGER NOT NULL DEFAULT 0,
            mealPreference TEXT,
            invitationSent INTEGER NOT NULL DEFAULT 0,
            giftReceived TEXT,
            thankYouSent INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE vendors (
            id TEXT PRIMARY KEY,
            weddingId TEXT NOT NULL,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            phone TEXT,
            site TEXT,
            address TEXT,
            amount REAL NOT NULL,
            status TEXT NOT NULL,
            note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE vendor_contact_logs (
            id TEXT PRIMARY KEY,
            weddingId TEXT NOT NULL,
            vendorId TEXT NOT NULL,
            date TEXT NOT NULL,
            note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE timeline_events (
            id TEXT PRIMARY KEY,
            weddingId TEXT NOT NULL,
            title TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'Other',
            time TEXT NOT NULL,
            note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE emergency_contacts (
            id TEXT PRIMARY KEY,
            weddingId TEXT NOT NULL,
            name TEXT NOT NULL,
            role TEXT,
            phone TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE seating_tables (
            id TEXT PRIMARY KEY,
            weddingId TEXT NOT NULL,
            name TEXT NOT NULL,
            capacity INTEGER NOT NULL DEFAULT 8,
            guestIds TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE mood_board_items (
            id TEXT PRIMARY KEY,
            weddingId TEXT NOT NULL,
            imagePath TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT 'Other',
            caption TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE menu_items (
            id TEXT PRIMARY KEY,
            weddingId TEXT NOT NULL,
            name TEXT NOT NULL,
            course TEXT NOT NULL,
            dietaryTags TEXT,
            note TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE custom_lists (
            id TEXT PRIMARY KEY,
            weddingId TEXT NOT NULL,
            name TEXT NOT NULL,
            icon TEXT NOT NULL DEFAULT 'list_alt',
            fields TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE custom_list_items (
            id TEXT PRIMARY KEY,
            listId TEXT NOT NULL,
            values_json TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE guests ADD COLUMN rsvpByEvent TEXT');
          await db.execute(
              'ALTER TABLE guests ADD COLUMN plusOnes INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE guests ADD COLUMN mealPreference TEXT');
          await db.execute(
              'ALTER TABLE guests ADD COLUMN invitationSent INTEGER NOT NULL DEFAULT 0');
          await db.execute('ALTER TABLE guests ADD COLUMN giftReceived TEXT');
          await db.execute(
              'ALTER TABLE guests ADD COLUMN thankYouSent INTEGER NOT NULL DEFAULT 0');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE budget_items ADD COLUMN dueDate TEXT');
          await db.execute('ALTER TABLE budget_items ADD COLUMN paymentMethod TEXT');
          await db.execute('ALTER TABLE budget_items ADD COLUMN paidBy TEXT');
          await db.execute(
              "ALTER TABLE budget_items ADD COLUMN paymentStatus TEXT NOT NULL DEFAULT 'unpaid'");
        }
        if (oldVersion < 4) {
          await db.execute('''
            CREATE TABLE vendor_contact_logs (
              id TEXT PRIMARY KEY,
              vendorId TEXT NOT NULL,
              date TEXT NOT NULL,
              note TEXT
            )
          ''');
        }
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE timeline_events (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              time TEXT NOT NULL,
              note TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE emergency_contacts (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              role TEXT,
              phone TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE seating_tables (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              capacity INTEGER NOT NULL DEFAULT 8,
              guestIds TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE mood_board_items (
              id TEXT PRIMARY KEY,
              imagePath TEXT NOT NULL,
              category TEXT NOT NULL DEFAULT 'Other',
              caption TEXT
            )
          ''');
        }
        if (oldVersion < 6) {
          await _migrateToMultiWedding(db);
        }
        if (oldVersion < 7) {
          await db.execute(
              "ALTER TABLE timeline_events ADD COLUMN category TEXT NOT NULL DEFAULT 'Other'");
        }
        if (oldVersion < 8) {
          await db.execute('''
            CREATE TABLE menu_items (
              id TEXT PRIMARY KEY,
              weddingId TEXT NOT NULL,
              name TEXT NOT NULL,
              course TEXT NOT NULL,
              dietaryTags TEXT,
              note TEXT
            )
          ''');
        }
        if (oldVersion < 9) {
          await db.execute('''
            CREATE TABLE custom_lists (
              id TEXT PRIMARY KEY,
              weddingId TEXT NOT NULL,
              name TEXT NOT NULL,
              icon TEXT NOT NULL DEFAULT 'list_alt',
              fields TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE custom_list_items (
              id TEXT PRIMARY KEY,
              listId TEXT NOT NULL,
              values_json TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  Future<void> _migrateToMultiWedding(Database db) async {
    await db.execute('''
      CREATE TABLE weddings (
        id TEXT PRIMARY KEY,
        brideName TEXT NOT NULL,
        groomName TEXT NOT NULL,
        weddingDate TEXT,
        currencyCode TEXT NOT NULL DEFAULT 'INR',
        createdAt TEXT NOT NULL
      )
    ''');

    final tables = await db.query(
      'sqlite_master',
      where: "type = 'table' AND name = 'wedding_info'",
    );
    String defaultWeddingId = const Uuid().v4();

    if (tables.isNotEmpty) {
      final oldInfo = await db.query('wedding_info', where: 'id = 1');
      final brideName = oldInfo.isNotEmpty ? oldInfo.first['brideName'] as String? ?? '' : '';
      final groomName = oldInfo.isNotEmpty ? oldInfo.first['groomName'] as String? ?? '' : '';
      final weddingDate = oldInfo.isNotEmpty ? oldInfo.first['weddingDate'] as String? : null;
      await db.insert('weddings', {
        'id': defaultWeddingId,
        'brideName': brideName,
        'groomName': groomName,
        'weddingDate': weddingDate,
        'currencyCode': 'INR',
        'createdAt': DateTime.now().toIso8601String(),
      });
      await db.execute('DROP TABLE wedding_info');
    } else {
      await db.insert('weddings', {
        'id': defaultWeddingId,
        'brideName': '',
        'groomName': '',
        'weddingDate': null,
        'currencyCode': 'INR',
        'createdAt': DateTime.now().toIso8601String(),
      });
    }

    const tablesToScope = [
      'checklist_items',
      'budget_items',
      'guests',
      'vendors',
      'vendor_contact_logs',
      'timeline_events',
      'emergency_contacts',
      'seating_tables',
      'mood_board_items',
    ];
    for (final table in tablesToScope) {
      await db.execute('ALTER TABLE $table ADD COLUMN weddingId TEXT');
      await db.update(table, {'weddingId': defaultWeddingId});
    }
  }
}
