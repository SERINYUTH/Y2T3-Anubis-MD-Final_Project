import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// This file handles the local SQLite database
class AppDatabase {
  static Database? _db;

  // Gets the database, opens it if not open yet
  Future<Database> getDatabase() async {
    if (_db != null) {
      return _db!;
    }

    String path = await getDatabasesPath();
    String fullPath = join(path, 'anubis.db');

    _db = await openDatabase(
      fullPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          '''
          CREATE TABLE credentials (
            id TEXT PRIMARY KEY,
            encryptedData TEXT,
            category TEXT
          )
          '''
        );

        await db.execute(
          '''
          CREATE TABLE user (
            id TEXT PRIMARY KEY,
            saltForPassword TEXT,
            saltForRecovery TEXT,
            wrappedKeyFromPassword TEXT,
            wrappedKeyFromRecovery TEXT,
            checkValue TEXT
          )
          '''
        );
      },
    );

    return _db!;
  }

  // Inserts one credential row, replaces if id already exists
  Future<void> insertCredential(Map<String, dynamic> row) async {
    Database db = await getDatabase();
    await db.insert(
      'credentials',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Reads every row from the credentials table
  Future<List<Map<String, dynamic>>> getAllRows() async {
    Database db = await getDatabase();
    List<Map<String, dynamic>> rows = await db.query('credentials');
    return rows;
  }

  // Deletes one row by id
  Future<void> deleteRow(String id) async {
    Database db = await getDatabase();
    await db.delete(
      'credentials',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Saves the user row, there is only ever one user on this device
  Future<void> saveUser(Map<String, dynamic> row) async {
    Database db = await getDatabase();
    await db.insert(
      'user',
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Reads the user row, returns null if no user was registered yet
  Future<Map<String, dynamic>?> getUser() async {
    Database db = await getDatabase();
    List<Map<String, dynamic>> rows = await db.query('user');

    if (rows.isEmpty) {
      return null;
    }

    return rows[0];
  }
}
