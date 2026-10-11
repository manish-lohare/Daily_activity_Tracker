import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.initialize();
  runApp(const DaylightApp());
}

const background = Color(0xFF090A16);
const surface = Color(0xFF17192C);
const surfaceLight = Color(0xFF242741);
const accent = Color(0xFFDFFF4B);
const primaryText = Color(0xFFF7F7FB);
const mutedText = Color(0xFFA5AAC0);

const standardCategories = <TrackerCategory>[
  TrackerCategory('Sleep', 0xFF776CFF, Icons.nightlight_round),
  TrackerCategory('Work', 0xFF2ACBFF, Icons.work_rounded),
  TrackerCategory('Study', 0xFFBE7AFF, Icons.menu_book_rounded),
  TrackerCategory('Exercise', 0xFFFF8250, Icons.bolt_rounded),
  TrackerCategory('Food', 0xFFFFD166, Icons.restaurant_rounded),
  TrackerCategory('Travel', 0xFF28D9B2, Icons.directions_car_rounded),
  TrackerCategory('Entertainment', 0xFFFF5C9C, Icons.movie_rounded),
  TrackerCategory('Social', 0xFF61E66F, Icons.people_rounded),
  TrackerCategory('Personal', 0xFFFFAC4A, Icons.face_rounded),
  TrackerCategory('Other', 0xFF8C96B5, Icons.more_horiz_rounded),
];

const categoryColors = <int>[
  0xFFFF625F,
  0xFFFF9D3D,
  0xFFFFD166,
  0xFFDFFF4B,
  0xFF61E66F,
  0xFF28D9B2,
  0xFF2ACBFF,
  0xFF776CFF,
  0xFFBE7AFF,
  0xFFFF5C9C,
];

class TrackerCategory {
  const TrackerCategory(this.name, this.colorValue, this.icon);

  final String name;
  final int colorValue;
  final IconData icon;

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {'name': name, 'color': colorValue};

  factory TrackerCategory.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final preset = standardCategories.where((item) => item.name == name);
    return TrackerCategory(
      name,
      json['color'] as int,
      preset.isEmpty ? Icons.label_rounded : preset.first.icon,
    );
  }
}

class ActivityEntry {
  ActivityEntry({
    required this.id,
    required this.title,
    required this.start,
    required this.end,
    required this.category,
    this.note = '',
    this.carried = false,
    this.sourceId,
  });

  final String id;
  String title;
  int start;
  int end;
  String category;
  String note;
  bool carried;
  String? sourceId;

  int get minutes => end - start;

  ActivityEntry carryToToday(int endMinute) => ActivityEntry(
        id: 'copy-$id',
        title: title,
        start: start,
        end: endMinute,
        category: category,
        note: note,
        carried: true,
        sourceId: id,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'start': start,
        'end': end,
        'category': category,
        'note': note,
        'carried': carried,
        'sourceId': sourceId,
      };

  factory ActivityEntry.fromJson(Map<String, dynamic> json) => ActivityEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        start: json['start'] as int,
        end: json['end'] as int,
        category: json['category'] as String,
        note: json['note'] as String? ?? '',
        carried: json['carried'] as bool? ?? false,
        sourceId: json['sourceId'] as String?,
      );
}

class Goal {
  Goal({
    required this.id,
    required this.name,
    required this.category,
    required this.schedule,
    required this.target,
    required this.isDuration,
    this.weekdays = const [],
  });

  final String id;
  final String name;
  final String category;
  final String schedule;
  final int target;
  final bool isDuration;
  final List<int> weekdays;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'schedule': schedule,
        'target': target,
        'isDuration': isDuration,
        'weekdays': weekdays,
      };

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
        id: json['id'] as String,
        name: json['name'] as String,
        category: json['category'] as String,
        schedule: json['schedule'] as String,
        target: json['target'] as int,
        isDuration: json['isDuration'] as bool,
        weekdays: (json['weekdays'] as List<dynamic>? ?? [])
            .map((day) => day as int)
            .toList(),
      );
}

class AppStore {
  AppStore._(this._preferences);

  static const _key = 'daylight-state-v3';
  final SharedPreferences _preferences;
  List<TrackerCategory> categories = List.of(standardCategories);
  List<Goal> goals = [];
  final Map<String, List<ActivityEntry>> records = {};

  static Future<AppStore> load() async {
    final store = AppStore._(await SharedPreferences.getInstance());
    final stored = store._preferences.getString(_key);
    if (stored == null) return store;
    final decoded = jsonDecode(stored) as Map<String, dynamic>;
    store.categories = (decoded['categories'] as List<dynamic>)
        .map((entry) => TrackerCategory.fromJson(entry as Map<String, dynamic>))
        .toList();
    store.goals = (decoded['goals'] as List<dynamic>)
        .map((entry) => Goal.fromJson(entry as Map<String, dynamic>))
        .toList();
    final savedRecords = decoded['records'] as Map<String, dynamic>;
    for (final entry in savedRecords.entries) {
      store.records[entry.key] = (entry.value as List<dynamic>)
          .map((item) => ActivityEntry.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return store;
  }

  List<ActivityEntry> activitiesFor(DateTime day) =>
      records.putIfAbsent(_dayKey(day), () => []);

  Future<void> save() async {
    await _preferences.setString(
      _key,
      jsonEncode({
        'categories': categories.map((category) => category.toJson()).toList(),
        'goals': goals.map((goal) => goal.toJson()).toList(),
        'records': records.map(
          (key, activities) => MapEntry(
            key,
            activities.map((activity) => activity.toJson()).toList(),
          ),
        ),
      }),
    );
  }
}

class Backend {
  // ── Supabase credentials ───────────────────────────────────────────────────
  // Replace these with your own project values from:
  // Supabase dashboard → Project Settings → API
  static const _url = 'https://lavsenhehwuoruphkxuz.supabase.co';
  static const _publishableKey =
      'sb_publishable_EKHUX4BNqGjqcLsVyK9jLA_MpuyHc5R';
  // ──────────────────────────────────────────────────────────────────────────

  static bool _ready = false;

  static bool get isConfigured => _url.isNotEmpty && _publishableKey.isNotEmpty;
  static bool get signedIn => _ready && Supabase.instance.client.auth.currentUser != null;
  static SupabaseClient get _client => Supabase.instance.client;

  static Future<void> initialize() async {
    if (!isConfigured) return;
    await Supabase.initialize(url: _url, publishableKey: _publishableKey);
    _ready = true;
  }

  static Future<String?> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not sign in. Check your connection and try again.';
    }
  }

