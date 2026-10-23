# TikTok Photo Posting — Backend Blueprint

## Overview

Photo posting for a linked TikTok account, using TikTok's **Content Posting API**
in **Direct Post** mode.

**Frontend App:** Zumimo Seller (Flutter)
**Backend:** Laravel API at `https://api.zumimo.com`
**TikTok API Base:** `https://open.tiktokapis.com/v2/`

Video posting is deliberately out of scope for this document; the endpoints
below are structured so video can be added as `media_type: VIDEO` later.

---

## Why the phone cannot call TikTok directly

The Flutter app never talks to `open.tiktokapis.com` for posting. Three
reasons, all of which require the backend:

1. **The access token is server-side.** The TikTok `access_token` lives in
   `tiktok_connections` (see `TIKTOK_BACKEND_BLUEPRINT.md`) and is never sent
   to the client. Posting requires it in an `Authorization` header.
2. **Photo posting only accepts public URLs.** The photo endpoint rejects file
   uploads outright — see [Photo constraints](#photo-constraints). TikTok fetches
   images from publicly reachable URLs on a **domain verified in the TikTok
   Developer Portal**. A phone cannot serve those.
3. **An audited `video.publish` client must keep credentials off the device.**

---

## Scopes required

The connected app currently requests:

```
user.info.basic, user.info.profile, user.info.stats, video.list
```

Posting needs one more, which is **not** yet requested:

| Scope | Purpose | Status |
|---|---|---|
| `video.publish` | Direct Post to the user's account | **Must be added + approved** |
| `video.list` | Already granted — used to read videos after posting | Granted |

Without `video.publish`, every create call fails with
`scope_not_authorized`.

### Sandboxing vs production

You can test end-to-end in **sandbox** while the app is unaudited, but with
hard limits that the app must respect:

- All posts are forced to `privacy_level: SELF_ONLY` (private to the creator).
- Up to **5 users** may post in any 24-hour window.
- Visibility restrictions are only lifted after the API client passes TikTok's
  **audit**.

The app handles this by never hardcoding privacy options — it renders whatever
`GET /tiktok/creator-info` returns, so a sandbox account simply shows one option.

---

## Endpoints

### 1. Get creator info

Called before the composer opens. TikTok requires the UI to reflect the
creator's real privacy options and live caps.

```
GET /api/tiktok/creator-info
```

**Headers**
```
Authorization: Bearer {user_token}
Accept: application/json
```

**Response (200)**
```json
{
  "success": true,
  "data": {
    "nickname": "Duka Langu",
    "avatar_url": "https://...",
    "follower_count": 1396,
    "privacy_level_options": ["SELF_ONLY"],
    "can_post": true,
    "max_video_post_duration_sec": 600,
    "quota_remaining": 5,
    "fail_reason": null,
    "max_photo_count": 10,
    "follower_count_limit_for_audio": 0
  }
}
```

**Upstream call**
```
GET https://open.tiktokapis.com/v2/creator_info/query/?fields=nickname,avatar_url,follower_count,privacy_level_options,max_video_post_duration_sec,quota_remaining
Authorization: Bearer {tiktok_access_token}
```

**Logic**

1. Look up `tiktok_connections` by `user_id`. If none, return
   `can_post: false` with `fail_reason: "TikTok haijaunganishwa"`.
2. Refresh the access token if expired (same helper as the profile endpoints).
3. Call `creator_info/query/`.
4. Map `privacy_level_options` through unchanged — **do not add or remove
   options**. TikTok rejects a `privacy_level` the account did not declare, and
   the app's UI is driven by this list.
5. `can_post` is `false` when the account is banned, out of quota, or posting is
   disabled. Surface `fail_reason` to the app.
6. `max_photo_count` is app policy, not a TikTok field — return 10 so the seller
   is not asked to upload 35 large images. TikTok's own maximum is 35.

**Failure codes from TikTok to map**

| TikTok `error.code` | HTTP | Meaning |
|---|---|---|
| `scope_not_authorized` | 403 | App lacks `video.publish` |
| `access_token_invalid` | 401 | Token dead; user must re-link |
| `creator_banned` / `user_banned` | 403 | Account cannot post |
| `too_many_pending_share` | 429 | Daily upload cap hit |

---

### 2. Host the post images

The app uploads the picked images here. The backend stores them somewhere
publicly reachable **and on a domain verified with TikTok**, then returns the
URLs. This is the step that makes `PULL_FROM_URL` possible.

```
POST /api/tiktok/posts/images
```

**Headers**
```
Authorization: Bearer {user_token}
Content-Type: multipart/form-data
Accept: application/json
```

**Request Body**

| Field | Type | Notes |
|---|---|---|
| `purpose` | string | `tiktok_post` — lets storage rules differ from product images |
| `images[]` | file[] | 1..10 files, JPEG/PNG/WebP, 20 MB each |

**Response (200)**
```json
{
  "success": true,
  "data": {
    "urls": [
      "https://ibink.me/media/tiktok/2026/10/abc123.jpg",
      "https://ibink.me/media/tiktok/2026/10/def456.jpg"
    ]
  }
}
```

**Logic**

1. Validate count and per-file size (20 MB is TikTok's limit — reject before
   uploading to TikTok to avoid a wasted round trip).
2. Re-encode if necessary. TikTok accepts **JPEG and WebP only**; convert PNG or
   oversized images rather than letting TikTok reject them later.
3. Store under a path served by a domain registered in the TikTok Developer
   Portal → *Portal → App → Domains and URLs*. **If the serving domain is not
   verified, every create call fails** with an invalid-URL error.
4. Return absolute URLs, in the same order as the uploads. **Order matters** —
   it becomes `photo_images`, and `photo_cover_index` indexes into it.
5. Do not serve these publicly without restriction forever; they are content
   about to be published.

---

### 3. Create the photo post

```
POST /api/tiktok/posts
```

**Headers**
```
Authorization: Bearer {user_token}
Content-Type: application/json
Accept: application/json
```

**Request Body**
```json
{
  "media_type": "PHOTO",
  "post_mode": "DIRECT_POST",
  "photo_images": [
    "https://ibink.me/media/tiktok/2026/10/abc123.jpg",
    "https://ibink.me/media/tiktok/2026/10/def456.jpg"
  ],
  "photo_cover_index": 0,
  "title": "Viatu vya kivimbe",
  "description": "Bei nafuu ya kila siku #viatu #tanzania",
  "privacy_level": "SELF_ONLY",
  "disable_comment": false,
  "auto_add_music": false,
  "brand_organic_toggle": true,
  "brand_content_toggle": false,
  "product_id": 42
}
```

| Field | Required | Rules |
|---|---|---|
| `media_type` | yes | `PHOTO` only. TikTok cannot mix photos and video in one post |
| `post_mode` | yes | `DIRECT_POST` |
| `photo_images` | yes | 1..35 URLs, publicly reachable, from a verified domain |
| `photo_cover_index` | yes | 0-based index into `photo_images` |
| `title` | no | Max **90** UTF-16 code units |
| `description` | no | Max **4000** UTF-16 code units |
| `privacy_level` | yes | Must be one of the account's `privacy_level_options` |
| `disable_comment` | no | Photos support comments only (no duet/stitch) |
| `auto_add_music` | no | Direct Post only |
| `brand_organic_toggle` | yes | Exactly one of the two brand toggles |
| `brand_content_toggle` | yes | `true` only for a paid partnership |
| `product_id` | no | Your own product, for attribution |

**Response (200)**
```json
{
  "success": true,
  "data": {
    "publish_id": "p_pub_url~v2.123456789"
  }
}
```

**Upstream call**
```
POST https://open.tiktokapis.com/v2/post/publish/content/init/
Authorization: Bearer {tiktok_access_token}
Content-Type: application/json; charset=UTF-8
```

**Logic**

1. Look up the connection; refresh the token if needed.
2. **Validate `privacy_level` against the live `privacy_level_options`.** An
   unaudited client that requests anything but `SELF_ONLY` is rejected — fail
   early with a clear message instead of surfacing TikTok's error.
3. Validate `title` ≤ 90 and `description` ≤ 4000. Note these are **UTF-16 code
   units**, not grapheme clusters.
4. Verify every URL in `photo_images` is on a verified domain. Reject any host
   outside the allow-list — this endpoint forwards attacker-supplied URLs to a
   trusted third party and is an SSRF vector.
5. Confirm `photo_cover_index` is within range.
6. Forward to TikTok. **Persist `publish_id` with the user_id and product_id
   before returning**, because TikTok processes asynchronously and the app polls
   endpoint 4.
7. Return `publish_id`. The post is **not** live yet.

**Rate limit:** 6 requests per minute per TikTok access token. Return `429` to
the app rather than letting it retry blindly.

---

### 4. Get post status

TikTok processes asynchronously. A successful create does **not** mean a
published post, so the app polls this.

```
GET /api/tiktok/posts/{publish_id}
```

**Response (200)**
```json
{
  "success": true,
  "data": {
    "publish_id": "p_pub_url~v2.123456789",
    "status": "PUBLISH_COMPLETE",
    "post_url": "https://www.tiktok.com/@shop/video/123456789",
    "message": null
  }
}
```

`status` is one of: `PUBLISH_PENDING`, `PROCESSING`, `PUBLISH_COMPLETE`,
`PUBLISH_FAILED`.

**Upstream call**
```
GET https://open.tiktokapis.com/v2/post/publish/status/fetch/
Authorization: Bearer {tiktok_access_token}
Content-Type: application/json; charset=UTF-8
Body: {"publish_id": "p_pub_url~v2.123456789"}
```

**Logic**

1. Confirm the `publish_id` belongs to the authenticated user before returning
   anything.
2. Cache the terminal state in your database. Once `PUBLISH_COMPLETE` or
   `PUBLISH_FAILED` is reached, stop calling TikTok — the app treats those as
   terminal and stops polling.
3. Optionally pre-fetch `post_url` via `GET /v2/video/query/` so the app can link
   straight to the published post.

**Alternative to polling:** subscribe to Content Posting API webhooks
(`post.publish.complete`, `post.publish.failed`). Prefer this in production;
keep the endpoint for reconciliation.

---

## Photo constraints

Straight from TikTok, and the reason several fields above are shaped as they
are:

| Constraint | Value |
|---|---|
| Photos per post | 1..35 (app caps at 10) |
| Formats | JPEG, WebP |
| Max size per photo | 20 MB |
| Source | `PULL_FROM_URL` **only** — file upload is not supported for photos |
| URLs | Publicly reachable, on a domain verified in the Developer Portal |
| Title | 90 UTF-16 code units |
| Description | 4000 UTF-16 code units |
| Aspect ratio | TikTok does not mix photos and video in one post |

Because only `PULL_FROM_URL` works, endpoint 2 is not optional — it is the
mechanism.

---

## Database changes

Add to the existing `tiktok_connections` table's neighbourhood:

```sql
Schema::create('tiktok_posts', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained()->onDelete('cascade');
    $table->string('publish_id', 64)->unique();
    $table->string('media_type', 16)->default('PHOTO');   // PHOTO | VIDEO later
    $table->string('status', 32)->default('PUBLISH_PENDING');
    $table->string('privacy_level', 32);
    $table->unsignedTinyInteger('photo_count')->default(0);
    $table->unsignedTinyInteger('photo_cover_index')->default(0);
    $table->text('photo_images')->nullable();   // JSON array of URLs
    $table->string('title', 255)->nullable();
    $table->text('description')->nullable();
    $table->boolean('brand_organic')->default(true);
    $table->unsignedBigInteger('product_id')->nullable();
    $table->string('post_url')->nullable();
    $table->text('error_message')->nullable();
    $table->timestamps();

    $table->index(['user_id', 'status']);
    $table->index('product_id');
});
```

Persisting this is what makes the flow auditable: when a seller asks "did my
post go up?", the answer is a row, not a guess.

---

## Routes

```php
Route::middleware('auth:sanctum')->group(function () {
    Route::get('/tiktok/creator-info',    [TikTokPostController::class, 'creatorInfo']);
    Route::post('/tiktok/posts/images',   [TikTokPostController::class, 'storeImages']);
    Route::post('/tiktok/posts',          [TikTokPostController::class, 'store']);
    Route::get('/tiktok/posts/{publishId}',[TikTokPostController::class, 'status']);
});
```

---

## Flutter integration

### Endpoints used (`api_config.dart`)

```dart
static const String tiktokCreatorInfoEndpoint = '/tiktok/creator-info';
static const String tiktokPostImagesEndpoint = '/tiktok/posts/images';
static const String tiktokPostsEndpoint = '/tiktok/posts';
static String tiktokPostStatusEndpoint(String id) => '/tiktok/posts/$id';
```

### Service (`tiktok_post_service.dart`)

| Method | Purpose |
|---|---|
| `fetchCreatorInfo()` | Live privacy options + caps; gates the composer |
| `uploadImages(paths)` | Multipart upload, returns public URLs in order |
| `createPhotoPost(...)` | Sends `media_type: PHOTO`, returns `publish_id` |
| `pollUntilSettled(id)` | Polls until terminal (5 attempts, 4s apart) |

### App-side flow

```
1. TikTok screen → "Tuma Bidhaa kwenye TikTok"
2. fetchCreatorInfo()
     → not connected / can_post=false  → show why, stop
     → privacy_level_options=["SELF_ONLY"] → show "private only" notice
3. Seller picks 1..max_photo_count images, taps one to set the cover
4. Seller writes title (≤90) + description (≤4000), picks privacy from the
   options TikTok returned, chooses comments / music / brand type, ticks consent
5. uploadImages()        → POST /tiktok/posts/images  → URLs
6. createPhotoPost()     → POST /tiktok/posts         → publish_id
7. pollUntilSettled()    → GET  /tiktok/posts/{id}    → published / failed
8. Show the result and the publish_id
```

### Models (`tiktok_post_model.dart`)

- `TikTokCreatorInfo` — `privacyLevelOptions`, `canPost`, `quotaRemaining`,
  `defaultPrivacyLevel` (prefers the most public option the account allows)
- `TikTokPostState` — `pending | processing | published | failed | unknown`
- `TikTokPostStatus` — `publishId`, `state`, `message`, `postUrl`

---

## Compliance checklist

TikTok's Content Sharing Guidelines impose UI requirements. The composer in this
repo implements them, but they are worth keeping in mind if the UI is reworked:

- **Preview the content** before publishing — the seller sees the exact
  carousel and cover that will post.
- **Do not add watermarks or promotional logos** to the creator's content.
- **Preset text must be editable.** Nothing is force-appended to the caption.
- **Express consent before sending anything to TikTok.** The composer blocks
  the submit button until consent is ticked.
- **Reflect the account's real settings.** Interactions the creator disabled
  must be greyed out — hence driving the UI from `creator_info`.
- **Music consent.** A declaration agreeing to TikTok's Music Usage Confirmation
  must be shown before the publish action.
- **Respect the caps.** When `creator_info` reports the creator cannot post
  more right now, stop the attempt and tell the seller to try later.

---

## Still to do before this works end to end

1. Add `video.publish` to the app's scopes on the TikTok Developer Portal.
2. Submit the app for review. First-time review requires a **sandbox
   demonstration video** (max 5 videos, 50 MB each).
3. Verify the media domain serving `/media/tiktok/**` in the portal.
4. Implement the four Laravel endpoints.
5. Run `tiktok_posts` migrations.
6. **For public visibility**, apply for the API client audit. Until then every
   post is `SELF_ONLY` by TikTok's own restriction, not by app logic.

## Adding video later

`createPhotoPost` becomes `createVideoPost` with:

- `media_type: "VIDEO"`
- `POST /v2/post/publish/video/init/` with `source_info`
- A **chunked `PUT`** to the returned `upload_url` with
  `Content-Range: bytes <start>-<end>/<total>` and `Content-Type: video/mp4`.
  Videos cannot be posted from a URL the same way photos are, unless you use
  `PULL_FROM_URL` with a URL on a verified domain.
- Video caption limit is 2200 characters.