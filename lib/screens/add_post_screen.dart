import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../widgets/eco_navbar.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _selectedImagePath; // Local file path from image picker
  bool _isPostEnabled = false;
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_onDescriptionChanged);
  }

  void _onDescriptionChanged() {
    final hasText = _descriptionController.text.trim().isNotEmpty;
    if (hasText != _isPostEnabled) {
      setState(() {
        _isPostEnabled = hasText;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_onDescriptionChanged);
    _descriptionController.dispose();
    super.dispose();
  }

  // Show bottom sheet and let user pick from gallery/camera or remove image
  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    setState(() {
                      _selectedImagePath = image.path;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null) {
                    setState(() {
                      _selectedImagePath = image.path;
                    });
                  }
                },
              ),
              if (_selectedImagePath != null)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Remove Image'),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _selectedImagePath = null;
                    });
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitPost() async {
    if (_isPosting) return;

    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please write something first."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final auth = FirebaseAuth.instance;
    final firestore = FirebaseFirestore.instance;
    final storage = FirebaseStorage.instance;
    final user = auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You must be logged in to post."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      // 1. Build authorName similar to FriendsLog (firstName/lastName/screenName/userEmail)
      String authorName = 'Eco Friend';

      final userDoc = await firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final String firstName = (data['firstName'] ?? '') as String;
        final String lastName = (data['lastName'] ?? '') as String;
        final String screenName = (data['screenName'] ?? '') as String;
        final String userEmail =
            (data['userEmail'] ?? user.email ?? '') as String;

        final fullName = '$firstName $lastName'.trim();

        if (fullName.isNotEmpty) {
          authorName = fullName;
        } else if (screenName.isNotEmpty) {
          authorName = screenName;
        } else if (userEmail.isNotEmpty) {
          authorName = userEmail;
        }
      } else {
        // fallback if no user doc
        authorName = user.displayName ?? user.email ?? 'Eco Friend';
      }

      // 2. Upload image if selected
      String? imageUrl;
      if (_selectedImagePath != null) {
        final file = File(_selectedImagePath!);
        if (file.existsSync()) {
          final fileName =
              '${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final ref = storage.ref().child('postImages').child(fileName);

          await ref.putFile(file);
          imageUrl = await ref.getDownloadURL();
        }
      }

      // 3. Create post document in Firestore
      await firestore.collection('posts').add({
        'authorId': user.uid,
        'authorName': authorName,
        'text': description,
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0, // numeric likes only
        // no likedBy / inspiredBy fields
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Post submitted successfully! 🌱"),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to submit post. Please try again."),
          backgroundColor: Colors.redAccent,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const MaterialColor ecoGreen = Colors.green;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add a Post', style: TextStyle(color: Colors.white)),
        backgroundColor: ecoGreen.shade400,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Share your eco-action 🌿",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color.fromARGB(255, 18, 96, 21),
              ),
            ),
            const SizedBox(height: 20),

            // Description field
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Describe your eco-friendly action...",
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ecoGreen, width: 1.5),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: ecoGreen, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Image picker area
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: ecoGreen, width: 2),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey[50],
                ),
                child:
                    _selectedImagePath == null ||
                        !File(_selectedImagePath!).existsSync()
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_a_photo, color: ecoGreen),
                            SizedBox(height: 8),
                            Text("Add an image"),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(
                          File(_selectedImagePath!),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 30),

            // Submit button
            Center(
              child: MouseRegion(
                cursor: _isPostEnabled && !_isPosting
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                child: ElevatedButton.icon(
                  onPressed: _isPostEnabled && !_isPosting ? _submitPost : null,
                  icon: _isPosting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(_isPosting ? "Posting..." : "Post"),
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    ),
                    shape: WidgetStateProperty.all(
                      const RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                        side: BorderSide(color: ecoGreen, width: 2),
                      ),
                    ),
                    // Text + icon color
                    foregroundColor: WidgetStateProperty.resolveWith<Color?>((
                      states,
                    ) {
                      if (states.contains(WidgetState.disabled)) {
                        // Softer green text when disabled
                        return ecoGreen.shade300;
                      }
                      // White text/icon when enabled
                      return Colors.white;
                    }),
                    // Background color
                    backgroundColor: WidgetStateProperty.resolveWith<Color?>((
                      states,
                    ) {
                      if (states.contains(WidgetState.disabled)) {
                        // Very light green pill when disabled
                        return ecoGreen.shade50;
                      }
                      if (states.contains(WidgetState.pressed) ||
                          states.contains(WidgetState.hovered)) {
                        // Darker green on hover/press
                        return ecoGreen.shade700;
                      }
                      // Solid green when enabled
                      return ecoGreen;
                    }),
                    // A bit of elevation when enabled
                    elevation: WidgetStateProperty.resolveWith<double?>((
                      states,
                    ) {
                      if (states.contains(WidgetState.disabled)) {
                        return 0.0;
                      }
                      if (states.contains(WidgetState.pressed)) {
                        return 2.0;
                      }
                      return 4.0;
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const EcoNavBar(currentIndex: -1),
    );
  }
}
