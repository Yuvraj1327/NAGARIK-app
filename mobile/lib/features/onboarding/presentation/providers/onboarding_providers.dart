import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nagarik/features/onboarding/data/onboarding_service.dart';

final onboardingServiceProvider = Provider<OnboardingService>((ref) => OnboardingService());
