# TikTok Integration — Backend Blueprint

## Overview

This document specifies the backend API structure required by the Flutter frontend for TikTok account linking, profile display, and video listing.

**Frontend App:** iBink.me Seller (Flutter)  
**Backend:** Laravel API at `https://ibink.me/api`  
**TikTok API Base:** `https://open.tiktokapis.com/v2/`

---

## Authentication

All endpoints require Laravel Sanctum Bearer token via `Authorization: Bearer {token}` header.

---

## Endpoints

### 1. Get TikTok OAuth URL

**Purpose:** Generate the TikTok authorization URL for the user to login.

```
GET /api/tiktok/auth/url
```

**Headers:**
```
Authorization: Bearer {user_token}
Accept: application/json
```

**Response (200):**
```json
{
  "url": "https://www.tiktok.com/v2/auth/authorize/?client_key=xxx&scope=user.info.basic,user.info.profile,user.info.stats,video.list&response_type=code&redirect_uri=https://ibink.me/api/auth/callback/tiktok&state=random_state_string"
}
```

**Logic:**
- Generate a random `state` string (40 chars)
- Store `state` in cache keyed by `tiktok_state_{user_id}` with 10 minute TTL
- Build the TikTok OAuth URL with:
  - `client_key` from config
  - `scope`: `user.info.basic,user.info.profile,user.info.stats,video.list`
  - `response_type`: `code`
  - `redirect_uri`: from config
  - `state`: the generated state

---

### 2. Handle TikTok OAuth Callback

**Purpose:** Exchange authorization code for access token and store connection.

```
POST /api/tiktok/callback
```

**Headers:**
```
Authorization: Bearer {user_token}
Content-Type: application/json
Accept: application/json
```

**Request Body:**
```json
{
  "code": "authorization_code_from_tiktok",
  "state": "random_state_string"
}
```

**Response (200):**
```json
{
  "success": true
}
```

**Response (400):**
```json
{
  "error": "Invalid state parameter"
}
```

**Logic:**
1. Validate `state` matches cached value for this user
2. Exchange `code` for tokens via TikTok OAuth:
   ```
   POST https://open.tiktokapis.com/v2/oauth/token/
   Content-Type: application/x-www-form-urlencoded
   
   client_key={client_key}&client_secret={client_secret}&code={code}&grant_type=authorization_code&redirect_uri={redirect_uri}
   ```
3. Extract from response:
   - `data.open_id`
   - `data.access_token`
   - `data.refresh_token`
   - `data.expires_in` (seconds)
4. Store in `tiktok_connections` table:
   - Upsert by `user_id`
   - Store all tokens and `token_expires_at = now() + expires_in`
5. Fetch user profile from TikTok (see Sync Profile below)
6. Return success

---

### 3. Get TikTok Profile

**Purpose:** Return the stored TikTok profile data for the authenticated user.

```
GET /api/tiktok/profile
```

**Headers:**
```
Authorization: Bearer {user_token}
Accept: application/json
```

**Response (200) — Connected:**
```json
{
  "connected": true,
  "profile": {
    "display_name": "Shop Name",
    "username": "shopname",
    "avatar_url": "https://...",
    "bio_description": "Quality products from Tanzania",
    "is_verified": false,
    "follower_count": 1250,
    "following_count": 340,
    "likes_count": 8900,
    "video_count": 45
  }
}
```

**Response (200) — Not Connected:**
```json
{
  "connected": false
}
```

**Logic:**
1. Look up `tiktok_connections` by `user_id`
2. If not found, return `connected: false`
3. If found but `last_synced_at` is older than 24 hours:
   - Refresh the token (see Token Refresh below)
   - Re-sync profile from TikTok API
4. Return stored profile data

---

### 4. Sync TikTok Profile

**Purpose:** Force refresh profile data from TikTok API.

```
POST /api/tiktok/sync
```

**Headers:**
```
Authorization: Bearer {user_token}
Content-Type: application/json
Accept: application/json
```

**Request Body:**
```json
{}
```

