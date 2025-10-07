import 'package:url_launcher/url_launcher.dart';

class RateUsService {
  static Future<void> requestReview() async {
    // For now, we'll just open the app store
    // In a real implementation, you might want to use in_app_review package
    final url = Uri.parse(
        'https://play.google.com/store/apps/details?id=com.varnastechsolutions.termile');

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      throw Exception('Could not launch app store');
    }
  }
}