  static Future<String?> signUp(String email, String password, {String? firstName, String? lastName}) async {
    try {
      await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
          if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
          'full_name': '${firstName ?? ''} ${lastName ?? ''}'.trim(),
        },
      );
      return null;
    } on AuthException catch (error) {
      return error.message;
    } catch (_) {
      return 'Could not create your account. Please try again.';
    }
  }

  /// Returns the display name from user metadata.
  static String get displayName {
    if (!signedIn) return '';
    final meta = _client.auth.currentUser?.userMetadata;
    if (meta == null) return '';
    final full = meta['full_name'] as String?;
    if (full != null && full.isNotEmpty) return full;
    final first = meta['first_name'] as String? ?? '';
    final last = meta['last_name'] as String? ?? '';
    return '$first $last'.trim();
  }

  static Future<void> syncStore(AppStore store) async {
    if (!signedIn) return;
    final userId = _client.auth.currentUser!.id;
    await _client.from('categories').upsert(
      store.categories.map((item) => {
        'user_id': userId,
        'name': item.name,
        'color_value': item.colorValue,
      }).toList(),
      onConflict: 'user_id,name',
    );
    final activityRows = <Map<String, dynamic>>[];
    for (final record in store.records.entries) {
      for (final item in record.value) {
        activityRows.add({
          'id': item.id,
          'user_id': userId,
          'entry_date': record.key,
          'title': item.title,
          'start_minute': item.start,
          'end_minute': item.end,
          'category': item.category,
          'note': item.note,
          'carried': item.carried,
          'source_id': item.sourceId,
        });
      }
    }
    if (activityRows.isNotEmpty) {
      await _client.from('activities').upsert(activityRows, onConflict: 'id');
    }
    if (store.goals.isNotEmpty) {
      await _client.from('goals').upsert(
        store.goals.map((goal) => {
          'id': goal.id,
          'user_id': userId,
          'name': goal.name,
          'category': goal.category,
          'schedule': goal.schedule,
          'target': goal.target,
          'is_duration': goal.isDuration,
          'weekdays': goal.weekdays,
        }).toList(),
        onConflict: 'id',
      );
    }
  }

  static Future<void> loadStore(AppStore store) async {
    if (!signedIn) return;
    final userId = _client.auth.currentUser!.id;
    final categoryRows = await _client.from('categories').select().eq('user_id', userId);
    if (categoryRows.isNotEmpty) {
      store.categories = categoryRows.map((row) => TrackerCategory(
        row['name'] as String,
        row['color_value'] as int,
        standardCategories.where((item) => item.name == row['name']).isEmpty
            ? Icons.label_rounded
            : standardCategories.firstWhere((item) => item.name == row['name']).icon,
      )).toList();
    }
    final activityRows = await _client.from('activities').select().eq('user_id', userId);
    for (final row in activityRows) {
      final date = row['entry_date'] as String;
      final local = store.activitiesFor(DateTime.parse(date));
      if (local.any((item) => item.id == row['id'])) continue;
      local.add(ActivityEntry(
        id: row['id'] as String,
        title: row['title'] as String,
        start: row['start_minute'] as int,
        end: row['end_minute'] as int,
        category: row['category'] as String,
        note: row['note'] as String? ?? '',
        carried: row['carried'] as bool? ?? false,
        sourceId: row['source_id'] as String?,
      ));
    }
    final goalRows = await _client.from('goals').select().eq('user_id', userId);
    for (final row in goalRows) {
      if (store.goals.any((goal) => goal.id == row['id'])) continue;
      store.goals.add(Goal(
        id: row['id'] as String,
        name: row['name'] as String,
        category: row['category'] as String,
        schedule: row['schedule'] as String,
        target: row['target'] as int,
        isDuration: row['is_duration'] as bool,
        weekdays: (row['weekdays'] as List<dynamic>? ?? []).map((day) => day as int).toList(),
      ));
    }
  }

  static Future<void> deleteActivity(String id) async {
    if (signedIn) await _client.from('activities').delete().eq('id', id);
  }

  static Future<void> deleteGoal(String id) async {
    if (signedIn) await _client.from('goals').delete().eq('id', id);
  }
}

String _dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

