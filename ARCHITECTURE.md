# Gmail Alarm V2 - Architecture Document

## Design Philosophy

**Built to Never Fail**

Every component is designed with these principles:
1. **Assume everything will fail** - Plan for it
2. **Fail gracefully** - Degrade, don't crash
3. **Self-heal** - Automatic recovery
4. **Observable** - Know what's happening
5. **Simple** - Easy to debug and maintain

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         USER INTERFACE                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Login Screen │  │ Home Screen  │  │ Alarm Banner │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      STATE MANAGEMENT                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Auth Manager │  │ Alarm State  │  │ Service State│      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      SERVICE LAYER                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │Token Manager │  │Service Manager│  │Alarm Manager │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   BACKGROUND WORKER                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Scan Engine  │  │  Watchdog    │  │Health Monitor│      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      EXTERNAL APIs                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Gmail API   │  │  Firebase    │  │Notifications │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Token Manager
**Purpose:** Manage Google OAuth tokens with zero-downtime refresh

**Responsibilities:**
- Proactive token refresh (45 min, expires at 60)
- Detect expired tokens
- Handle refresh failures with retry
- Detect permanent failures (revoked permissions)
- Notify user when re-auth needed

**Key Features:**
- Refresh 15 minutes BEFORE expiry (not after)
- Exponential backoff on failures
- Max 10 retry attempts
- Cache token in memory for fast access
- Persist timestamp in SharedPreferences

**Error Handling:**
- Network timeout → Retry
- Invalid grant → Clear cache, notify user
- Rate limit → Exponential backoff
- Server error → Retry with backoff

### 2. Service Manager
**Purpose:** Manage background service lifecycle

**Responsibilities:**
- Start/stop background service
- Monitor service health
- Restart on failure
- Clean shutdown
- Resource cleanup

**Key Features:**
- Atomic start/stop operations
- Idempotent (safe to call multiple times)
- Graceful shutdown (cancel timers, save state)
- Auto-restart with backoff
- Max 5 restart attempts per hour

**Error Handling:**
- Service crash → Auto-restart with delay
- Restart storm → Stop after 5 attempts
- Low memory → Reduce scan frequency
- Battery optimization → Notify user

### 3. Scan Engine
**Purpose:** Fetch emails from Gmail and trigger alarms

**Responsibilities:**
- Fetch unread emails matching criteria
- Deduplicate emails (seen tracking)
- Keyword matching
- Trigger alarms for matches
- Track dismissed emails

**Key Features:**
- Incremental scanning (only new since last scan)
- Efficient deduplication with LRU cache
- Case-insensitive keyword matching
- Atomic alarm triggering
- Idempotent (safe to retry)

**Error Handling:**
- Network offline → Pause scanning
- API error → Retry with backoff
- Rate limit → Exponential backoff
- No emails → Normal, continue

### 4. Alarm Manager
**Purpose:** Trigger and manage alarms

**Responsibilities:**
- Play alarm sound (looping)
- Show notification
- Handle dismiss action
- Persist alarm state
- Clean up audio resources

**Key Features:**
- Single alarm instance (no duplicates)
- Persistent dismiss state
- Proper audio cleanup
- Works when app is closed
- Survives device reboot

**Error Handling:**
- Audio playback fail → Show notification only
- Notification fail → Try alarm sound only
- Both fail → Log error, mark as triggered

### 5. Watchdog
**Purpose:** Monitor service health and auto-recover

**Responsibilities:**
- Check service heartbeat
- Detect dead service
- Restart unresponsive service
- Prevent restart storms
- Log health metrics

**Key Features:**
- Check every 30 seconds
- 5-minute timeout for dead service
- Exponential backoff on restarts
- Max 5 restarts per hour
- Stop after 10 consecutive failures

**Error Handling:**
- Restart fails → Wait longer, try again
- Restart storm → Stop attempting, notify user
- Watchdog crash → Service continues (fail-safe)

### 6. Health Monitor
**Purpose:** Track service health and emit metrics

**Responsibilities:**
- Heartbeat every minute
- Track uptime
- Count successful/failed scans
- Track token refresh events
- Persist health metrics

**Key Features:**
- Lightweight (minimal overhead)
- Runs in background thread
- Atomic writes to SharedPreferences
- Survives service restarts

**Error Handling:**
- Metric write fails → Log, continue
- SharedPreferences corrupted → Reset metrics

## Data Flow

### Alarm Trigger Flow
```
1. Scan Engine fetches emails
2. Filter: Remove seen emails
3. Filter: Remove dismissed emails
4. Match: Check keywords
5. If match → Trigger alarm
6. Alarm Manager plays sound
7. Show notification
8. Update state (alarmRinging = true)
9. UI detects state change
10. Show dismiss button
```

