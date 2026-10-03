import 'package:doctylia_app/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _pageIndex = 0;

  static const _slides = [
    _OnboardingSlideData(
      eyebrow: 'DOCTYLIA',
      title: 'Manage Smart. Heal More.',
      message: 'Complete clinic management, built for modern doctors.',
      imagePath: 'assets/images/onboarding/onboarding_hero_1.png',
      buttonLabel: 'Let’s Simplify',
      caption: 'Your clinic, simplified.',
      decoration: _HeaderDecoration.dashboard,
    ),
    _OnboardingSlideData(
      eyebrow: 'APPOINTMENTS',
      title: 'Book Smart.\nNever Miss.',
      message: 'Smart scheduling that keeps\nyour clinic on time.',
      imagePath: 'assets/images/onboarding/onboarding_hero_2.png',
      buttonLabel: 'Next',
      caption: 'Every second counts.',
      decoration: _HeaderDecoration.appointments,
    ),
    _OnboardingSlideData(
      eyebrow: 'RECORDS',
      title: 'Organized Files.\nZero Chaos.',
      message: 'Every patient history, just one tap away.',
      imagePath: 'assets/images/onboarding/onboarding_hero_3.png',
      buttonLabel: 'Next',
      caption: 'History at your fingertips.',
      decoration: _HeaderDecoration.records,
    ),
    _OnboardingSlideData(
      eyebrow: 'ANALYTICS',
      title: 'Track Growth.\nGrow Smart.',
      message: 'Insights that help your clinic grow every day.',
      imagePath: 'assets/images/onboarding/onboarding_hero_4.png',
      buttonLabel: 'Join Doctylia',
      caption: 'Your clinic’s growth, visualized.',
      decoration: _HeaderDecoration.analytics,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _complete() {
    return ref.read(onboardingSeenProvider.notifier).complete();
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _pageIndex == _slides.length - 1;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FBFF),
      body: SafeArea(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.75, -0.8),
              radius: 1.25,
              colors: [Color(0xFFFFFFFF), Color(0xFFF5F9FE)],
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 720;
              final slide = _slides[_pageIndex];
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  compact ? 8 : 18,
                  20,
                  compact ? 12 : 20,
                ),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Expanded(
                          child: PageView.builder(
                            controller: _pageController,
                            itemCount: _slides.length,
                            onPageChanged: (index) =>
                                setState(() => _pageIndex = index),
                            itemBuilder: (context, index) => _OnboardingSlide(
                              data: _slides[index],
                              compact: compact,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 12 : 20),
                        _PageIndicator(
                          count: _slides.length,
                          selectedIndex: _pageIndex,
                        ),
                        SizedBox(height: compact ? 14 : 24),
                        _OnboardingButton(
                          label: slide.buttonLabel,
                          onPressed: isLastPage
                              ? _complete
                              : () => _pageController.nextPage(
                                  duration: const Duration(milliseconds: 320),
                                  curve: Curves.easeOutCubic,
                                ),
                        ),
                        SizedBox(height: compact ? 8 : 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            slide.caption,
                            key: ValueKey(slide.caption),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color(0xFF657084),
                              fontSize: compact ? 13 : 15,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        opacity: isLastPage ? 0 : 1,
                        duration: const Duration(milliseconds: 180),
                        child: IgnorePointer(
                          ignoring: isLastPage,
                          child: _SkipButton(onPressed: _complete),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF073D8D),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        minimumSize: const Size(48, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'Skip',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OnboardingButton extends StatelessWidget {
  const _OnboardingButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF073D8D), Color(0xFF075CB2), Color(0xFF073D8D)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0753A4).withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: double.infinity,
            height: 58,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingSlide extends StatelessWidget {
  const _OnboardingSlide({required this.data, required this.compact});

  final _OnboardingSlideData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: compact ? 190 : 235,
          child: _OnboardingHeader(data: data, compact: compact),
        ),
        SizedBox(height: compact ? 6 : 12),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Image.asset(
                data.imagePath,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({required this.data, required this.compact});

  final _OnboardingSlideData data;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isBrandPage = data.eyebrow == 'DOCTYLIA';
    return Stack(
      children: [
        _HeaderDecorations(type: data.decoration),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 34),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  data.eyebrow,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF073D8D),
                    fontSize: isBrandPage
                        ? (compact ? 31 : 36)
                        : (compact ? 18 : 21),
                    fontWeight: FontWeight.w800,
                    letterSpacing: isBrandPage ? -1 : 0.2,
                  ),
                ),
                SizedBox(height: compact ? 8 : 12),
                Text(
                  data.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: isBrandPage
                        ? (compact ? 20 : 23)
                        : (compact ? 27 : 31),
                    height: 1.08,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(height: compact ? 8 : 13),
                Text(
                  data.message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF596579),
                    fontSize: compact ? 13 : 15,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderDecorations extends StatelessWidget {
  const _HeaderDecorations({required this.type});

  final _HeaderDecoration type;

  static const _blue = Color(0xFF0795D2);

  @override
  Widget build(BuildContext context) {
    final leftIcon = switch (type) {
      _HeaderDecoration.records => Icons.folder_open_outlined,
      _ => Icons.bar_chart_rounded,
    };
    final rightIcon = switch (type) {
      _HeaderDecoration.records => Icons.search_rounded,
      _ => Icons.trending_up_rounded,
    };
    final lowerIcon = switch (type) {
      _HeaderDecoration.dashboard => Icons.pie_chart_outline_rounded,
      _HeaderDecoration.records => Icons.add_circle_outline_rounded,
      _ => Icons.star_outline_rounded,
    };

    return IgnorePointer(
      child: Opacity(
        opacity: 0.95,
        child: Stack(
          children: [
            Positioned(
              left: 10,
              top: 5,
              child: Icon(leftIcon, color: _blue, size: 42),
            ),
            Positioned(
              right: 6,
              top: 65,
              child: Icon(rightIcon, color: _blue, size: 42),
            ),
            Positioned(
              left: 2,
              bottom: 5,
              child: Icon(lowerIcon, color: _blue, size: 40),
            ),
            const Positioned(
              right: 2,
              bottom: 12,
              child: Icon(
                Icons.add_rounded,
                color: Color(0xFF60B4DA),
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.count, required this.selectedIndex});

  final int count;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final selected = index == selectedIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 10,
          height: 10,
          margin: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0753A4) : const Color(0xFFB5C7D4),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? const Color(0xFF0753A4)
                  : const Color(0xFFB5C7D4),
            ),
          ),
        );
      }),
    );
  }
}

enum _HeaderDecoration { dashboard, appointments, records, analytics }

class _OnboardingSlideData {
  const _OnboardingSlideData({
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.imagePath,
    required this.buttonLabel,
    required this.caption,
    required this.decoration,
  });

  final String eyebrow;
  final String title;
  final String message;
  final String imagePath;
  final String buttonLabel;
  final String caption;
  final _HeaderDecoration decoration;
}