class DaylightApp extends StatelessWidget {
  const DaylightApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Daylight',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: const ColorScheme.dark(
            primary: accent,
            surface: surface,
            onSurface: primaryText,
          ),
          scaffoldBackgroundColor: background,
          dialogTheme: const DialogThemeData(backgroundColor: surface),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: surface,
            modalBackgroundColor: surface,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: surfaceLight,
            labelStyle: const TextStyle(color: mutedText),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        home: const AuthGate(),
      );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool? canEnterApp;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final preferences = await SharedPreferences.getInstance();
    final skipped = preferences.getBool('daylight-guest-mode') ?? false;
    if (!mounted) return;
    setState(() => canEnterApp = skipped || Backend.signedIn);
  }

  Future<void> _continueAsGuest() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('daylight-guest-mode', true);
    if (mounted) setState(() => canEnterApp = true);
  }

  void _signedIn() => setState(() => canEnterApp = true);

  @override
  Widget build(BuildContext context) {
    if (canEnterApp == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: accent)),
      );
    }
    return canEnterApp! 
        ? const TrackerHome()
        : AuthPage(onGuest: _continueAsGuest, onSignedIn: _signedIn);
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({required this.onGuest, required this.onSignedIn, super.key});

  final Future<void> Function() onGuest;
  final VoidCallback onSignedIn;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _createAccount = false;
  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  String? _message;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  /// Password must be ≥6 chars and contain at least one letter and one digit.
  String? _validatePassword(String value) {
    if (value.length < 6) return 'Password must be at least 6 characters.';
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) return 'Password must contain at least one letter.';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Password must contain at least one number.';
    return null;
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;

    // Email check
    if (email.isEmpty || !RegExp(r'^[\w.+-]+@[\w-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      setState(() => _message = 'Please enter a valid email address.');
      return;
    }

    // Password validation
    final pwError = _validatePassword(password);
    if (pwError != null) {
      setState(() => _message = pwError);
      return;
    }

    // Signup-specific checks
    if (_createAccount) {
      if (_firstName.text.trim().isEmpty) {
        setState(() => _message = 'Please enter your first name.');
        return;
      }
      if (password != _confirmPassword.text) {
        setState(() => _message = 'Passwords do not match.');
        return;
      }
    }

    if (!Backend.isConfigured) {
      setState(() => _message = 'Supabase is not configured. You can still skip and use the app locally.');
      return;
    }

    setState(() { _loading = true; _message = null; });

    final error = _createAccount
        ? await Backend.signUp(
            email,
            password,
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
          )
        : await Backend.signIn(email, password);

    if (!mounted) return;
    setState(() => _loading = false);

    if (error != null) {
      setState(() => _message = error);
      return;
    }
    if (_createAccount && !Backend.signedIn) {
      setState(() => _message = 'Check your email to confirm your account, then sign in.');
      return;
    }
    widget.onSignedIn();
  }

  void _toggleMode() => setState(() {
        _createAccount = !_createAccount;
        _message = null;
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF28204A), background, background],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _loading ? null : widget.onGuest,
                  child: const Text('Skip for now', style: TextStyle(color: primaryText)),
                ),
              ),
              const SizedBox(height: 16),
              // Logo
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.bolt_rounded, color: Colors.black, size: 31),
              ),
              const SizedBox(height: 22),
              Text(
                _createAccount ? 'Create your\naccount.' : 'Know where your\ntime goes.',
                style: const TextStyle(fontSize: 34, height: .97, fontWeight: FontWeight.w900, letterSpacing: -1.2),
              ),
              const SizedBox(height: 10),
              Text(
                _createAccount
                    ? 'Join Daylight to sync your timeline across all devices.'
                    : 'Sign in to keep your timeline, goals, and streaks safely synced.',
                style: const TextStyle(color: mutedText, height: 1.4),
              ),
              const SizedBox(height: 26),

              // Form card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF343852)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ── Name fields (signup only) ──
                  if (_createAccount) ...[
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _firstName,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'First name'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _lastName,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Last name'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                  ],

                  // ── Email ──
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email address'),
                  ),
                  const SizedBox(height: 12),

                  // ── Password ──
                  TextField(
                    controller: _password,
                    obscureText: !_showPassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      helperText: 'Min 6 characters, letters & numbers',
                      helperStyle: const TextStyle(fontSize: 11, color: mutedText),
                      suffixIcon: IconButton(
                        icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                        onPressed: () => setState(() => _showPassword = !_showPassword),
                      ),
                    ),
                  ),

                  // ── Confirm password (signup only) ──
                  if (_createAccount) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPassword,
                      obscureText: !_showConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm password',
                        suffixIcon: IconButton(
                          icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                          onPressed: () => setState(() => _showConfirm = !_showConfirm),
                        ),
                      ),
                    ),
                  ],

                  // ── Error / info message ──
                  if (_message != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A1F2A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFFFB4A7)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_message!, style: const TextStyle(fontSize: 12, color: Color(0xFFFFB4A7)))),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // ── Submit button ──
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : Text(_createAccount ? 'Create account' : 'Sign in', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Toggle sign in / create ──
                  Center(
                    child: TextButton(
                      onPressed: _loading ? null : _toggleMode,
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13),
                          children: [
                            TextSpan(
                              text: _createAccount ? 'Already have an account? ' : "Don't have an account? ",
                              style: const TextStyle(color: mutedText),
                            ),
                            TextSpan(
                              text: _createAccount ? 'Sign in' : 'Create one',
                              style: const TextStyle(color: accent, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: _loading ? null : widget.onGuest,
                  child: const Text('Continue without an account', style: TextStyle(color: mutedText)),
                ),
              ),
              const SizedBox(height: 24),
            ]),
          ),
        ),
      ),
    );
  }
}

class TrackerHome extends StatefulWidget {
  const TrackerHome({super.key});

  @override
  State<TrackerHome> createState() => _TrackerHomeState();
}

class _TrackerHomeState extends State<TrackerHome> {
  AppStore? store;
  late DateTime selectedDay;
  Timer? timer;
  int tab = 0;
  bool use24Hour = true;

  @override
  void initState() {
    super.initState();
    selectedDay = _dateOnly(DateTime.now());
    _load();
    timer = Timer.periodic(const Duration(minutes: 1), (_) => _carryForward());
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final result = await AppStore.load();
    try {
      await Backend.syncStore(result);
      await Backend.loadStore(result);
    } catch (_) {
      // The timeline remains available locally until the Supabase schema exists.
    }
    await result.save();
    if (!mounted) return;
    setState(() => store = result);
    await _carryForward();
  }

  List<ActivityEntry> get _activities {
    final list = store!.activitiesFor(selectedDay);
    list.sort((a, b) => a.start.compareTo(b.start));
    return list;
  }

  bool get _isToday => _dayKey(selectedDay) == _dayKey(DateTime.now());

  String _clock(int minute) {
    final hour = minute ~/ 60;
    final mins = (minute % 60).toString().padLeft(2, '0');
    if (use24Hour) return '${hour.toString().padLeft(2, '0')}:$mins';
    final suffix = hour < 12 ? 'AM' : 'PM';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;
    return '$displayHour:$mins $suffix';
  }

  String _duration(int minutes) {
    if (minutes <= 0) return '0m';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins}m';
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  TrackerCategory _category(String name) => store!.categories.firstWhere(
        (item) => item.name == name,
        orElse: () => standardCategories.last,
      );

