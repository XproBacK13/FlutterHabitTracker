import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background messages
  print('Handling a background message: ${message.messageId}');
}

Future<void> requestNotificationPermission() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted permission');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print('User granted provisional permission');
  } else {
    print('User declined or has not accepted permission');
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAYWd7GUhRP3GfQDqd25Po1camKGPTc18c",
      authDomain: "habit-tracker-f4f47.firebaseapp.com",
      projectId: "habit-tracker-f4f47",
      storageBucket: "habit-tracker-f4f47.appspot.com",
      messagingSenderId: "435208808943",
      appId: "1:435208808943:web:d82b62559ddcca8df9959a",
      measurementId: "G-V7SX1TVC3B",
    ),
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await requestNotificationPermission();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  void _toggleTheme(bool isDarkMode) {
    setState(() {
      _isDarkMode = isDarkMode;
    });
    _saveThemePreference(isDarkMode);
  }

  Future<void> _saveThemePreference(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('isDarkMode', isDarkMode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Habit Tracker',
      theme: _isDarkMode ? ThemeData.dark() : ThemeData.light(),
      home: FirebaseAuth.instance.currentUser == null
          ? AuthScreen(onThemeChanged: _toggleTheme)
          : DashboardScreen(onThemeChanged: _toggleTheme),
    );
  }
}



class AuthScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;

  const AuthScreen({Key? key, required this.onThemeChanged}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true; // Toggle between Login and Sign-Up
  String? _errorMessage;

  Future<void> _authenticate() async {
    try {
      if (_isLogin) {
        // Login
        await _auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              onThemeChanged: widget.onThemeChanged,
            ),
          ),
        );
      } else {
        // Sign-Up
        await _auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DashboardScreen(
              onThemeChanged: widget.onThemeChanged,
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Sign-Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _authenticate,
              child: Text(_isLogin ? 'Login' : 'Sign-Up'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLogin = !_isLogin; // Toggle between Login and Sign-Up
                });
              },
              child: Text(
                _isLogin
                    ? "Don’t have an account? Sign Up"
                    : "Already have an account? Login",
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 20),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}















class DashboardScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;

  const DashboardScreen({Key? key, required this.onThemeChanged}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _filter = 'All'; // Default filter
  String _sortBy = 'Timestamp'; // Default sorting
  bool _isDarkMode = false; // Track dark mode state

  @override
  void initState() {
    super.initState();
    _loadPreferences(); // Load saved preferences
    resetHabitsDaily(); // Reset habits daily
  }

  // Load preferences from local storage
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _filter = prefs.getString('filter') ?? 'All';
      _sortBy = prefs.getString('sortBy') ?? 'Timestamp';
      _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    });
  }

  // Save preferences to local storage
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('filter', _filter);
    await prefs.setString('sortBy', _sortBy);
  }

  // Reset habits daily
  Future<void> resetHabitsDaily() async {
    final CollectionReference habitsCollection =
    FirebaseFirestore.instance.collection('habits');

    // Get all habits
    final snapshot = await habitsCollection.get();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;

      // Check if the habit needs to be reset
      final lastReset = (data['lastReset'] as Timestamp?)?.toDate();
      final today = DateTime.now();

      if (lastReset == null ||
          lastReset.day != today.day ||
          lastReset.month != today.month ||
          lastReset.year != today.year) {
        // Reset the habit
        await habitsCollection.doc(doc.id).update({
          'completed': false,
          'lastReset': today,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final CollectionReference habitsCollection =
    FirebaseFirestore.instance.collection('habits');

    Query habitsQuery = habitsCollection;

    if (_filter == 'Completed') {
      habitsQuery = habitsQuery.where('completed', isEqualTo: true);
    } else if (_filter == 'Pending') {
      habitsQuery = habitsQuery.where('completed', isEqualTo: false);
    }

    if (_sortBy == 'Alphabetical') {
      habitsQuery = habitsQuery.orderBy('name');
    } else {
      habitsQuery = habitsQuery.orderBy('timestamp', descending: true);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Tracker'),
        actions: [
          IconButton(
            icon: Icon(_isDarkMode ? Icons.dark_mode : Icons.light_mode),
            onPressed: () {
              setState(() {
                _isDarkMode = !_isDarkMode;
              });
              widget.onThemeChanged(_isDarkMode); // Trigger theme change
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              FirebaseAuth.instance.signOut();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => AuthScreen(onThemeChanged: widget.onThemeChanged),
                ),
              );

            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Indicator Section
          StreamBuilder<QuerySnapshot>(
            stream: habitsCollection.snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Loading progress...'),
                );
              }

              final totalHabits = snapshot.data!.docs.length;
              final completedHabits = snapshot.data!.docs
                  .where((doc) => (doc.data() as Map<String, dynamic>)['completed'] == true)
                  .length;

              final progress = totalHabits == 0
                  ? 0.0
                  : completedHabits / totalHabits;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Progress: $completedHabits / $totalHabits habits completed',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      color: Colors.green,
                    ),
                  ],
                ),
              );
            },
          ),
          // Filters and Sorting
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  value: _filter,
                  items: ['All', 'Completed', 'Pending']
                      .map((filter) => DropdownMenuItem(
                    value: filter,
                    child: Text(filter),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _filter = value!;
                    });
                    _savePreferences(); // Save preferences
                  },
                ),
                DropdownButton<String>(
                  value: _sortBy,
                  items: ['Timestamp', 'Alphabetical']
                      .map((sort) => DropdownMenuItem(
                    value: sort,
                    child: Text('Sort by $sort'),
                  ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _sortBy = value!;
                    });
                    _savePreferences(); // Save preferences
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: habitsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading habits.'));
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No habits found.'));
                }
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return Dismissible(
                      key: Key(doc.id),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) {
                        // Delete habit from Firestore
                        habitsCollection.doc(doc.id).delete();
                        // Show confirmation message
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Habit deleted successfully!')),
                        );
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16.0),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      child:  Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(
                    color: data['completed'] ?? false ? Colors.green : Colors.grey,
                    width: 2,
                    ),
                    ),
                    child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                    width: 10,
                    height: double.infinity,
                    decoration: BoxDecoration(
                    color: data['completed'] ?? false ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(5),
                    ),
                    ),
                    title: Text(
                    data['name'] ?? 'Unnamed Habit',
                    style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: data['completed'] ?? false
                    ? Colors.green[800]
                        : Theme.of(context).brightness == Brightness.dark
                    ? Colors.white // White text for dark mode
                        : Colors.black, // Black text for light mode
                    ),
                    ),
                    subtitle: Text(
                    data['description'] ?? 'No description provided',
                    style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[300] // Subtle text color in dark mode
                        : Colors.grey[600],
                    ),
                    ),
                    trailing: Row(
                    mainAxisSize: MainAxisSize.min, // Ensures the row doesn't take full width
                    children: [
                    // Checkbox for marking completion
                    Checkbox(
                    value: data['completed'] ?? false,
                    onChanged: (bool? value) {
                    habitsCollection.doc(doc.id).update({'completed': value});
                    },
                    ),
                    // Delete button
                    IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                    // Confirm habit deletion
                    showDialog(
                    context: context,
                    builder: (BuildContext context) {
                    return AlertDialog(
                    title: const Text('Delete Habit'),
                    content: const Text('Are you sure you want to delete this habit?'),
                    actions: [
                    TextButton(
                    onPressed: () => Navigator.pop(context), // Cancel
                    child: const Text('Cancel'),
                    ),
                    TextButton(
                    onPressed: () {
                    habitsCollection.doc(doc.id).delete(); // Delete habit
                    Navigator.pop(context); // Close dialog
                    ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Habit deleted successfully!')),
                    );
                    },
                    child: const Text('Delete'),
                    ),
                    ],
                    );
                    },
                    );
                    },
                    ),
                    ],
                    ),
                    ),



                    ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
              const AddHabitScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0); // Slide from bottom
                const end = Offset.zero;
                const curve = Curves.ease;

                var tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                var offsetAnimation = animation.drive(tween);

                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              },
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}


class AddHabitScreen extends StatelessWidget {
  const AddHabitScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController _nameController = TextEditingController();
    final TextEditingController _descriptionController = TextEditingController();
    final CollectionReference habitsCollection =
    FirebaseFirestore.instance.collection('habits'); // Firestore collection

    Future<void> _saveHabit() async {
      final String name = _nameController.text.trim();
      final String description = _descriptionController.text.trim();

      // Validate input fields
      if (name.isEmpty || description.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields.')),
        );
        return; // Stop execution if fields are empty
      }

      try {
        // Save habit to Firestore
        await habitsCollection.add({
          'name': name,
          'description': description,
          'completed': false, // Default value for new habits
          'timestamp': FieldValue.serverTimestamp(),
          'lastReset': DateTime.now(), // Add the lastReset field
        });



        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Habit added successfully!')),
        );

        // Delay briefly to allow the user to see the confirmation message
        await Future.delayed(const Duration(milliseconds: 500));

        // Force navigation back to the Dashboard
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop(); // Works even if async operation affects navigation
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Add Habit')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Habit Name'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveHabit, // Call the save habit function
              child: const Text('Save Habit'),
            ),
          ],
        ),
      ),
    );
  }
}


