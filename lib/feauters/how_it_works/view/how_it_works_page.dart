import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:watchparty/shared/atoms/app_button.dart';
import 'package:watchparty/shared/atoms/dot_indicator.dart';
import 'package:watchparty/shared/atoms/step_number_badge.dart';
import 'package:watchparty/shared/molecules/how_it_works_step_card.dart';

class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0A0A0A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0).copyWith(top: 80, bottom: 120),
        child: Center(
          child: Column(
            children: [
              const Text(
                "How It Works",
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                "It's simple, fast, and fun.",
                style: TextStyle(fontSize: 18, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 20),
              HowItWorksStepCard(
                stepNumber: 1,
                iconPath: "assets/icons/chain-icon.png",
                title: "Paste a YouTube Link",
                description:
                    "Add any YouTube video link to instantly create a watch room.",
              ),
              const SizedBox(height: 20),
              HowItWorksStepCard(
                stepNumber: 2,
                iconPath: "assets/icons/invite-icon.png",
                title: "Invite Your Friends",
                description:
                    "Share the auto-generated room link with anyone you want to watch with.",
              ),
              const SizedBox(height: 20),
              HowItWorksStepCard(
                stepNumber: 3,
                iconPath: "assets/icons/play-button.png",
                title: "Watch Together",
                description:
                    "Watch the video in perfect sync with everyone in the room.",
              ),
              const SizedBox(height: 20),
              HowItWorksStepCard(
                stepNumber: 4,
                iconPath: "assets/icons/chat-icon.png",
                title: "Chat & React",
                description:
                    "Send messages and reactions while watching together in real-time.",
              ),
              const SizedBox(height: 20),
              DotIndicator(),
              const Text(
                "That's it! No signup required.",
                style: TextStyle(fontSize: 18, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 20),
              AppButton(
                label: "Got It!",
                onPressed: () {
                  context.pushNamed('home');
                },
                assetIconPath: "assets/icons/check-icon.png",
              )
            ],
          ),
        ),
      ),
    );
  }
}
