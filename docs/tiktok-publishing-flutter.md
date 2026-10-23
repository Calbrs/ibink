# TikTok Publishing — Flutter Integration Guide

**Version:** 1.0
**Date:** 2026-10-09
**Backend base:** `https://api.zumimo.com`
**Status:** ✅ Backend live and tested

---

## 1. Overview

The Zumimo Seller app supports **two ways** to send a video to TikTok:

| Mode | Endpoint | Behavior | Sandbox OK? |
|---|---|---|---|
| **Draft** | `POST /tiktok/publish/draft` | Video goes to TikTok inbox — user finishes on TikTok app | ✅ Yes |
| **Direct** | `POST /tiktok/publish/direct` | Video posts directly to the user's profile | ⚠️ `SELF_ONLY` only in sandbox |

The user chooses which mode to use from a **single screen** with a mode toggle.

**After a successful Direct post**, the app must **poll status** until `PUBLISH_COMPLETE` — this is where the app learns the video is live and gets the URL.

---

## 2. User Flow

```
User picks a video
        ↓
   ┌──────────────────┐
   │  Choose mode:    │
   │  ● Draft         │
   │  ○ Direct        │
   └──────────────────┘
        ↓
   ┌──────────────────────────────────────┐
   │ If Draft:                            │
   │   → Upload → Success → "Open TikTok" │
   └──────────────────────────────────────┘

   ┌──────────────────────────────────────┐
   │ If Direct:                           │
   │   → Load creator info                │
   │   → Show form:                       │
   │     • Caption                        │
   │     • Privacy dropdown               │
   │     • Comment / Duet / Stitch        │
   │   → Upload → Poll status             │
   │   → Success → "View on TikTok"       │
   └──────────────────────────────────────┘
```

---

## 3. Backend Endpoints

### 3.1 Get Creator Info (required before Direct Post)

```http
GET /tiktok/publish/creator-info
Authorization: Bearer <sanctum_token>
Accept: application/json
```

**Response (200):**
```json
{
  "success": true,
  "creator": {
    "creator_avatar_url": "https://...",
    "creator_username": "calbrs_dev",
    "creator_nickname": "Calbrs Dev",
    "privacy_level_options": [
      "PUBLIC_TO_EVERYONE",
      "MUTUAL_FOLLOW_FRIERS",
      "SELF_ONLY"
    ],
    "comment_disabled": false,
    "duet_disabled": false,
    "stitch_disabled": false,
    "max_video_post_duration_sec": 3600
  }
}
```

**UI Rules (TikTok requires these):**
- Show `creator_avatar_url`, `creator_username`, `creator_nickname` at top of Direct Post screen
- Build the privacy dropdown from `privacy_level_options` — **do not hardcode options**
- **Do not pre-select any privacy option** — user must choose
- Disable Comment toggle if `comment_disabled == true`
- Disable Duet toggle if `duet_disabled == true`
- Disable Stitch toggle if `stitch_disabled == true`
- Reject videos longer than `max_video_post_duration_sec` before upload

### 3.2 Draft Upload

```http
POST /tiktok/publish/draft
Authorization: Bearer <sanctum_token>
Content-Type: multipart/form-data
```

**Body:**
| Field | Type | Required | Value |
|---|---|---|---|
| `video` | File | ✅ | MP4 / MOV / WebM, max 1GB |

**Success (200):**
```json
{
  "success": true,
  "publish_id": "v_inbox_file~v2.xxx",
  "message": "Video imetumwa TikTok. Fungua TikTok app kumalizia."
}
```

**No status polling needed** — the draft is immediately visible in the user's TikTok inbox.

### 3.3 Direct Post

```http
POST /tiktok/publish/direct
Authorization: Bearer <sanctum_token>
Content-Type: multipart/form-data
```

**Body:**
| Field | Type | Required | Notes |
|---|---|---|---|
| `video` | File | ✅ | MP4 / MOV / WebM, max 1GB |
| `title` | String | ❌ | Caption. Max 2200 chars. Hashtags allowed |
| `privacy_level` | String | ✅ | One of: `PUBLIC_TO_EVERYONE`, `MUTUAL_FOLLOW_FRIERS`, `FOLLOWER_OF_CREATOR`, `SELF_ONLY` |
| `disable_duet` | Bool | ❌ | Default `false` |
| `disable_comment` | Bool | ❌ | Default `false` |
| `disable_stitch` | Bool | ❌ | Default `false` |
| `video_cover_timestamp_ms` | Int | ❌ | Default `0` (first frame) |
| `brand_content_toggle` | Bool | ❌ | Default `false` |
| `brand_organic_toggle` | Bool | ❌ | Default `false` |
| `is_aigc` | Bool | ❌ | Default `false`. `true` if video was AI-generated |

