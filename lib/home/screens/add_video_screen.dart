import 'package:flutter/material.dart';
import 'package:videon/common/extra/reusable_info_screen.dart';
import 'package:videon/styles/app_assets.dart';

class AddVideoScreen extends StatelessWidget {
  const AddVideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ReusableInfoScreen(
      imagePath: AppAssets.image2,
      title: "Add Video",
      subtitle: "Upload your videos here!",
    );
  }
}