**Response (200):**
```json
{
  "success": true,
  "profile": {
    "display_name": "Shop Name",
    "username": "shopname",
    "avatar_url": "https://...",
    "bio_description": "Quality products from Tanzania",
    "is_verified": false,
    "follower_count": 1250,
    "following_count": 340,
    "likes_count": 8900,
    "video_count": 45
  }
}
```

**Logic:**
1. Look up `tiktok_connections` by `user_id`
2. Refresh token if needed
3. Call TikTok API:
   ```
   GET https://open.tiktokapis.com/v2/user/info/?fields=open_id,display_name,username,avatar_url,bio_description,is_verified,follower_count,following_count,likes_count,video_count
   Authorization: Bearer {access_token}
   ```
4. Update `tiktok_connections` with fresh data
5. Update `last_synced_at` to now
6. Return updated profile

---

### 5. Get TikTok Videos

**Purpose:** Fetch the user's recent TikTok videos.

```
GET /api/tiktok/videos
```

**Headers:**
```
Authorization: Bearer {user_token}
Accept: application/json
```

**Response (200):**
```json
{
  "data": {
    "videos": [
      {
        "id": "7077642457847994444",
        "title": "Product showcase #tanzania",
        "video_description": "Check out our new products",
        "cover_image_url": "https://...",
        "embed_link": "https://www.tiktok.com/embed/v2/7077642457847994444",
        "duration": 30,
        "create_time": 1690000000
      }
    ]
  }
}
```

**Logic:**
1. Look up `tiktok_connections` by `user_id`
2. Refresh token if needed
3. Call TikTok API:
   ```
   POST https://open.tiktokapis.com/v2/video/list/
   Authorization: Bearer {access_token}
   Content-Type: application/json
   
   {
     "max_count": 20
   }
   ```
4. Return videos list

---

### 6. Disconnect TikTok

**Purpose:** Remove TikTok connection and revoke tokens.

```
POST /api/tiktok/disconnect
```

**Headers:**
```
Authorization: Bearer {user_token}
Content-Type: application/json
Accept: application/json
```

**Request Body:**
```json
{}
```

**Response (200):**
```json
{
  "success": true
}
```

**Logic:**
1. Look up `tiktok_connections` by `user_id`
2. If found:
   - Revoke token via TikTok API:
     ```
     POST https://open.tiktokapis.com/v2/oauth/revoke/
     Content-Type: application/x-www-form-urlencoded
     
     client_key={client_key}&client_secret={client_secret}&token={access_token}
     ```
   - Delete record from `tiktok_connections`
3. Return success

---

## Token Refresh Logic

Implement as a reusable method:

```php
private function refreshTokenIfNeeded(TikTokConnection $connection)
{
    if ($connection->token_expires_at->isFuture()) {
        return;
    }
    
    $response = Http::asForm()->post('https://open.tiktokapis.com/v2/oauth/token/', [
        'client_key' => config('services.tiktok.client_key'),
        'client_secret' => config('services.tiktok.client_secret'),
        'grant_type' => 'refresh_token',
        'refresh_token' => $connection->refresh_token,
    ]);
    
    $data = $response->json()['data'];
    
    $connection->update([
        'access_token' => $data['access_token'],
        'refresh_token' => $data['refresh_token'],
        'token_expires_at' => now()->addSeconds($data['expires_in']),
    ]);
}
```

---

## Database Schema

### Table: `tiktok_connections`

```php
Schema::create('tiktok_connections', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->onDelete('cascade');
    $table->string('tiktok_open_id')->unique();
    $table->text('access_token');
    $table->text('refresh_token');
    $table->timestamp('token_expires_at');
    $table->string('display_name')->nullable();
    $table->string('username')->nullable();
    $table->text('avatar_url')->nullable();
    $table->text('bio_description')->nullable();
    $table->boolean('is_verified')->default(false);
    $table->bigInteger('follower_count')->default(0);
    $table->bigInteger('following_count')->default(0);
    $table->bigInteger('likes_count')->default(0);
    $table->bigInteger('video_count')->default(0);
    $table->timestamp('last_synced_at')->nullable();
    $table->timestamps();
    
    $table->index('user_id');
});
```

---

## Configuration

### `.env`

```env
TIKTOK_CLIENT_KEY=your_client_key
TIKTOK_CLIENT_SECRET=your_client_secret
TIKTOK_REDIRECT_URI=https://ibink.me/api/auth/callback/tiktok
```

