import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'aura_mobile.db');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE memories(
        id TEXT PRIMARY KEY,
        content TEXT,
        category TEXT,
        timestamp INTEGER,
        embedding TEXT,
        eventDate INTEGER,
        eventTime TEXT,
        reminderScheduled INTEGER DEFAULT 0
      )
    ''');
    
    // New Schema for Documents (Split into documents and chunks)
    await db.execute('''
      CREATE TABLE documents(
        id TEXT PRIMARY KEY,
        filename TEXT,
        path TEXT,
        uploadDate INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE document_chunks(
        id TEXT PRIMARY KEY,
        documentId TEXT,
        content TEXT,
        chunkIndex INTEGER,
        embedding TEXT,
        FOREIGN KEY(documentId) REFERENCES documents(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_messages(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        thinking TEXT,
        timestamp INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns for notification support
      await db.execute('ALTER TABLE memories ADD COLUMN eventDate INTEGER');
      await db.execute('ALTER TABLE memories ADD COLUMN eventTime TEXT');
      await db.execute('ALTER TABLE memories ADD COLUMN reminderScheduled INTEGER DEFAULT 0');
    }

    if (oldVersion < 3) {
      // Migration to normalized document schema
      // Drop old table if exists (since schema changed drastically)
      await db.execute('DROP TABLE IF EXISTS documents');

      await db.execute('''
        CREATE TABLE documents(
          id TEXT PRIMARY KEY,
          filename TEXT,
          path TEXT,
          uploadDate INTEGER
        )
      ''');

      await db.execute('''
        CREATE TABLE document_chunks(
          id TEXT PRIMARY KEY,
          documentId TEXT,
          content TEXT,
          chunkIndex INTEGER,
          embedding TEXT,
          FOREIGN KEY(documentId) REFERENCES documents(id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 4) {
      // Add chat messages table for persistence
      await db.execute('''
        CREATE TABLE chat_messages(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          role TEXT NOT NULL,
          content TEXT NOT NULL,
          thinking TEXT,
          timestamp INTEGER NOT NULL
        )
      ''');
    }
  }
}