### Dismiss Flow
```
1. User taps dismiss button
2. Alarm Manager stops sound
3. Cancel notification
4. Mark emails as dismissed
5. Persist dismissed IDs
6. Update state (alarmRinging = false)
7. UI hides dismiss button
```

### Token Refresh Flow
```
1. Scan Engine checks token age
2. If >45 min → Request refresh
3. Token Manager attempts refresh
4. If success → Update timestamp
5. If fail → Retry with backoff
6. If 10 failures → Notify user
7. Continue with old token (may fail)
```

### Service Recovery Flow
```
1. Watchdog checks heartbeat
2. If >5 min old → Service is dead
3. Count consecutive restarts
4. If <5 restarts → Attempt restart
5. Wait 2^N seconds (exponential backoff)
6. Start service
7. If success → Reset counter
8. If fail → Increment counter, try again
9. If >5 restarts → Stop, notify user
```

## Persistence

### SharedPreferences Keys
```
kAlarmEnabled: bool         // Alarm ON/OFF state
kScanInterval: int          // Minutes between scans
kKeywords: List<String>     // Keywords to match
kLastScanTime: String       // ISO timestamp
kSeenIds: List<String>      // email_id|timestamp pairs
kDismissedIds: List<String> // Dismissed email IDs
kAlarmRinging: bool         // Is alarm currently ringing
kServiceRunning: bool       // Is service alive
kLastHealthCheck: String    // ISO timestamp
kTokenTimestamp: String     // ISO timestamp of last refresh
kRestartCount: int          // Consecutive restart count
kTotalScans: int           // Total scans since install
kFailedScans: int          // Failed scans count
kTokenRefreshes: int       // Token refresh count
```

### Data Cleanup
- Seen IDs: Remove entries >2 hours old
- Dismissed IDs: Keep forever (user dismissed)
- Health metrics: Reset weekly

## Threading Model

### Main Thread (UI)
- Render UI
- Handle user input
- Read state from SharedPreferences (fast)
- Trigger service actions (async)

### Background Isolate (Service)
- Run scan engine
- Refresh tokens
- Write to SharedPreferences
- Trigger alarms

### Watchdog Thread (UI)
- Check service health
- Restart service if needed
- Runs independently of service

## Error Recovery Matrix

| Error Type | Retry? | Backoff? | Max Retries | User Notify? |
|------------|--------|----------|-------------|--------------|
| Network timeout | Yes | Yes | 10 | No |
| Token expired | Yes | No | 1 | No |
| Token revoked | No | N/A | 0 | Yes |
| Rate limit | Yes | Yes | 10 | No |
| Service crash | Yes | Yes | 5 | After 5 |
| API disabled | No | N/A | 0 | Yes |
| Permissions denied | No | N/A | 0 | Yes |
| Low memory | Degrade | N/A | N/A | No |

## Performance Targets

- **App startup:** <3 seconds
- **Service start:** <2 seconds
- **Email scan:** <5 seconds
- **Alarm trigger:** <1 second
- **Token refresh:** <3 seconds
- **Memory usage:** <50MB
- **Battery drain:** <2% per 8 hours

## Testing Strategy

### Unit Tests
- Token Manager refresh logic
- Scan Engine filtering
- Alarm Manager state transitions
- Watchdog restart logic

### Integration Tests
- End-to-end alarm flow
- Service lifecycle
- Token refresh during scan
- Recovery from crashes

### Manual Tests
- 8-hour runtime test
- Network offline/online
- Kill service, verify restart
- Revoke permissions
- Battery optimization enabled

## Logging Strategy

All logs use structured format:
```
[LEVEL] [COMPONENT] [ACTION] Message (key=value, ...)
```

Example:
```
[INFO] [TOKEN] [REFRESH] Token refreshed successfully (age=52min, attempt=1)
[WARN] [SERVICE] [RESTART] Service restarted (reason=crash, attempt=3/5)
[ERROR] [SCAN] [FAILED] Gmail API error (code=429, retry_in=60s)
```

Levels:
- DEBUG: Development only
- INFO: Normal operations
- WARN: Handled errors
- ERROR: Failures requiring attention

## Security

- Tokens stored in SharedPreferences (Android encrypted storage)
- No tokens in logs
- No PII in logs
- Minimal permissions (Gmail read-only)

## Scalability

Current design supports:
- 1000+ keywords
- 10,000+ emails tracked
- 24/7 operation
- Multiple alarms per scan

Future improvements:
- Local email caching
- ML-based keyword matching
- Multiple Gmail accounts
- Cross-device sync

---

This architecture ensures the app will run reliably for weeks without crashes.
