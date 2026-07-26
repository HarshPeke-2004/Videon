import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:videon/common/extension/text_theme_extension.dart';
import 'package:videon/common/utils/snackbar_utils.dart';
import 'package:videon/components/button/t_primary_button.dart';
import 'package:videon/components/utils/dialog_utils.dart';
import 'package:videon/styles/app_assets.dart';
import 'package:videon/styles/app_colors.dart';

/// Name of the Hive box used to persist locally-editable profile fields
/// (profile picture path + phone number). Make sure this box is opened
/// once at app startup, e.g. in main():
///   await Hive.openBox(ProfileScreen.hiveBoxName);
const String _profileHiveBoxName = 'profileBox';
const String _imagePathKey = 'profileImagePath';
const String _phoneNumberKey = 'phoneNumber';
const String _nameKey = 'name';

class ProfileScreen extends StatefulWidget {
  static const String hiveBoxName = _profileHiveBoxName;

  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser;
  late final Box _profileBox;

  File? _profileImage;
  String _phoneNumber = ''; // populated from Hive, no more hardcoded default
  String _name = '';

  @override
  void initState() {
    super.initState();
    _profileBox = Hive.box(_profileHiveBoxName);
    _loadSavedProfile();
  }

  void _loadSavedProfile() {
    final savedPath = _profileBox.get(_imagePathKey) as String?;
    if (savedPath != null && File(savedPath).existsSync()) {
      _profileImage = File(savedPath);
    }
    final savedPhone = _profileBox.get(_phoneNumberKey) as String?;
    if (savedPhone != null && savedPhone.isNotEmpty) {
      _phoneNumber = savedPhone;
    }

    // Name: prefer what's saved locally (kept in sync via the edit dialog),
    // fall back to the Firebase display name set at signup, then a generic default.
    final savedName = _profileBox.get(_nameKey) as String?;
    final firebaseName = FirebaseAuth.instance.currentUser?.displayName;
    _name = (savedName != null && savedName.isNotEmpty)
        ? savedName
        : (firebaseName != null && firebaseName.isNotEmpty)
            ? firebaseName
            : 'User';

    setState(() {});
  }

  Future<void> signout() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _pickAndSaveImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      // Copy into app documents dir with a fixed name so it persists
      // and overwrites any previous picture.
      final docsDir = await getApplicationDocumentsDirectory();
      final savedImage = await File(picked.path).copy(
        '${docsDir.path}/profile_picture.jpg',
      );

      await _profileBox.put(_imagePathKey, savedImage.path);

      setState(() {
        _profileImage = savedImage;
      });
    } catch (e) {
      if (!mounted) return;
      SnackBarUtils.showCustomSnackBar(
        context: context,
        content: 'Could not update profile picture',
      );
    }
  }

  Future<void> _showImageSourceSheet() async {
    await showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndSaveImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndSaveImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: _name);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Name'),
          content: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Enter your name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && result != _name) {
      await _profileBox.put(_nameKey, result);
      try {
        await FirebaseAuth.instance.currentUser?.updateDisplayName(result);
      } catch (_) {
        // Non-fatal: local Hive copy is already the source of truth for display.
      }
      setState(() {
        _name = result;
      });
    }
  }

  Future<void> _editPhoneNumber() async {
    final controller = TextEditingController(text: _phoneNumber);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Mobile No'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(hintText: 'Enter phone number'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty && result != _phoneNumber) {
      await _profileBox.put(_phoneNumberKey, result);
      setState(() {
        _phoneNumber = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            GestureDetector(
              onTap: _showImageSourceSheet,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 108,
                    height: 108,
                    decoration: ShapeDecoration(
                      image: DecorationImage(
                        image: _profileImage != null
                            ? FileImage(_profileImage!) as ImageProvider
                            : const AssetImage(AppAssets.avatar),
                        fit: BoxFit.fill,
                      ),
                      shape: const OvalBorder(
                        side: BorderSide(
                          width: 3.40,
                          strokeAlign: BorderSide.strokeAlignOutside,
                          color: AppColors.grey100,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 2,
                    right: 8,
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(
                        Icons.camera_alt,
                        color: AppColors.green500,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            InkWell(
              onTap: _editName,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _name,
                    style: context.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.edit, size: 16, color: AppColors.shadow),
                ],
              ),
            ),
            Text(
              FirebaseAuth.instance.currentUser?.email ?? '',
              style: const TextStyle(color: AppColors.shadow),
            ),
            const SizedBox(height: 32),
            _buildInfoRow("Location", "Maharashtra, India"),
            _buildInfoRow(
              "Mobile No",
              _phoneNumber,
              onTap: _editPhoneNumber,
              trailingIcon: Icons.edit,
            ),
            _buildInfoRow(
                "Email", FirebaseAuth.instance.currentUser?.email ?? ''),
            const Spacer(),
            TPrimaryButton(
              label: 'Log Out',
              isBusy: false,
              onPressed: () async {
                final shouldLogout = await DialogUtils.confirmationDialog(
                  context: context,
                  title: 'Log Out',
                  subtitle: 'Are you sure you want to log out?',
                  positiveLabel: 'Yes',
                  cancelLabel: 'Cancel',
                );
                if (shouldLogout ?? false) {
                  try {
                    await signout();
                  } catch (e) {
                    if (!mounted) return;
                    SnackBarUtils.showCustomSnackBar(
                      // ignore: use_build_context_synchronously
                      context: context,
                      content: 'Something went wrong',
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    VoidCallback? onTap,
    IconData? trailingIcon,
  }) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.shadow),
          ),
          Row(
            children: [
              Text(value),
              if (trailingIcon != null) ...[
                const SizedBox(width: 6),
                Icon(trailingIcon, size: 16, color: AppColors.shadow),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}