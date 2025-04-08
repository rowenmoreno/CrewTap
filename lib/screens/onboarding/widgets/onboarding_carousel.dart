import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class OnboardingCarousel extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingCarousel({
    super.key,
    required this.onComplete,
  });

  @override
  State<OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends State<OnboardingCarousel> {
  final List<OnboardingSlide> _slides = [
    OnboardingSlide(
      title: 'Welcome to CrewTap',
      description: 'Connect with your crew members and stay organized.',
      // image: 'assets/images/onboarding1.png',
    ),
    OnboardingSlide(
      title: 'Easy Communication',
      description: 'Chat, share updates, and coordinate with your team.',
      // image: 'assets/images/onboarding2.png',
    ),
    OnboardingSlide(
      title: 'Stay Organized',
      description: 'Keep track of tasks and schedules in one place.',
      // image: 'assets/images/onboarding3.png',
    ),
  ];

  int _currentIndex = 0;
  final CarouselSliderController _carouselController = CarouselSliderController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: CarouselSlider.builder(
            carouselController: _carouselController,
            options: CarouselOptions(
              height: double.infinity,
              enableInfiniteScroll: false,
              viewportFraction: 1.0,
              onPageChanged: (index, reason) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),
            itemCount: _slides.length,
            itemBuilder: (context, index, realIndex) {
              final slide = _slides[index];
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Placeholder container for image
                  Container(
                    height: 200,
                    width: 200,
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.group,
                      size: 80,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    slide.title,
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      slide.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _slides.asMap().entries.map((entry) {
              return Container(
                width: 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withOpacity(
                    _currentIndex == entry.key ? 0.9 : 0.4,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 32.0),
          child: ElevatedButton(
            onPressed: widget.onComplete,
            child: const Text('Get Started'),
          ),
        ),
      ],
    );
  }
}

class OnboardingSlide {
  final String title;
  final String description;
  final String? image;  // Made image optional

  OnboardingSlide({
    required this.title,
    required this.description,
    this.image,  // Made image optional
  });
} 