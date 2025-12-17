import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../widgets/eco_header.dart';
import '../screens/auth_screen.dart';
import '../services/auth_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  // Profile image URL stored in Firestore
  String? _profileImageUrl;

  // Firebase user fields
  String? firstName = "";
  String? lastName = "";
  String? screenName = "";
  String? email = "";

  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Load user data (including profileImageUrl) from Firestore
  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        setState(() {
          firstName = data['firstName'] as String? ?? "";
          lastName = data['lastName'] as String? ?? "";
          screenName = data['screenName'] as String? ?? "";
          email = data['userEmail'] as String? ?? "";
          _profileImageUrl = data['profileImageUrl'] as String?;
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    await _processSelectedImage(File(image.path));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera),
                title: const Text('Take a Photo'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (image != null) {
                    await _processSelectedImage(File(image.path));
                  }
                },
              ),
              if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete),
                  title: const Text('Remove Photo'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _removeProfileImage();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _processSelectedImage(File file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profileImages')
          .child(user.uid)
          .child('profile.jpg');

      // Upload to Firebase Storage
      await storageRef.putFile(file);

      // Get download URL
      final downloadUrl = await storageRef.getDownloadURL();

      // Save URL in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'profileImageUrl': downloadUrl},
      );

      setState(() {
        _profileImageUrl = downloadUrl;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated!')));
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update profile photo. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  Future<void> _removeProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Clear the field in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {'profileImageUrl': FieldValue.delete()},
      );

      // Optionally also delete from Storage (ignore errors)
      try {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('profileImages')
            .child(user.uid)
            .child('profile.jpg');
        await storageRef.delete();
      } catch (_) {}

      setState(() {
        _profileImageUrl = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo removed.')));
    } catch (e) {
      debugPrint('Error removing profile image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to remove photo. Please try again.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color green = Color(0xFF4CAF50);

    return Scaffold(
      appBar: const EcoTrackHeader(),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  'Profile',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),

              // PROFILE AVATAR
              Center(
                child: GestureDetector(
                  onTap: _isUploadingImage ? null : _pickImage,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: green,
                        backgroundImage:
                            _profileImageUrl != null &&
                                _profileImageUrl!.isNotEmpty
                            ? NetworkImage(_profileImageUrl!)
                            : null,
                        child:
                            (_profileImageUrl == null ||
                                _profileImageUrl!.isEmpty)
                            ? const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 50,
                              )
                            : null,
                      ),

                      // Small uploading overlay
                      if (_isUploadingImage)
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),

                      // Camera icon badge
                      if (!_isUploadingImage)
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: green,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.only(top: 15.5),
                child: Divider(color: Colors.grey, thickness: 1.5),
              ),
              const SizedBox(height: 20),

              // Display user data pulled from Firebase
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  "Name: $firstName $lastName\n"
                  "Screen Name: $screenName\n"
                  "Email: $email",
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
              ),

              const Spacer(),

              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await _authService.signOut();
                      if (!mounted) return;
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AuthScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),

          // Back button
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ],
      ),
    );
  }
}
