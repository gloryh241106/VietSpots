# VietSpots

A modern, professionally-designed Flutter application for discovering and exploring tourist spots in Vietnam, powered by AI chat assistance. Built with Material Design 3 principles and a comprehensive design system achieving 10/10 UI/UX standards.

## ✨ Features

### 🤖 AI-Powered Experience
- **Intelligent Travel Assistant**: Chat with VietSpots AI for personalized travel recommendations
- **Chat History (In-session)**: Open previous conversations from the History drawer
- **Real-time Responses**: Smooth chat interface with typing indicators and timestamps

### 🎨 Professional UI/UX Design
- **Design System**: Comprehensive typography tokens, 8px spacing grid, and color system
- **WCAG AA Compliant**: Accessible contrast ratios for dark and light modes
- **Visual Hierarchy**: Clear section headers, improved readability, consistent styling
- **Micro-interactions**: Pull-to-refresh, smooth transitions, visual feedback
- **Enhanced Empty States**: Helpful illustrations and actionable CTAs

### 🌟 Core Features
- **Place Discovery**: Browse curated tourist destinations across Vietnam
- **Smart Search**: Real-time search with clear button and filters
- **Favorites Management**: Save and organize your favorite places
- **User Authentication**: Secure login and registration system
- **Notifications**: Visual states for read/unread with red dot indicators
- **Notification Details**: Tap a notification to see the full content
- **Dark/Light Theme**: Seamless theme switching with proper contrast
- **Multi-language Support**: English/Vietnamese/Russian/Chinese via `LocalizationProvider`
- **Profile & Settings**:
   - Change avatar from the device gallery (with runtime permission)
   - General Information: Full name, email, phone (validated)
   - Private Information: Preferences, Culture, Religion, Companion preference
   - Change Password: validates current password (demo/in-memory)
- **Offline Support**: Mock data for demonstration purposes

## Screenshots

*(Add screenshots here when available)*

## 📋 Requirements

- **Flutter**: 3.38.5 or higher
- **Dart**: 3.10.4 or higher
- **Android Studio** or **Visual Studio Code** with Flutter extension
- **Android SDK** (for Android development)
- **Xcode** (for iOS development on macOS)

## Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/your-username/vietspots.git
   cd vietspots
   ```

2. **Install Flutter dependencies**:
   ```bash
   flutter pub get
   ```

3. **Set up your development environment**:
   - For Android: Ensure Android SDK is installed and configured
   - For iOS: Ensure Xcode is installed (macOS only)
   - For Web: No additional setup required

## Running the Application

### Development Mode

1. **Check connected devices**:
   ```bash
   flutter devices
   ```

2. **Run on specific platform**:
   ```bash
   # Android
   flutter run -d android

   # iOS (macOS only)
   flutter run -d ios

   # Web
   flutter run -d chrome

   # Windows (requires Visual Studio)
   flutter run -d windows

   # Linux
   flutter run -d linux

   # macOS
   flutter run -d macos
   ```

3. **Run tests**:
   ```bash
   flutter test
   ```

### Building for Production

1. **Build APK (Android)**:
   ```bash
   flutter build apk --release
   ```

2. **Build iOS (macOS only)**:
   ```bash
   flutter build ios --release
   ```

3. **Build Web**:
   ```bash
   flutter build web --release
   ```

## 📁 Project Structure

```
lib/
├── main.dart                 # Application entry point
├── models/                   # Data models
│   ├── chat_model.dart       # Chat message model with timestamps
│   ├── place_model.dart      # Place/location data model
│   └── user_model.dart       # User authentication model
├── providers/                # State management (Provider pattern)
│   ├── auth_provider.dart    # Authentication state
│   ├── chat_provider.dart    # Chat history management
│   ├── localization_provider.dart  # Language switching
│   ├── place_provider.dart   # Places and favorites state
│   └── theme_provider.dart   # Dark/Light theme state
├── screens/                  # UI screens
│   ├── auth/                 # Login and registration
│   ├── detail/               # Place detail screen
│   ├── main/                 # Main app screens
│   │   ├── home_screen.dart  # Home with place discovery
│   │   ├── search_screen.dart # Search with filters
│   │   ├── chat_screen.dart  # AI chat assistant
│   │   ├── notification_screen.dart # Notifications with visual states
│   │   ├── notification_detail_screen.dart # Full notification view
│   │   ├── favorites_screen.dart # Saved places
│   │   ├── settings_screen.dart # User settings
│   │   └── main_screen.dart  # Bottom navigation wrapper
│   ├── settings/             # Settings sub-screens
│   └── splash_screen.dart    # App launch screen
├── utils/                    # Utilities and design system
│   ├── mock_data.dart        # Sample data for demo
│   ├── avatar_image_provider.dart # Avatar: network vs local file
│   ├── theme.dart            # Theme configuration (colors, card styles)
│   └── typography.dart       # Design tokens (fonts, spacing, colors)
└── widgets/                  # Reusable widgets
    └── place_card.dart       # Place card component
