# Gmail Alarm V2 - Testing Guide

## Overview

This guide covers comprehensive testing of the Gmail Alarm app to ensure production-ready reliability.

## Test Mode

### Enabling Test Mode

1. Launch the app
2. Sign in with Google
3. Tap the bug report icon (🐛) in the top-right corner
4. Test mode is now enabled

### What Test Mode Does

- **Token Expiry**: Reduces token expiry from 60 minutes to 10 seconds
- **Token Refresh Threshold**: Changes from 45 minutes to 7 seconds
- This allows testing token refresh without waiting

### Testing Token Refresh

1. Enable test mode
2. Enable alarm and start service
3. Watch the logs for `[TOKEN] [REFRESH]` messages
4. Should see token refresh within 10 seconds
5. Verify no errors or crashes

## Manual Test Cases

### 1. Authentication Flow

#### Test: Initial Sign-In
**Steps:**
1. Launch app (not signed in)
2. Tap "Sign in with Google"
3. Select Google account
4. Grant Gmail permissions

**Expected:**
- Sign-in succeeds
- Home screen displays user info
- No errors

#### Test: Sign-Out
**Steps:**
1. Sign in
2. Tap menu > Sign out
3. Confirm sign-out

**Expected:**
- Returns to login screen
- Background service stops
- No crashes

#### Test: Persistent Sign-In
**Steps:**
1. Sign in
2. Close app completely
3. Reopen app

**Expected:**
- User still signed in
- No need to sign in again

### 2. Alarm Configuration

#### Test: Add Keywords
**Steps:**
1. Sign in
2. Enter keyword "urgent"
3. Tap Add
4. Add more keywords: "important", "alert"

**Expected:**
- Keywords appear in list
- Saved to storage
- No duplicates

#### Test: Remove Keywords
**Steps:**
1. Add several keywords
2. Tap delete on one keyword
3. Confirm deletion

**Expected:**
- Keyword removed from list
- Persists after app restart

#### Test: Scan Interval
**Steps:**
1. Adjust scan interval slider
2. Try minimum (1 min)
3. Try maximum (60 min)
4. Set to 5 min

**Expected:**
- Value updates immediately
- Saved to storage
- Service uses new interval

#### Test: Enable/Disable Alarm
**Steps:**
1. Toggle alarm switch ON
2. Toggle alarm switch OFF

**Expected:**
- State persists after restart
- Service starts when enabled
- Service stops when disabled

### 3. Background Service

#### Test: Start Service
**Steps:**
1. Enable alarm
2. Tap "Start Service"
3. Wait 10 seconds

**Expected:**
- Service status shows "Running"
- Health check updates every minute
- No crashes

#### Test: Service Persistence
**Steps:**
1. Start service
2. Close app (swipe away)
3. Wait 5 minutes
4. Reopen app

**Expected:**
- Service still running
- Health check recent (<2 min old)
- No restarts

#### Test: Service After Reboot
**Steps:**
1. Start service
2. Reboot device
3. Wait 2 minutes
4. Open app

**Expected:**
- Service auto-starts
- Health check recent
- Alarm state preserved

#### Test: Stop Service
**Steps:**
1. Start service
2. Tap "Stop Service"
3. Confirm

**Expected:**
- Service status shows "Stopped"
- Health check stops updating
- No crashes

### 4. Email Scanning

#### Test: Keyword Match
**Steps:**
1. Add keyword "testword123"
2. Enable alarm
3. Start service
4. Send email to yourself with subject "testword123"
5. Wait for scan interval

**Expected:**
- Alarm triggers within scan interval
- Notification appears
- Alarm sound plays
- Alarm banner shows in app

#### Test: No Match
**Steps:**
1. Add keyword "urgenttest"
2. Enable alarm
3. Start service
4. Send email without keyword
5. Wait for scan interval

**Expected:**
- No alarm triggers
- No notification
- Service continues running

#### Test: Multiple Matches
**Steps:**
1. Add keywords "test1", "test2"
2. Enable alarm
3. Send 3 emails matching keywords
4. Wait for scan

**Expected:**
- Alarm triggers once
- Shows match count
- All matches logged

#### Test: Dismiss Alarm
**Steps:**
1. Trigger alarm
2. Open app
3. Tap "DISMISS ALARM"

**Expected:**
- Alarm stops
- Notification dismissed
- Emails marked as dismissed
- Won't trigger again for same emails

### 5. Token Management

#### Test: Proactive Refresh (Test Mode)
**Steps:**
1. Enable test mode
2. Sign in
3. Enable alarm, start service
4. Watch logs for 15 seconds

**Expected:**
- Token refreshes before expiry
- `[TOKEN] [REFRESH]` in logs at ~7 seconds
- No errors
- Service continues running

#### Test: Token Refresh Failure Retry
**Steps:**
1. Enable test mode
2. Disconnect internet
3. Wait for token refresh attempt
4. Reconnect internet

**Expected:**
- Retries with exponential backoff
- Eventually succeeds when online
- Service doesn't crash