**Success (200):**
```json
{
  "success": true,
  "publish_id": "v_pub_file~v2-1.xxx",
  "message": "Video inachapishwa. Angalia hali kwa publish_id."
}
```

**IMPORTANT:** The `publish_id` is NOT the final video. You must poll status to know when the video is live.

**Error (400) — Sandbox restriction:**
```json
{
  "error": "Imeshindwa kuanzisha direct post.",
  "details": {
    "code": "unaudited_client_can_only_post_to_private_accounts",
    "message": "Please review our integration guidelines..."
  }
}
```

Handle this by informing the user:
> "Kwa sasa unaweza kupost private pekee. Chagua 'Mimi pekee' kwenye privacy."

### 3.4 Poll Status (required after Direct Post)

Call this endpoint every **3 seconds** until `status` is `PUBLISH_COMPLETE` or `FAILED`.

```http
POST /tiktok/publish/status
Authorization: Bearer <sanctum_token>
Content-Type: application/json
```

**Body:**
```json
{ "publish_id": "v_pub_file~v2-1.xxx" }
```

**Response (200):**
```json
{
  "success": true,
  "status": "PUBLISH_COMPLETE",
  "reason": null,
  "post_id": null,
  "video_url": null,
  "profile_url": "https://www.tiktok.com/@calbrs_dev",
  "raw": { "status": "PUBLISH_COMPLETE" }
}
```

**Status values:**

| Status | Meaning | Action |
|---|---|---|
| `PROCESSING_UPLOAD` | Bytes are being uploaded | Keep polling |
| `PROCESSING_DOWNLOAD` | TikTok is transcoding | Keep polling |
| `PUBLISH_COMPLETE` | ✅ Video is live | Stop polling, show success |
| `FAILED` | Something went wrong | Stop polling, show `reason` |

**Response fields:**
- `post_id` — TikTok video ID (may be `null` in sandbox with `SELF_ONLY`)
- `video_url` — Full URL to the video (may be `null` in sandbox)
- `profile_url` — Profile URL (always present) — **use this as fallback**

**Polling rules:**
- Max 40 attempts (2 minutes)
- Interval: 3 seconds
- If still `PROCESSING_*` after 40 attempts, show timeout message

---

## 4. Backend Contract Summary

| Endpoint | Method | Purpose | Body |
|---|---|---|---|
| `/tiktok/publish/creator-info` | GET | Load privacy options + user info | — |
| `/tiktok/publish/draft` | POST | Upload as draft | `video` (file) |
| `/tiktok/publish/direct` | POST | Upload + post directly | `video`, `title`, `privacy_level`, `disable_*`, `is_aigc` |
| `/tiktok/publish/status` | POST | Poll publish state | `publish_id` |

**All requests require:** `Authorization: Bearer <sanctum_token>`

---

## 5. Platform Setup

### Android — `android/app/src/main/AndroidManifest.xml`

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
    android:maxSdkVersion="32" />

<queries>
    <package android:name="com.zhiliaoapp.musically" />
    <package android:name="com.ss.android.ugc.trill" />
</queries>
```

### iOS — `ios/Runner/Info.plist`

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>Tunahitaji access kuchagua video kwa TikTok</string>

<key>LSApplicationQueriesSchemes</key>
<array>
    <string>tiktok</string>
    <string>snssdk1233</string>
</array>
```

---

## 6. Localization (Swahili labels)

| Code | Label (Swahili) |
|---|---|
| `PUBLIC_TO_EVERYONE` | Kila mtu |
| `MUTUAL_FOLLOW_FRIERS` | Marafiki tu |
| `FOLLOWER_OF_CREATOR` | Wafuasi wangu |
| `SELF_ONLY` | Mimi pekee |

---

## 7. Error Codes Reference

| Backend Error | Cause | UX |
|---|---|---|
| `unaudited_client_can_only_post_to_private_accounts` | Sandbox restriction | Show: "Kwa sasa unaweza kupost private pekee" |
| `scope_not_authorized` | Token missing `video.publish` | Ask user to reconnect TikTok |
| `access_token_invalid` | Token expired | Ask user to reconnect TikTok |
| `rate_limit_exceeded` | Too many uploads | Show: "Subiri dakika 60" |
| `invalid_params` | Bad video format or size | Check file |
| `video_too_long` | Exceeds `max_video_post_duration_sec` | Reject before upload |
| `duration_check_failed` | Video duration out of range | Same as above |