  int _nowRounded() {
    final now = DateTime.now();
    return ((now.hour * 60 + now.minute) ~/ 15 * 15).clamp(0, 1380).toInt();
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _save() async {
    await store!.save();
    await Backend.syncStore(store!);
  }

  Future<void> _carryForward() async {
    if (store == null) return;
    final now = DateTime.now();
    final today = _dateOnly(now);
    final elapsedMinute = now.hour * 60 + now.minute;
    final yesterday = today.subtract(const Duration(days: 1));
    final previous = List<ActivityEntry>.from(store!.activitiesFor(yesterday));
    final todayActivities = store!.activitiesFor(today);
    var changed = false;

    for (final oldActivity in previous) {
      final copiedEnd = oldActivity.end < elapsedMinute ? oldActivity.end : elapsedMinute;
      if (copiedEnd <= oldActivity.start) continue;
      final found = todayActivities.where(
        (item) => item.carried && item.sourceId == oldActivity.id,
      );
      final existing = found.isEmpty ? null : found.first;
      final userLoggedOverIt = todayActivities.any(
        (item) =>
            !item.carried &&
            item.start < copiedEnd &&
            item.end > oldActivity.start,
      );
      if (userLoggedOverIt) continue;

      if (existing == null) {
        todayActivities.add(oldActivity.carryToToday(copiedEnd));
        changed = true;
      } else if (existing.end < copiedEnd) {
        existing.end = copiedEnd;
        changed = true;
      }
    }
    if (!changed) return;
    todayActivities.sort((a, b) => a.start.compareTo(b.start));
    await _save();
    if (mounted && _isToday) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (store == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: accent)));
    }
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF12142E), background, background],
          ),
        ),
        child: SafeArea(
          child: tab == 0 ? _timelineView() : tab == 1 ? _profileView() : _goalsView(),
        ),
      ),
      floatingActionButton: tab == 0
          ? FloatingActionButton.extended(
              backgroundColor: accent,
              foregroundColor: Colors.black,
              icon: const Icon(Icons.add),
              label: const Text('Log time'),
              onPressed: _editActivity,
            )
          : null,
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF101124),
        indicatorColor: const Color(0xFF33374D),
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Timeline'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag), label: 'Goals'),
        ],
      ),
    );
  }

  Widget _timelineView() {
    final tracked = _activities
        .fold(0, (total, item) => total + item.minutes)
        .clamp(0, 1440)
        .toInt();
    final now = DateTime.now();
    final currentMinute = now.hour * 60 + now.minute;
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _header(),
            const SizedBox(height: 19),
            Text(
              _isToday ? 'Your day in\nreal time.' : _friendlyDate(selectedDay),
              style: const TextStyle(fontSize: 34, height: .95, fontWeight: FontWeight.w900, letterSpacing: -1.2),
            ),
            const SizedBox(height: 9),
            Text(
              _isToday ? 'Every minute tells a part of your story.' : 'A saved view of this day.',
              style: const TextStyle(color: mutedText),
            ),
            const SizedBox(height: 18),
            _weekPicker(),
            const SizedBox(height: 18),
            _progressCard(tracked),
            const SizedBox(height: 23),
            Row(children: [
              const Expanded(child: Text('Timeline', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800))),
              Text('00:00 — 24:00', style: const TextStyle(fontSize: 12, color: mutedText)),
            ]),
            if (_isToday) ...[
              const SizedBox(height: 3),
              Text('Live marker · ${_clock(currentMinute)}', style: const TextStyle(fontSize: 11, color: mutedText)),
            ],
          ]),
        ),
      ),
      SliverToBoxAdapter(child: _timeline(currentMinute)),
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(20, 26, 20, 100), child: _summary(tracked))),
    ]);
  }

  Widget _header() => Row(children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.bolt_rounded, color: Colors.black),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Text('DAYLIGHT', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
        _headerAction(Icons.schedule_outlined, use24Hour ? '24h' : '12h', () => setState(() => use24Hour = !use24Hour)),
        const SizedBox(width: 7),
        _headerAction(Icons.calendar_month_outlined, null, _pickDate),
        const SizedBox(width: 7),
        _headerAction(Icons.palette_outlined, null, _showCategories),
        const SizedBox(width: 7),
        _profileButton(),
      ]);

  Future<void> _pickDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(2020),
      lastDate: _dateOnly(DateTime.now()),
      helpText: 'Choose a day',
    );
    if (chosen != null) setState(() => selectedDay = _dateOnly(chosen));
  }

  Widget _headerAction(IconData icon, String? label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 39,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: surfaceLight, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 18),
            if (label != null) ...[const SizedBox(width: 5), Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))],
          ]),
        ),
      );

  /// Profile avatar when signed in; "Sign in" chip when not.
  Widget _profileButton() {
    if (Backend.signedIn) {
      final email = Supabase.instance.client.auth.currentUser?.email ?? '';
      final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
      return GestureDetector(
        onTap: _showProfile,
        child: Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF776CFF), Color(0xFFBE7AFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
      );
    }
    // Not signed in: compact "Sign in" pill button
    return GestureDetector(
      onTap: _openSignIn,
      child: Container(
        height: 39,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: accent, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.login_rounded, size: 15, color: accent),
          SizedBox(width: 5),
          Text('Sign in', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: accent)),
        ]),
      ),
    );
  }

  void _showProfile() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ProfileSheet(onSignOut: () {
        Navigator.pop(context);
        setState(() {}); // refresh header
      }),
    );
  }

  Future<void> _openSignIn() async {
    final signedIn = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => AuthPage(
          onGuest: () async => Navigator.of(context).pop(false),
          onSignedIn: () => Navigator.of(context).pop(true),
        ),
      ),
    );
    if (signedIn == true && mounted) {
      setState(() {}); // refresh header to show avatar
      try {
        await Backend.syncStore(store!);
        await Backend.loadStore(store!);
        await store!.save();
        if (mounted) setState(() {});
      } catch (_) {}
    }
  }

  Widget _weekPicker() {
    final start = selectedDay.subtract(Duration(days: selectedDay.weekday - 1));
    const initials = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return Row(children: List.generate(7, (index) {
      final date = start.add(Duration(days: index));
      final active = _dayKey(date) == _dayKey(selectedDay);
      final isToday = _dayKey(date) == _dayKey(DateTime.now());
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => selectedDay = _dateOnly(date)),
          child: Container(
            margin: EdgeInsets.only(right: index == 6 ? 0 : 5),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: active ? accent : surface,
              borderRadius: BorderRadius.circular(14),
              border: isToday && !active ? Border.all(color: accent) : null,
            ),
            child: Column(children: [
              Text(initials[index], style: TextStyle(fontSize: 10, color: active ? Colors.black54 : mutedText)),
              const SizedBox(height: 4),
              Text('${date.day}', style: TextStyle(fontWeight: FontWeight.w900, color: active ? Colors.black : primaryText)),
            ]),
          ),
        ),
      );
    }));
  }

  Widget _progressCard(int tracked) {
    final progress = tracked / 1440;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2D314B)),
      ),
      child: Row(children: [
        SizedBox(
          width: 92,
          height: 92,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(width: 92, height: 92, child: CircularProgressIndicator(value: progress, strokeWidth: 9, color: accent, backgroundColor: surfaceLight, strokeCap: StrokeCap.round)),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${(progress * 100).round()}%', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const Text('MAPPED', style: TextStyle(fontSize: 8, color: mutedText, letterSpacing: 1)),
            ]),
          ]),
        ),
        const SizedBox(width: 18),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Your 24 hours', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          Text('${_duration(tracked)} recorded', style: const TextStyle(color: mutedText)),
          const SizedBox(height: 4),
          Text('${_duration(1440 - tracked)} still open', style: const TextStyle(color: mutedText)),
        ])),
      ]),
    );
  }

  Widget _timeline(int currentMinute) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: List.generate(24, (hour) {
          final start = hour * 60;
          final end = start + 60;
          final entries = _activities.where((item) => item.start < end && item.end > start).toList();
          final live = _isToday && currentMinute >= start && currentMinute < end;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 52,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _clock(start),
                  style: const TextStyle(fontSize: 11, color: mutedText),
                ),
              ),
            ),
            SizedBox(width: 20, child: Column(children: [
              Container(width: 1, height: 10, color: const Color(0xFF353950)),
              Container(width: live ? 10 : 6, height: live ? 10 : 6, decoration: BoxDecoration(color: live ? accent : const Color(0xFF555B74), shape: BoxShape.circle)),
              if (entries.isEmpty) Container(width: 1, height: 36, color: const Color(0xFF353950)),
            ])),
            const SizedBox(width: 8),
            Expanded(child: entries.isEmpty ? _openTime() : Column(children: entries.map((item) => _activityCard(item, start, end)).toList())),
          ]);
        })),
      );

  Widget _openTime() => Container(
        height: 50,
        alignment: Alignment.centerLeft,
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF1D2034)))),
        child: const Text('open time', style: TextStyle(fontSize: 12, color: Color(0xFF62687E))),
      );

  Widget _activityCard(ActivityEntry item, int hourStart, int hourEnd) {
    final category = _category(item.category);
    final visibleStart = item.start > hourStart ? item.start : hourStart;
    final visibleEnd = item.end < hourEnd ? item.end : hourEnd;
    final height = ((visibleEnd - visibleStart) * .78).clamp(42, 70).toDouble();
    return GestureDetector(
      onTap: () => _editActivity(item),
      onLongPress: () => _deleteActivity(item),
      child: Container(
        height: height,
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: category.color.withValues(alpha: .16),
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: category.color, width: 4)),
        ),
        child: Row(children: [
          Icon(category.icon, color: category.color, size: 17),
          const SizedBox(width: 9),
          Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
            Text('${item.category}${item.carried ? ' · copied' : ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: category.color)),
          ])),
          Text('${_clock(item.start)}\n${_clock(item.end)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 9, height: 1.35, color: mutedText)),
        ]),
      ),
    );
  }

  Widget _summary(int tracked) {
    final totals = <String, int>{};
    for (final item in _activities) {
      totals[item.category] = (totals[item.category] ?? 0) + item.minutes;
    }
    final rows = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Time, made visible', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('No judgement. Just an honest view of your day.', style: TextStyle(fontSize: 12, color: mutedText)),
      const SizedBox(height: 15),
      if (rows.isEmpty) _emptyCard('Tap “Log time” to begin mapping your day.'),
      ...rows.map(_summaryRow),
      if (tracked < 1440) _untrackedRow(1440 - tracked),
    ]);
  }

  Widget _summaryRow(MapEntry<String, int> row) {
    final category = _category(row.key);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        _dot(category.color, 10),
        const SizedBox(width: 10),
        Expanded(child: Text(row.key, style: const TextStyle(fontWeight: FontWeight.w800))),
        Text(_duration(row.value), style: TextStyle(fontWeight: FontWeight.w900, color: category.color)),
      ]),
    );
  }

  Widget _untrackedRow(int minutes) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(color: surfaceLight, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          _dot(const Color(0xFF62687E), 10),
          const SizedBox(width: 10),
          const Expanded(child: Text('Untracked', style: TextStyle(fontWeight: FontWeight.w800))),
          Text(_duration(minutes), style: const TextStyle(fontWeight: FontWeight.w900, color: mutedText)),
        ]),
      );

  Future<void> _editActivity([ActivityEntry? existing]) async {
    final title = TextEditingController(text: existing?.title ?? '');
    final notes = TextEditingController(text: existing?.note ?? '');
    var start = existing?.start ?? _nowRounded();
    var end = existing?.end ?? (start + 60).clamp(0, 1440).toInt();
    var category = existing?.category ?? store!.categories.first.name;
    final result = await showModalBottomSheet<ActivityEntry>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, change) => Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: _handle()),
            const SizedBox(height: 20),
            Text(existing == null ? 'Log your time' : 'Edit activity', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 7),
            const Text('A clear record beats a perfect one.', style: TextStyle(color: mutedText)),
            const SizedBox(height: 19),
            TextField(controller: title, autofocus: true, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What did you do?')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _timePicker('Start', start, (value) => change(() => start = value))),
              const SizedBox(width: 10),
              Expanded(child: _timePicker('End', end, (value) => change(() => end = value))),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: store!.categories.map((item) => DropdownMenuItem(value: item.name, child: Row(children: [_dot(item.color, 10), const SizedBox(width: 9), Text(item.name)]))).toList(),
              onChanged: (value) => change(() => category = value!),
            ),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () async {
              final created = await _createCategory();
              if (created != null) change(() => category = created.name);
            }, icon: const Icon(Icons.add, size: 17), label: const Text('New category'))),
            TextField(controller: notes, maxLines: 2, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Note (optional)')),
            const SizedBox(height: 18),
            SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: () {
                if (title.text.trim().isEmpty || end <= start) return;
                Navigator.pop(context, ActivityEntry(id: existing?.id ?? _newId(), title: title.text.trim(), start: start, end: end, category: category, note: notes.text.trim()));
              },
              child: Text(existing == null ? 'Add activity' : 'Save changes'),
            )),
          ])),
        ),
      ),
    );
    if (result == null) return;
    final activities = store!.activitiesFor(selectedDay);
    setState(() {
      if (existing == null) {
        activities.add(result);
      } else {
        activities[activities.indexOf(existing)] = result;
      }
      activities.sort((a, b) => a.start.compareTo(b.start));
    });
    await _save();
  }

  Widget _timePicker(String label, int value, ValueChanged<int> onChanged) => OutlinedButton(
        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: Color(0xFF3B405B))),
        onPressed: () async {
          final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: value ~/ 60, minute: value % 60));
          if (picked != null) onChanged(picked.hour * 60 + picked.minute);
        },
        child: Column(children: [Text(label, style: const TextStyle(fontSize: 11, color: mutedText)), const SizedBox(height: 3), Text(_clock(value), style: const TextStyle(fontWeight: FontWeight.w800))]),
      );

  Future<void> _deleteActivity(ActivityEntry item) async {
    final answer = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('Delete this activity?'),
      content: Text('Remove “${item.title}” from this day?'),
      actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))],
    ));
    if (answer != true) return;
    setState(() => _activities.remove(item));
    await _save();
    await Backend.deleteActivity(item.id);
  }

  Future<TrackerCategory?> _createCategory() async {
    final name = TextEditingController();
    var color = categoryColors.first;
    final result = await showModalBottomSheet<TrackerCategory>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, change) => Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: _handle()),
            const SizedBox(height: 18),
            const Text('Create a category', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900)),
            const SizedBox(height: 18),
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Category name')),
            const SizedBox(height: 17),
            const Text('Choose a colour', style: TextStyle(color: mutedText)),
            const SizedBox(height: 10),
            Wrap(spacing: 11, runSpacing: 11, children: categoryColors.map((value) => GestureDetector(
              onTap: () => change(() => color = value),
              child: Container(width: 36, height: 36, decoration: BoxDecoration(color: Color(value), shape: BoxShape.circle, border: value == color ? Border.all(color: Colors.white, width: 3) : null), child: value == color ? const Icon(Icons.check, color: Colors.black, size: 20) : null),
            )).toList()),
            const SizedBox(height: 22),
            SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
              onPressed: () {
                final text = name.text.trim();
                if (text.isEmpty || store!.categories.any((item) => item.name.toLowerCase() == text.toLowerCase())) return;
                Navigator.pop(context, TrackerCategory(text, color, Icons.label_rounded));
              },
              child: const Text('Add category'),
            )),
          ]),
        ),
      ),
    );
    if (result != null) {
      setState(() => store!.categories.add(result));
      await _save();
    }
    return result;
  }

  Future<void> _showCategories() async {
    await showModalBottomSheet<void>(context: context, builder: (context) => StatefulBuilder(
      builder: (context, update) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: _handle()),
          const SizedBox(height: 17),
          Row(children: [
            const Expanded(child: Text('Your categories', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
            IconButton(onPressed: () async { final newItem = await _createCategory(); if (newItem != null) update(() {}); }, icon: const Icon(Icons.add_circle_outline)),
          ]),
          const SizedBox(height: 11),
          Wrap(spacing: 9, runSpacing: 9, children: store!.categories.map((item) => _categoryChip(item)).toList()),
        ]),
      ),
    ));
  }

  Widget _categoryChip(TrackerCategory item) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(color: item.color.withValues(alpha: .14), borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [_dot(item.color, 8), const SizedBox(width: 7), Text(item.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]),
      );

  // ── Profile tab ──────────────────────────────────────────────────────────────
  Widget _profileView() {
    final signedIn = Backend.signedIn;
    final userEmail = signedIn
        ? (Supabase.instance.client.auth.currentUser?.email ?? '')
        : '';
    final displayName = Backend.displayName;
    final initial = userEmail.isNotEmpty ? userEmail[0].toUpperCase() : '?';
    final joinedAt = signedIn && Supabase.instance.client.auth.currentUser?.createdAt != null
        ? DateTime.parse(Supabase.instance.client.auth.currentUser!.createdAt).toLocal()
        : null;

    return ListView(padding: const EdgeInsets.fromLTRB(20, 24, 20, 100), children: [
      // ── Header ──
      Row(children: [
        Container(
          width: 39, height: 39,
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.bolt_rounded, color: Colors.black),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Text('DAYLIGHT', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
      ]),
      const SizedBox(height: 28),

      // ── Profile card ──
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1F1B3A), Color(0xFF17192C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF343852)),
        ),
        child: signedIn ? Column(children: [
          // Avatar row
          Row(children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF776CFF), Color(0xFFBE7AFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (displayName.isNotEmpty) ...[
                Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -.3)),
                const SizedBox(height: 3),
              ],
              Text(userEmail, style: const TextStyle(fontSize: 13, color: mutedText)),
              if (joinedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Member since ${_monthName(joinedAt.month)} ${joinedAt.year}',
                  style: const TextStyle(fontSize: 11, color: mutedText),
                ),
              ],
            ])),
          ]),
          const SizedBox(height: 18),
          // Sync status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(color: surfaceLight, borderRadius: BorderRadius.circular(12)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_done_rounded, size: 15, color: accent),
              SizedBox(width: 8),
              Expanded(child: Text('Synced across all your devices', style: TextStyle(fontSize: 12))),
            ]),
          ),
          const SizedBox(height: 14),
          // Sign out button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF3B405B)),
                foregroundColor: const Color(0xFFFF6B6B),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.logout_rounded, size: 17),
              label: const Text('Sign out'),
            ),
          ),
        ]) : Column(children: [
          // Guest state
          const Icon(Icons.person_outline_rounded, size: 52, color: mutedText),
          const SizedBox(height: 14),
          const Text('You\'re not signed in', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          const Text('Sign in to sync your timeline, goals, and streaks across devices.', textAlign: TextAlign.center, style: TextStyle(color: mutedText, height: 1.4, fontSize: 13)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                final ok = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => AuthPage(
                      onGuest: () async => Navigator.of(context).pop(false),
                      onSignedIn: () => Navigator.of(context).pop(true),
                    ),
                  ),
                );
                if (ok == true && mounted) {
                  setState(() {});
                  try {
                    await Backend.syncStore(store!);
                    await Backend.loadStore(store!);
                    await store!.save();
                    if (mounted) setState(() {});
                  } catch (_) {}
                }
              },
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign in / Create account', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ]),
      ),

      const SizedBox(height: 32),

      // ── Insights section ──
      const Text('INSIGHTS', style: TextStyle(fontSize: 12, letterSpacing: 2, color: accent, fontWeight: FontWeight.w900)),
      const SizedBox(height: 9),
      const Text('Your patterns\nunfolding.', style: TextStyle(fontSize: 32, height: .98, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
      const SizedBox(height: 9),
      const Text('Keep the data. Let the patterns speak.', style: TextStyle(color: mutedText)),
      const SizedBox(height: 23),
      _todayInsight(),
      const SizedBox(height: 22),
      const Text('Category streaks', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text('Consecutive days with time logged.', style: TextStyle(fontSize: 12, color: mutedText)),
      const SizedBox(height: 13),
      ...store!.categories.map(_streakCard),
      const SizedBox(height: 21),
      const Text('This week', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
      const SizedBox(height: 12),
      _weekSummary(),
    ]);
  }

  String _monthName(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }


  Widget _todayInsight() {
    final total = _activities.fold(0, (sum, item) => sum + item.minutes);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(21), border: Border.all(color: const Color(0xFF2D314B))),
      child: Row(children: [
        Container(width: 48, height: 48, decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.auto_graph_rounded, color: Colors.black)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Today so far', style: TextStyle(color: mutedText, fontSize: 12)), Text(_duration(total), style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900))])),
        Text('${(total / 1440 * 100).round()}%', style: const TextStyle(fontSize: 20, color: accent, fontWeight: FontWeight.w900)),
      ]),
    );
  }

  Widget _streakCard(TrackerCategory category) {
    final streak = _categoryStreak(category.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: category.color.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)), child: Icon(category.icon, size: 20, color: category.color)),
        const SizedBox(width: 11),
        Expanded(child: Text(category.name, style: const TextStyle(fontWeight: FontWeight.w800))),
        Icon(Icons.local_fire_department_rounded, color: streak == 0 ? mutedText : accent, size: 18),
        const SizedBox(width: 4),
        Text('${streak}d', style: TextStyle(fontWeight: FontWeight.w900, color: streak == 0 ? mutedText : accent)),
      ]),
    );
  }

  int _categoryMinutes(DateTime date, String category) => store!
      .activitiesFor(date)
      .where((item) => item.category == category)
      .fold(0, (sum, item) => sum + item.minutes);

  int _categorySessions(DateTime date, String category) => store!
      .activitiesFor(date)
      .where((item) => item.category == category)
      .length;

  int _categoryStreak(String category) {
    var date = _dateOnly(DateTime.now());
    if (_categoryMinutes(date, category) == 0) date = date.subtract(const Duration(days: 1));
    var streak = 0;
    while (_categoryMinutes(date, category) > 0) {
      streak++;
      date = date.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Widget _weekSummary() {
    final totals = <String, int>{};
    final today = _dateOnly(DateTime.now());
    for (var index = 0; index < 7; index++) {
      for (final item in store!.activitiesFor(today.subtract(Duration(days: index)))) {
        totals[item.category] = (totals[item.category] ?? 0) + item.minutes;
      }
    }
    final rows = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    if (rows.isEmpty) return _emptyCard('Log a few activities to see weekly trends.');
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(18)),
      child: Column(children: rows.take(5).map((row) {
        final item = _category(row.key);
        return Padding(padding: const EdgeInsets.symmetric(vertical: 7), child: Row(children: [_dot(item.color, 9), const SizedBox(width: 10), Expanded(child: Text(row.key)), Text(_duration(row.value), style: const TextStyle(fontWeight: FontWeight.w900))]));
      }).toList()),
    );
  }

  Widget _goalsView() => ListView(padding: const EdgeInsets.fromLTRB(20, 22, 20, 40), children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('GOALS', style: TextStyle(fontSize: 12, letterSpacing: 2, color: accent, fontWeight: FontWeight.w900)),
            SizedBox(height: 9),
            Text('Promises to\nyourself.', style: TextStyle(fontSize: 32, height: .98, fontWeight: FontWeight.w900, letterSpacing: -1.2)),
          ])),
          FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black), onPressed: _createGoal, icon: const Icon(Icons.add), label: const Text('Add goal')),
        ]),
        const SizedBox(height: 9),
        const Text('Set the pace. The app keeps track.', style: TextStyle(color: mutedText)),
        const SizedBox(height: 24),
        if (store!.goals.isEmpty) _emptyGoals() else ...store!.goals.map(_goalCard),
        const SizedBox(height: 14),
        _freezeCard(),
      ]);

  Widget _emptyGoals() => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF2D314B))),
        child: Column(children: [
          const Icon(Icons.flag_outlined, color: accent, size: 35),
          const SizedBox(height: 11),
          const Text('Start with one small goal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          const Text('Set a duration or session target for any category.', textAlign: TextAlign.center, style: TextStyle(color: mutedText)),
          const SizedBox(height: 12),
          TextButton(onPressed: _createGoal, child: const Text('Create a goal')),
        ]),
      );

  Future<void> _createGoal() async {
    final name = TextEditingController();
    final target = TextEditingController(text: '60');
    var category = store!.categories.first.name;
    var schedule = 'Daily';
    var durationTarget = true;
    final weekdays = <int>{};
    final result = await showModalBottomSheet<Goal>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, change) => Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: _handle()),
            const SizedBox(height: 18),
            const Text('Create a goal', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 18),
            TextField(controller: name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Goal name')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(initialValue: category, decoration: const InputDecoration(labelText: 'Category'), items: store!.categories.map((item) => DropdownMenuItem(value: item.name, child: Text(item.name))).toList(), onChanged: (value) => change(() => category = value!)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(initialValue: schedule, decoration: const InputDecoration(labelText: 'Repeat'), items: const ['Daily', 'Weekly', 'Specific days'].map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(), onChanged: (value) => change(() => schedule = value!)),
            if (schedule == 'Specific days') ...[
              const SizedBox(height: 11),
              Wrap(spacing: 6, children: List.generate(7, (index) {
                final day = index + 1;
                return FilterChip(label: Text(const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index]), selected: weekdays.contains(day), onSelected: (value) => change(() { if (value) { weekdays.add(day); } else { weekdays.remove(day); } }));
              })),
            ],
            const SizedBox(height: 12),
            SwitchListTile(value: durationTarget, contentPadding: EdgeInsets.zero, title: const Text('Target a duration'), subtitle: Text(durationTarget ? 'Measured in minutes' : 'Measured in sessions', style: const TextStyle(color: mutedText)), onChanged: (value) => change(() => durationTarget = value)),
            TextField(controller: target, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: durationTarget ? 'Target minutes' : 'Target sessions')),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
              onPressed: () {
                final value = int.tryParse(target.text);
                if (name.text.trim().isEmpty || value == null || value < 1 || (schedule == 'Specific days' && weekdays.isEmpty)) return;
                Navigator.pop(context, Goal(id: _newId(), name: name.text.trim(), category: category, schedule: schedule, target: value, isDuration: durationTarget, weekdays: weekdays.toList()));
              },
              child: const Text('Create goal'),
            )),
          ])),
        ),
      ),
    );
    if (result == null) return;
    setState(() => store!.goals.add(result));
    await _save();
  }

  bool _goalApplies(Goal goal, DateTime date) => goal.schedule != 'Specific days' || goal.weekdays.contains(date.weekday);

  int _goalValue(Goal goal, DateTime date) {
    if (goal.schedule != 'Weekly') {
      return goal.isDuration ? _categoryMinutes(date, goal.category) : _categorySessions(date, goal.category);
    }
    var total = 0;
    for (var index = 0; index < 7; index++) {
      final day = date.subtract(Duration(days: index));
      total += goal.isDuration ? _categoryMinutes(day, goal.category) : _categorySessions(day, goal.category);
    }
    return total;
  }

  int _goalStreak(Goal goal) {
    if (goal.schedule == 'Weekly') return 0;
    var date = _dateOnly(DateTime.now());
    var streak = 0;
    for (var count = 0; count < 365; count++) {
      if (_goalApplies(goal, date) && _goalValue(goal, date) < goal.target) break;
      if (_goalApplies(goal, date)) streak++;
      date = date.subtract(const Duration(days: 1));
    }
    return streak;
  }

  Widget _goalCard(Goal goal) {
    final category = _category(goal.category);
    final value = _goalValue(goal, _dateOnly(DateTime.now()));
    final fraction = (value / goal.target).clamp(0, 1).toDouble();
    final current = goal.isDuration ? _duration(value) : '$value sessions';
    final target = goal.isDuration ? _duration(goal.target) : '${goal.target} sessions';
    final streak = _goalStreak(goal);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFF2D314B))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: category.color.withValues(alpha: .16), borderRadius: BorderRadius.circular(14)), child: Icon(category.icon, color: category.color)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(goal.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), Text('${goal.schedule} · ${goal.category}', style: const TextStyle(fontSize: 12, color: mutedText))])),
          IconButton(icon: const Icon(Icons.more_horiz, color: mutedText), onPressed: () => _deleteGoal(goal)),
        ]),
        const SizedBox(height: 16),
        ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: fraction, minHeight: 8, color: category.color, backgroundColor: surfaceLight)),
        const SizedBox(height: 9),
        Row(children: [Expanded(child: Text('$current / $target', style: const TextStyle(fontSize: 12, color: mutedText))), Icon(Icons.local_fire_department_rounded, color: streak == 0 ? mutedText : accent, size: 17), const SizedBox(width: 3), Text('${streak}d', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: streak == 0 ? mutedText : accent))]),
      ]),
    );
  }

  Future<void> _deleteGoal(Goal goal) async {
    final answer = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Delete goal?'), content: Text('Remove “${goal.name}”?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete'))]));
    if (answer != true) return;
    setState(() => store!.goals.remove(goal));
    await _save();
    await Backend.deleteGoal(goal.id);
  }

  Widget _freezeCard() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF2C3049), borderRadius: BorderRadius.circular(18)),
        child: const Row(children: [
          Icon(Icons.ac_unit_rounded, color: Color(0xFF8DCEFF)),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('1 streak freeze available', style: TextStyle(fontWeight: FontWeight.w900)),
            SizedBox(height: 3),
            Text('One missed day does not erase your progress.', style: TextStyle(fontSize: 12, color: mutedText)),
          ])),
        ]),
      );

  Widget _emptyCard(String text) => Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
        child: Text(text, style: const TextStyle(color: mutedText)),
      );

  Widget _dot(Color color, double size) => Container(width: size, height: size, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

  Widget _handle() => Container(width: 38, height: 4, decoration: BoxDecoration(color: const Color(0xFF555A71), borderRadius: BorderRadius.circular(4)));

  String _friendlyDate(DateTime date) {
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${months[date.month - 1]} ${date.day}';
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Profile bottom sheet
// ──────────────────────────────────────────────────────────────────────────────

class ProfileSheet extends StatefulWidget {
  const ProfileSheet({required this.onSignOut, super.key});

  final VoidCallback onSignOut;

  @override
  State<ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<ProfileSheet> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (mounted) widget.onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final displayName = Backend.displayName;
    final initial = email.isNotEmpty ? email[0].toUpperCase() : '?';
    final joinedAt = user?.createdAt != null
        ? DateTime.parse(user!.createdAt).toLocal()
        : null;
    final joinedStr = joinedAt != null
        ? '${joinedAt.day} ${_shortMonth(joinedAt.month)} ${joinedAt.year}'
        : null;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // drag handle
        Center(
          child: Container(
            width: 38, height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF555A71),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        // Avatar + name + email
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF776CFF), Color(0xFFBE7AFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          alignment: Alignment.center,
          child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 30)),
        ),
        const SizedBox(height: 14),
        if (displayName.isNotEmpty) ...[
          Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
        ],
        Text(email, style: const TextStyle(fontSize: 14, color: mutedText)),
        if (joinedStr != null) ...[
          const SizedBox(height: 4),
          Text('Member since $joinedStr', style: const TextStyle(fontSize: 11, color: mutedText)),
        ],
        const SizedBox(height: 24),
        // Sync status pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: surfaceLight, borderRadius: BorderRadius.circular(14)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_done_rounded, size: 16, color: accent),
            SizedBox(width: 8),
            Text('Data synced across your devices', style: TextStyle(fontSize: 12, color: primaryText)),
          ]),
        ),
        const SizedBox(height: 24),
        // Sign out button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF3B405B)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: const Color(0xFFFF6B6B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _signingOut ? null : _signOut,
            icon: _signingOut
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF6B6B)))
                : const Icon(Icons.logout_rounded, size: 18),
            label: Text(_signingOut ? 'Signing out…' : 'Sign out'),
          ),
        ),
      ]),
    );
  }

  String _shortMonth(int month) {
    const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return names[month - 1];
  }
}
