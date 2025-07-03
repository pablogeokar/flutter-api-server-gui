import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/user_model.dart';
import 'config_service.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static DatabaseService get instance => _instance ??= DatabaseService._();
  DatabaseService._();

  Database? _database;
  bool _initialized = false;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    await _initDatabase();
    return _database!;
  }

  Future<void> _initDatabase() async {
    if (_initialized) return;

    // Initialize FFI for desktop platforms
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final configService = ConfigService.instance;
    await configService.initialize();

    final databasePath = configService.databasePath;

    _database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: _createTables,
      onUpgrade: _upgradeTables,
    );

    _initialized = true;
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        created_at INTEGER NOT NULL
      )
    ''');

    // Insert sample data
    await _insertSampleData(db);
  }

  Future<void> _upgradeTables(
      Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here if needed
    if (oldVersion < 2) {
      // Example: Add new column
      // await db.execute('ALTER TABLE users ADD COLUMN phone TEXT');
    }
  }

  Future<void> _insertSampleData(Database db) async {
    final sampleUsers = [
      UserModel(name: 'João Silva', email: 'joao@exemplo.com'),
      UserModel(name: 'Maria Santos', email: 'maria@exemplo.com'),
      UserModel(name: 'Pedro Oliveira', email: 'pedro@exemplo.com'),
    ];

    for (final user in sampleUsers) {
      await db.insert('users', user.toDatabase());
    }
  }

  // User CRUD operations
  Future<List<UserModel>> getAllUsers() async {
    final db = await database;
    final maps = await db.query('users', orderBy: 'created_at DESC');
    return maps.map((map) => UserModel.fromDatabase(map)).toList();
  }

  Future<UserModel?> getUserById(int id) async {
    final db = await database;
    final maps = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return UserModel.fromDatabase(maps.first);
  }

  Future<UserModel?> getUserByEmail(String email) async {
    final db = await database;
    final maps =
        await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (maps.isEmpty) return null;
    return UserModel.fromDatabase(maps.first);
  }

  Future<int> createUser(UserModel user) async {
    if (!user.isValid()) {
      throw ArgumentError('Invalid user data');
    }

    // Check if email already exists
    final existingUser = await getUserByEmail(user.email);
    if (existingUser != null) {
      throw ArgumentError('Email already exists');
    }

    final db = await database;
    return await db.insert('users', user.toDatabase());
  }

  Future<bool> updateUser(int id, UserModel user) async {
    if (!user.isValid()) {
      throw ArgumentError('Invalid user data');
    }

    // Check if email exists for other users
    final existingUser = await getUserByEmail(user.email);
    if (existingUser != null && existingUser.id != id) {
      throw ArgumentError('Email already exists');
    }

    final db = await database;
    final count = await db.update(
      'users',
      user.copyWith(id: id).toDatabase(),
      where: 'id = ?',
      whereArgs: [id],
    );
    return count > 0;
  }

  Future<bool> deleteUser(int id) async {
    final db = await database;
    final count = await db.delete('users', where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  Future<int> getUserCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM users');
    return result.first['count'] as int? ?? 0;
  }

  Future<void> clearAllUsers() async {
    final db = await database;
    await db.delete('users');
  }

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
      _initialized = false;
    }
  }

  // Database diagnostics
  Future<Map<String, dynamic>> getDatabaseInfo() async {
    final db = await database;
    final userCount = await getUserCount();
    final databasePath = db.path;

    final file = File(databasePath);
    final size = await file.length();

    return {
      'path': databasePath,
      'size_bytes': size,
      'size_kb': (size / 1024).toStringAsFixed(2),
      'user_count': userCount,
      'is_open': db.isOpen,
    };
  }
}
