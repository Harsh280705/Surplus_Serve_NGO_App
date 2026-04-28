import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

// When you have your screen recording URL, put it here.
const String? tutorialVideoUrl = null;
// Example later:
// const String? tutorialVideoUrl = 'https://youtu.be/your-video-id';

class HowToUsePage extends StatelessWidget {
  const HowToUsePage({super.key});

  @override
  Widget build(BuildContext context) {
    final steps = [
      {
        'title': 'Browse Items',
        'desc': 'View surplus items available near you.',
        'icon': Icons.search,
      },
      {
        'title': 'Request',
        'desc': 'Send a request for the items you need.',
        'icon': Icons.assignment_turned_in,
      },
      {
        'title': 'Donate',
        'desc': 'Post items you want to donate to others.',
        'icon': Icons.volunteer_activism,
      },
      {
        'title': 'Track',
        'desc': 'Track pickup / delivery status.',
        'icon': Icons.local_shipping,
      },
      {
        'title': 'Chat',
        'desc': 'Coordinate via in-app chat for smooth handover.',
        'icon': Icons.chat_bubble_outline,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('How to Use the App'),
        backgroundColor: kPrimaryColor,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 🔹 Section reserved for screen-recording link
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 1,
            child: ListTile(
              leading: const Icon(Icons.play_circle_fill, size: 32),
              title: const Text(
                'Watch Video Walkthrough',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                tutorialVideoUrl == null
                    ? 'Video guide coming soon.'
                    : 'Tap to watch the tutorial.',
              ),
              onTap: tutorialVideoUrl == null
                  ? null
                  : () {
                      // Later: use url_launcher to open the link
                      // launchUrl(Uri.parse(tutorialVideoUrl!));
                    },
            ),
          ),
          const SizedBox(height: 16),

          const Text(
            'Step-by-step Guide',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 12),

          ...List.generate(steps.length, (index) {
            final step = steps[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 1,
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(step['icon'] as IconData),
                  ),
                  title: Text(step['title'] as String),
                  subtitle: Text(step['desc'] as String),
                  trailing: Text('#${index + 1}'),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