```

## 🎨 Design System

VietSpots follows a comprehensive design system ensuring consistency and accessibility across the app.

### Typography Tokens

Standardized text styles defined in `lib/utils/typography.dart`:

```dart
// Headings
heading1: 24px, w700    // Major sections
heading2: 20px, w700    // Page titles
heading3: 18px, w600    // Subsections

// Section Headers
sectionHeader: 16px, w600, letter-spacing: 0.15

// Body Text
bodyLarge: 16px, w400
bodyMedium: 14px, w400

// Labels & Captions
labelLarge: 14px, w600
labelMedium: 12px, w500
caption: 12px, w400
```

### Spacing System (8px Grid)

```dart
xs: 4px   // Minimal spacing
sm: 8px   // Small gaps
md: 16px  // Standard padding
lg: 24px  // Section spacing
xl: 32px  // Large sections
xxl: 48px // Extra large
```

### Color System (WCAG AA Compliant)

**Light Mode:**
- Primary Text: `#212121` (grey[900])
- Secondary Text: `#616161` (grey[700]) - 4.5:1 contrast
- Tertiary Text: `#9E9E9E` (grey[500])

**Dark Mode:**
- Primary Text: `#FFFFFF` (white)
- Secondary Text: `#B0B0B0` - Improved contrast
- Tertiary Text: `#808080`
- Card Background: `#252525` - Enhanced from #1E1E1E
- Scaffold Background: `#121212`

**Brand Colors:**
- Primary Red: `#D32F2F`
- Accent Yellow: `#FFC107`

### UI Components

- **Border Radius**: 12px (cards), 20-30px (search bars), circle (avatars)
- **Elevation**: Minimal shadows (2-4dp) for subtle depth
- **Transitions**: Smooth 200-400ms animations

## 📦 Dependencies

Key packages used in this project:

- **provider** (^6.1.2): State management
- **cached_network_image** (^3.4.1): Optimized image loading and caching
- **permission_handler** (^11.4.0): Runtime permission management
- **image_picker** (^1.1.2): Pick avatar image from device gallery
- **url_launcher** (^6.3.1): Open URLs and external apps
- **intl** (^0.19.0): Internationalization and date formatting
- **google_fonts** (^6.2.1): Noto Sans for better multi-language glyph coverage

See `pubspec.yaml` for complete list of dependencies.

## Configuration

### Environment Setup

1. **Android**: Add to `android/app/build.gradle`:
   ```gradle
   android {
       defaultConfig {
           minSdkVersion 21
           targetSdkVersion 34
       }
   }
   ```

2. **iOS**: Add to `ios/Runner/Info.plist`:
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>This app needs location access for travel recommendations</string>
   ```

### API Keys

*(Add instructions for any required API keys)*

## 🏗️ Architecture & Best Practices

### State Management
- **Provider Pattern**: Separation of business logic from UI
- **Consumer Widgets**: Efficient rebuilds for specific state changes
- **ChangeNotifier**: Reactive state updates

### Notes / Limitations (Current)
- Chat history and user profile are stored **in memory** (demo mode). There is no persistence layer in this project.
- Password validation in "Change Password" is also **in-memory demo logic** (no backend).

### Code Quality
- **Type Safety**: Strict null safety enabled
- **Linting**: Flutter recommended lints
- **Formatting**: Consistent code formatting with `dart format`
- **No Deprecation**: All deprecated APIs replaced (e.g., `withOpacity` → `withValues`)

### Accessibility
- **WCAG AA Compliance**: All text meets 4.5:1 contrast ratio
- **Touch Targets**: Minimum 48dp for interactive elements
- **Screen Reader Support**: Semantic labels for assistive technologies

### Performance
- **Lazy Loading**: ListView.builder for efficient list rendering
- **Image Caching**: CachedNetworkImage for optimized loading
- **Build Optimization**: Const constructors where possible

### UI/UX Patterns
- **Pull-to-Refresh**: RefreshIndicator on all list screens
- **Loading States**: Skeleton screens and progress indicators
- **Error Handling**: User-friendly error messages with retry actions
- **Empty States**: Helpful illustrations with clear CTAs

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Troubleshooting

### Common Issues

1. **Flutter SDK version mismatch**:
   ```bash
   flutter upgrade
   flutter pub get
   ```

2. **Permission issues**:
   - Ensure location permissions are granted
   - Check app permissions in device settings

3. **Build failures**:
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### Getting Help

- [Flutter Documentation](https://docs.flutter.dev/)
- [Flutter Community](https://flutter.dev/community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Flutter team for the amazing framework
- Open source community for the packages used
- Vietnamese tourism industry for inspiration