### `config/services.php`

```php
'tiktok' => [
    'client_key' => env('TIKTOK_CLIENT_KEY'),
    'client_secret' => env('TIKTOK_CLIENT_SECRET'),
    'redirect_uri' => env('TIKTOK_REDIRECT_URI', 'https://ibink.me/api/auth/callback/tiktok'),
],
```

---

## Routes Registration

### `routes/api.php`

```php
use App\Http\Controllers\TikTokController;

Route::middleware('auth:sanctum')->group(function () {
    Route::get('/tiktok/auth/url', [TikTokController::class, 'getAuthUrl']);
    Route::post('/tiktok/callback', [TikTokController::class, 'handleCallback']);
    Route::get('/tiktok/profile', [TikTokController::class, 'getProfile']);
    Route::post('/tiktok/sync', [TikTokController::class, 'syncProfile']);
    Route::get('/tiktok/videos', [TikTokController::class, 'getVideos']);
    Route::post('/tiktok/disconnect', [TikTokController::class, 'disconnect']);
});
```

---

## Flutter Frontend Integration

### API Endpoints Used (in `api_config.dart`)

```dart
static const String tiktokAuthUrlEndpoint = '/tiktok/auth/url';
static const String tiktokCallbackEndpoint = '/tiktok/callback';
static const String tiktokProfileEndpoint = '/tiktok/profile';
static const String tiktokVideosEndpoint = '/tiktok/videos';
static const String tiktokDisconnectEndpoint = '/tiktok/disconnect';
static const String tiktokSyncEndpoint = '/tiktok/sync';
```

### Data Models (in `tiktok_model.dart`)

**TikTokProfile:**
```dart
class TikTokProfile {
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final String? bioDescription;
  final bool isVerified;
  final int followerCount;
  final int followingCount;
  final int likesCount;
  final int videoCount;
}
```

**TikTokVideo:**
```dart
class TikTokVideo {
  final String id;
  final String? title;
  final String? description;
  final String? coverImageUrl;
  final String? embedLink;
  final int? duration;
  final DateTime? createdAt;
}
```

### OAuth Flow (Flutter → Backend → TikTok)

```
1. User taps "TikTok" in profile
2. Flutter calls GET /api/tiktok/auth/url
3. Backend returns TikTok OAuth URL
4. Flutter opens URL in in-app browser (WebView)
5. User authorizes on TikTok
6. TikTok redirects to https://ibink.me/api/auth/callback/tiktok?code=xxx&state=yyy
7. Backend handles callback:
   a. Validates state
   b. Exchanges code for tokens
   c. Fetches profile from TikTok
   d. Stores in database
   e. Redirects to ibink://tiktok/callback?code=xxx&state=yyy (deep link)
8. Flutter catches deep link, calls POST /api/tiktok/callback
9. Backend returns success
10. Flutter refreshes profile data
```

---

## Error Responses

All error responses follow this format:

```json
{
  "error": "Error message in Swahili or English"
}
```

Common errors:
- `Invalid state parameter` — State mismatch or expired
- `Token exchange failed` — TikTok rejected the authorization code
- `Not connected` — User has no TikTok connection
- `Failed to refresh token` — TikTok refresh token is invalid/expired
- `API rate limit exceeded` — Too many requests to TikTok API

---

## TikTok API Scopes Required

| Scope | Description |
|-------|-------------|
| `user.info.basic` | Read profile info (open_id, avatar, display_name) |
| `user.info.profile` | Read bio, profile links, verification status |
| `user.info.stats` | Read follower/following/likes/video counts |
| `video.list` | Read user's public videos |

---

## Notes

1. **Token Security:** Tokens are stored server-side only. Flutter never sees raw TikTok tokens.
2. **Auto-Refresh:** Backend automatically refreshes tokens before they expire (24h lifetime).
3. **State Validation:** OAuth state is cached for 10 minutes to prevent CSRF.
4. **Profile Caching:** Profile is synced from TikTok at most once every 24 hours.
5. **Disconnect:** Disconnecting revokes the TikTok token and deletes the database record.
