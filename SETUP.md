# Gmail Alarm V2 - Setup Guide

## Prerequisites

- Flutter SDK (>=3.0.0)
- Android Studio / Xcode
- Google Cloud Console project with Gmail API enabled
- OAuth 2.0 credentials

## Google Cloud Setup

### 1. Create a Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable the Gmail API:
   - Navigate to "APIs & Services" > "Library"
   - Search for "Gmail API"
   - Click "Enable"

### 2. Configure OAuth Consent Screen

1. Go to "APIs & Services" > "OAuth consent screen"
2. Choose "External" user type
3. Fill in:
   - App name: "Gmail Alarm"
   - User support email: Your email
   - Developer contact: Your email
4. Add scopes:
   - `userinfo.email`
   - `gmail.readonly`
5. Add test users (your Gmail account)
6. Save and continue

### 3. Create OAuth 2.0 Credentials

#### For Android:

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth 2.0 Client ID"
3. Application type: "Android"
4. Package name: `com.example.gmail_alarm`
5. Get SHA-1 certificate fingerprint:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
6. Copy SHA-1 fingerprint
7. Create credentials
8. Download the client configuration

#### For iOS:

1. Create another OAuth 2.0 Client ID
2. Application type: "iOS"
3. Bundle ID: `com.example.gmailAlarm`
4. Download the client configuration

### 4. Update Android Configuration

Edit `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <!-- ... existing configuration ... -->
        
        <!-- Google Sign-In -->
        <meta-data
            android:name="com.google.android.gms.version"
            android:value="@integer/google_play_services_version" />
    </application>

    <!-- Permissions -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT" />
</manifest>
```

### 5. iOS Configuration

Edit `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

Replace `YOUR_CLIENT_ID` with your OAuth 2.0 client ID.

## Installation

### 1. Clone and Setup

```bash
cd /path/to/gmail-alarm-v2
flutter pub get
```

### 2. Add Alarm Sound

Place an MP3 audio file at `assets/alarm.mp3`. This will be used as the alarm sound.

### 3. Run the App

```bash
# For Android
flutter run -d android

# For iOS
flutter run -d ios
```

## Configuration

### Google Sign-In Client IDs

The OAuth client IDs are managed by the `google_sign_in` package. You can specify them in the code:

```dart
final googleSignIn = GoogleSignIn(
  scopes: AppConstants.googleScopes,
  // Optional: specify client ID
  // clientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
);
```

## Testing

### Enable Test Mode

1. Tap the bug icon in the app toolbar
2. Test mode reduces token expiry to 10 seconds
3. This allows you to test token refresh without waiting 45 minutes

### Manual Testing Checklist

- [ ] Sign in with Google
- [ ] Add keywords
- [ ] Enable alarm
- [ ] Start background service
- [ ] Send test email matching keyword
- [ ] Verify alarm triggers
- [ ] Dismiss alarm
- [ ] Check service stays running
- [ ] Enable test mode
- [ ] Verify token refresh works
- [ ] Kill app, verify service continues
- [ ] Reboot device, verify service restarts

## Troubleshooting

### Google Sign-In Fails

- Verify OAuth 2.0 credentials are configured correctly
- Check SHA-1 fingerprint matches
- Ensure Gmail API is enabled
- Add your test account to OAuth consent screen

### Background Service Stops

- Check battery optimization settings
- Disable "Battery Optimization" for the app
- On Android, go to Settings > Apps > Gmail Alarm > Battery > Unrestricted

### Alarm Doesn't Sound

- Ensure `assets/alarm.mp3` exists
- Check app notification permissions
- Verify "Do Not Disturb" is off
- Check app volume settings

### Token Refresh Fails

- Check internet connection
- Verify OAuth credentials are valid
- Check if user revoked permissions
- Try signing out and back in

## Production Deployment

### 1. Generate Release Keys

```bash
keytool -genkey -v -keystore ~/gmail-alarm-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias gmail-alarm
```

### 2. Configure Signing

Create `android/key.properties`:

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=gmail-alarm
storeFile=/path/to/gmail-alarm-release.jks
```

Update `android/app/build.gradle`:

```gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile file(keystoreProperties['storeFile'])
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

### 3. Build Release APK

```bash
flutter build apk --release
flutter build appbundle --release  # For Play Store
```

### 4. Update OAuth Credentials

Generate SHA-1 for release key:

```bash
keytool -list -v -keystore ~/gmail-alarm-release.jks -alias gmail-alarm
```

Add this SHA-1 to Google Cloud Console OAuth credentials.

## Support

For issues or questions:
1. Check the logs: `adb logcat | grep -E "GMAIL|ALARM|TOKEN|SERVICE"`
2. Review ARCHITECTURE.md for design details
3. Check GitHub issues