---

## 8. Date Field — Current Posting Date

The app should display the **current date** in the UI where relevant. This is a **client-side field only** — TikTok does not accept a custom post date.

### Why

TikTok's API does not allow scheduling or backdating. The video is always posted at the moment the API call succeeds. TikTok itself shows the **actual posting timestamp** in the user's profile — based on TikTok's own server time.

### Where to Show the Current Date

**On the Direct Post screen, below the caption field**, show a small info row:

```dart
Row(
  children: [
    const Icon(Icons.schedule, size: 14, color: AppColors.inkSoft),
    const SizedBox(width: 6),
    Text(
      'Itapostiwa: ${_formatPostDate(DateTime.now())}',
      style: const TextStyle(
        fontSize: 11.5,
        color: AppColors.inkSoft,
      ),
    ),
  ],
),
```

Helper:

```dart
String _formatPostDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun',
    'Jul', 'Ago', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  final d = dt.day.toString().padLeft(2, '0');
  final m = months[dt.month - 1];
  final y = dt.year;
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  return '$d $m $y, $hh:$mm';
}
```

**Example display:** `Itapostiwa: 09 Okt 2026, 14:30`

### After Successful Post

When showing the success dialog, include the **actual completion time** (captured **after** polling returns `PUBLISH_COMPLETE`):

```dart
final postedAt = DateTime.now(); // captured right after PUBLISH_COMPLETE
```

### Important Notes

- **Do not send any date field to the backend.** TikTok sets the timestamp on its own servers.
- The date shown in the app is **informational only**.
- The real posting time visible on TikTok's profile will be **TikTok's server time**, which is usually within a few seconds of the completion message.
- If the user is in a different timezone than the device, use `DateTime.now()` (device-local).
- The backend already returns the correct publish state; **no backend date handling is required**.

---

## 9. Testing Checklist

### Draft Mode
- [ ] Pick a video
- [ ] Select "Draft" mode
- [ ] Tap "Tuma kwenye Draft"
- [ ] Expect success dialog with "Fungua TikTok"
- [ ] Open TikTok app → Inbox → draft is there

### Direct Mode — Happy Path
- [ ] Pick a video
- [ ] Select "Direct" mode
- [ ] Creator info card shows (username, avatar)
- [ ] Privacy dropdown is populated from API
- [ ] Select privacy, add caption, toggle switches
- [ ] Tap "Post kwa TikTok"
- [ ] Progress bar shows upload, then "Inachapishwa..."
- [ ] Success dialog appears with "Fungua TikTok"

### Direct Mode — Sandbox Restriction
- [ ] Select `PUBLIC_TO_EVERYONE`
- [ ] Expect error: *"Kwa sasa unaweza kupost private pekee..."*
- [ ] Retry with `SELF_ONLY` → succeeds

### Direct Mode — Validation
- [ ] Try submit without video → button disabled
- [ ] Try submit without privacy → error banner
- [ ] Try video > 1GB → backend error surfaced

### Status Polling
- [ ] `PROCESSING_UPLOAD` → `PUBLISH_COMPLETE` within 30s
- [ ] Progress shows "(attempt/max)"
- [ ] Timeout after 2 minutes → error with retry option

### App Integration
- [ ] "Fungua TikTok" opens TikTok app (or store if not installed)
- [ ] Profile URL opens in browser if video URL is null
- [ ] Back navigation returns to TikTok screen

---

## 10. Out of Scope

- **Scheduled posting** — TikTok does not support this via API
- **Custom post date** — TikTok sets the timestamp server-side
- **Editing after post** — must be done inside TikTok app
- **Post to multiple accounts** — one connection per user
- **Public posting in sandbox** — requires Content Posting Audit

---

## 11. Handoff Notes

- Backend is **fully tested** with `@calbrs_dev` account
- Draft mode works **without restrictions**
- Direct mode works but **`SELF_ONLY` only** until audit is passed
- All error responses include Swahili messages ready to display
- Status polling returns both `video_url` and `profile_url` — use `video_url` first, fall back to `profile_url`

For backend questions, contact the backend team with:
- `user_id`
- `publish_id`
- Laravel log excerpt (`storage/logs/laravel.log`)
