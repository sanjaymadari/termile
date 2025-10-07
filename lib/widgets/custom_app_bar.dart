import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:get/get.dart';
import 'package:termile/constants.dart';
import 'package:termile/services/rate_us_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool isHomeScreen;
  final VoidCallback? onMenuPressed;

  const CustomAppBar({
    super.key,
    required this.title,
    this.onMenuPressed,
    this.isHomeScreen = false,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.grey.shade900,
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.white, // Optional: text color
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: onMenuPressed ??
              () {
                // I want here to show a menu with options like "Settings", "About", etc.
                // Like it should come from right to left and covers the screen 90%
                _showRightSideMenu(context);
              },
        ),
      ],
    );
  }

  // Method to show the right side menu
  void _showRightSideMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54, // Background dim color
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8, // 80% width
            height: double.infinity,
            color: Colors.grey.shade900,
            child: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== App Icon + App Name Section =====
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  TermileConstants.appName,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                FutureBuilder<PackageInfo>(
                                  future: PackageInfo.fromPlatform(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Text(
                                        'Version ${snapshot.data!.version}',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          decoration: TextDecoration.none,
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Colors.white24, thickness: 1),

                    // ===== Menu Items Section =====
                    _meterialWidgetTile(
                      context: context,
                      icon: Icons.star,
                      title: 'Rate Us',
                      onTap: () {
                        Navigator.pop(context);
                        _rateUs();
                      },
                    ),
                    _meterialWidgetTile(
                      context: context,
                      icon: Icons.share,
                      title: 'Share App',
                      onTap: () {
                        Navigator.pop(context);
                        _shareApp();
                      },
                    ),
                    _meterialWidgetTile(
                      context: context,
                      icon: Icons.feedback,
                      title: 'Feedback',
                      onTap: () {
                        Navigator.pop(context);
                        _giveFeedback();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(begin: const Offset(1, 0), end: Offset.zero);
        return SlideTransition(
          position: tween.animate(animation),
          child: child,
        );
      },
    );
  }

  _meterialWidgetTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.grey.shade900,
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        onTap: onTap ?? () => Navigator.pop(context),
      ),
    );
  }

  void _giveFeedback() {
    launchUrl(
      Uri.parse(
          'https://www.varnastechsolutions.com/traintogo/feedback?app=termile'),
    );
  }

  void _shareApp() {
    final String message =
        'Check out ${TermileConstants.appName} - Your ultimate SSH terminal companion!\n\n';
    final String playStoreLink =
        'https://play.google.com/store/apps/details?id=com.termile.app';
    final String shareText = '$message\n$playStoreLink';

    SharePlus.instance.share(
      ShareParams(text: shareText, subject: TermileConstants.appName),
    );
  }

  void _rateUs() async {
    try {
      await RateUsService.requestReview();
    } catch (e) {
      // Show a snackbar or dialog if rating fails
      if (Get.context != null) {
        Get.snackbar(
          'Error',
          'Unable to open rating dialog. Please try again later.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
  }
}