#### Test: Max Refresh Retries
**Steps:**
1. Enable test mode
2. Revoke app permissions in Google account
3. Wait for token refresh attempts

**Expected:**
- After 10 failures, stops retrying
- User notified to re-authenticate
- No crashes

### 6. Watchdog Recovery

#### Test: Service Crash Recovery
**Steps:**
1. Start service
2. Force stop app: Settings > Apps > Gmail Alarm > Force Stop
3. Wait 6 minutes
4. Reopen app

**Expected:**
- Watchdog detects dead service
- Auto-restarts service
- Health check resumes
- Restart count incremented

#### Test: Multiple Restart Limit
**Steps:**
1. Repeatedly force stop (5+ times)
2. Check restart count

**Expected:**
- After 5 restarts, stops attempting
- User notified
- No infinite restart loop

### 7. Edge Cases

#### Test: Network Offline
**Steps:**
1. Start service
2. Enable airplane mode
3. Wait through scan interval
4. Disable airplane mode

**Expected:**
- Scans fail gracefully
- Service continues running
- Resumes when online
- No crashes

#### Test: Low Battery
**Steps:**
1. Let device reach low battery (<15%)
2. Check service status

**Expected:**
- Service continues (may slow down)
- No crashes
- Resumes normally when charged

#### Test: Battery Optimization
**Steps:**
1. Enable battery optimization for app
2. Start service
3. Lock device for 1 hour

**Expected:**
- Service may be killed
- Watchdog restarts it
- Or user notified to disable optimization

#### Test: Multiple Alarm Instances
**Steps:**
1. Trigger alarm
2. Before dismissing, trigger again

**Expected:**
- Only one alarm instance
- No duplicate sounds
- Dismiss stops all

### 8. Long-Running Test

#### Test: 8-Hour Stability
**Steps:**
1. Enable alarm with keywords
2. Start service
3. Set scan interval to 5 minutes
4. Leave running for 8 hours
5. Check periodically

**Expected:**
- Service runs entire duration
- No crashes
- Memory usage stable (<50MB)
- Token refreshes successfully
- Health checks regular

**Monitor:**
- Check logs every hour
- Verify health check timestamps
- Watch for memory leaks
- Check CPU usage

## Automated Testing

### Run Unit Tests

```bash
flutter test
```

### Run Integration Tests

```bash
flutter test integration_test/
```

## Log Monitoring

### View Live Logs

```bash
# Android
adb logcat | grep -E "\[INFO\]|\[WARN\]|\[ERROR\]"

# iOS
idevicesyslog | grep -E "\[INFO\]|\[WARN\]|\[ERROR\]"
```

### Key Log Messages

- `[TOKEN] [REFRESH] Token refreshed successfully` - Token refresh worked
- `[SCAN] [SCAN] Scan completed` - Email scan finished
- `[ALARM] [TRIGGER] Alarm triggered successfully` - Alarm triggered
- `[HEALTH] [HEARTBEAT] Heartbeat emitted` - Service alive
- `[WATCHDOG] [RESTART] Service restarted` - Watchdog recovery

### Error Indicators

- `[ERROR]` - Critical errors
- `[WARN]` - Warnings (may indicate issues)
- `Max retry attempts exceeded` - Needs attention
- `Service appears dead` - Watchdog triggered

## Performance Metrics

### Target Metrics
- **App startup**: <3 seconds
- **Service start**: <2 seconds
- **Email scan**: <5 seconds
- **Alarm trigger**: <1 second
- **Token refresh**: <3 seconds
- **Memory usage**: <50MB
- **Battery drain**: <2% per 8 hours

### Measure Performance

```bash
# Memory usage
adb shell dumpsys meminfo com.example.gmail_alarm

# CPU usage
adb shell top | grep gmail_alarm

# Battery stats
adb shell dumpsys batterystats --reset
# ... use app for a while ...
adb shell dumpsys batterystats com.example.gmail_alarm
```

## Test Environment Setup

### Test Gmail Account

1. Create a dedicated Gmail account for testing
2. Don't use personal account
3. Send test emails to this account

### Test Devices

Test on multiple devices:
- Android 10+ (various manufacturers)
- Different screen sizes
- Low-end and high-end devices
- iOS 13+ (if applicable)

## Regression Testing

Before each release:
1. Run all manual test cases
2. Run automated tests
3. Perform 8-hour stability test
4. Test on multiple devices
5. Review all logs for errors
6. Check performance metrics

## Reporting Issues

When reporting bugs, include:
1. Device model and Android version
2. Steps to reproduce
3. Expected vs actual behavior
4. Logs (filter by error level)
5. Screenshots/screen recording
6. App version

## Success Criteria

The app is production-ready when:
- ✓ All manual tests pass
- ✓ 8-hour stability test passes
- ✓ No crashes or memory leaks
- ✓ Token refresh works reliably
- ✓ Service survives device reboot
- ✓ Watchdog recovers from failures
- ✓ Performance metrics met
- ✓ Battery drain acceptable
