## Product Requirements Document (PRD)

### Product
**Gasolinahan** — local gas price finder + nearest stations + crowdsourced OCR-based price updates.

### Document info
- **Version**: 0.1 (draft)
- **Date**: 2026-03-07
- **Owner**: Gasolinahan team



## 1) Overview
Gasolinahan is a mobile app that shows **station-level fuel prices in local communities**, helps users find the **nearest gas stations**, and keeps prices up-to-date via **crowdsourced photo uploads** of station price boards. Uploaded photos are processed using **Google OCR**, parsed into structured fuel prices, then stored and served from **Firebase** with coordinates and timestamps.

### Problem
Drivers lack a single, reliable, up-to-date source of **branch-specific** fuel prices and promos; prices change frequently and vary by station location.

### Goal
Make fuel pricing **transparent, searchable, and nearby**, using a scalable update loop: **photo → OCR → verification → publish**.



## 2) Target users & personas
- **Daily commuter**: wants the cheapest nearby gasoline/diesel quickly.
- **Ride-hailing / delivery driver**: optimizes refuel cost/time; checks multiple fuel types often.
- **Road tripper**: plans refueling; cares about station amenities and promos.
- **Contributor (“Scout”)**: uploads price board photos to keep data fresh.
- **Moderator/Admin**: reviews submissions for quality and safety.



## 3) Success metrics (KPIs)
- **Price coverage**: % of stations with a price updated within the last 7 days (pilot target: 30–50% in initial area).
- **Freshness**: median time since last verified update per station (pilot target: <72 hours).
- **Accuracy**: published price accuracy vs spot-check audit (target: ≥95%).
- **Engagement**: WAU/MAU, searches per user, station detail views.
- **Conversion**: “navigate to station” taps per active user.
- **Supply of updates**: uploads/day, acceptance rate, time-to-publish.
- **Moderation load**: average review time and queue size.



## 4) Scope

### In scope
- **Nearby station discovery** (map + list, distance, “updated recently”).
- **Station details**: address, coordinates, prices by fuel type, last updated time, confidence/verification status.
- **Fuel prices** for relevant types (e.g., gasoline variants, diesel; expandable later).
- **Crowdsourced updates**:
  - take/upload a price board photo
  - OCR extraction via Google OCR
  - parse into structured price fields
  - attach GPS coordinates + timestamp
  - submit to Firebase
  - verification workflow before publish
- **Search & filters**: fuel type, brand, distance radius, cheapest nearby, updated within.
- **Abuse prevention**: rate limits, reputation signals, duplicate detection.

### Out of scope (initially)
- Direct oil-company pricing API integrations / partnerships.
- Payments, loyalty points, in-app purchases.
- Full route planning / multi-stop optimizer (Phase 2).
- Guaranteed nationwide completeness at launch.



## 5) User stories (representative)
- As a user, I want to see **current fuel prices near me** so I can pick where to refuel.
- As a user, I want to filter by **Diesel** and sort by **cheapest** within 5 km.
- As a user, I want station details (address, hours if known, promos) so I can choose best value.
- As a contributor, I want to **take a photo** and have the app **auto-fill extracted prices** for quick review.
- As a moderator, I want to **review and approve/deny submissions** to keep prices accurate.



## 6) Functional requirements

### 6.1 Onboarding & permissions
- Request **location permission** (foreground). Allow limited browsing without it via area search.
- Request **camera permission** only when the user enters “Report”.

### 6.2 Home / Explore
- Show nearby stations (map/list), selected fuel type price, and freshness indicator.
- Quick filters: fuel type, “cheapest”, “updated recently”, brand (optional).

### 6.3 Map & list view
- Cluster pins, tap pin → station preview.
- Filters:
  - radius (1/3/5/10/20 km)
  - brand
  - “updated within” (24h/3d/7d)
  - amenities (optional: air, restroom, convenience store)

### 6.4 Station detail page
- Station metadata: brand, address, coordinates, hours/contact if available.
- Price table by fuel type + “last verified update”.
- Promo section (if available).
- Optional: recent change history (last N updates, anonymized).
- Primary actions: **Navigate**, **Report/update prices**, **Report issue**.

### 6.5 Price update via photo (core loop)
**Capture**
- Provide capture tips: align board, avoid glare, include station name/logo if possible.
- Attach metadata: GPS (with accuracy), timestamp, device info.

**OCR + parsing**
- Run Google OCR on the photo.
- Parse OCR text into structured prices (fuel labels + numeric PHP/L values).
- Show “Review extracted prices” screen allowing quick corrections.

**Submission**
- Upload: image(s), OCR text, parsed fields, metadata.
- Server validates:
  - price plausibility bounds (PHP/L)
  - geo proximity plausibility
  - duplicate detection (similar image/time + same station)
- Station match:
  - match to nearest known station, or create a “candidate station” for moderation.

**Publishing**
- Publish only after verification (automatic or moderation-based).
- Keep previous verified price as fallback if new data is unverified/uncertain.

### 6.6 Moderation / admin console (required)
- Queue view with: photo, OCR text, parsed prices, map location, station match.
- Actions: approve/publish, reject (with reason), merge into station, flag user.
- Audit log for price changes.



## 7) Data & system requirements

### 7.1 Conceptual data entities
- **Station**
  - id, name, brand, address, lat/lng, geo index (e.g., geohash), amenities, status
- **PriceSnapshot**
  - stationId, fuelType, price, currency (PHP), observedAt, publishedAt, confidence, sourceSubmissionId, verificationStatus
- **Submission**
  - userId (or anonymous id), stationMatch (stationId or candidate), lat/lng + accuracy, photoUrls, ocrRawText, parsedFields, createdAt, status
- **Promo**
  - stationId/brandId, title, details, validity dates, source
- **User/Reputation**
  - contribution count, acceptance rate, trust tier, bans/flags

### 7.2 OCR + parsing approach
- OCR: Google OCR (cloud or on-device depending on cost/latency).
- Parsing:
  - detect PHP currency patterns and common fuel labels
  - normalize decimals and formatting
  - compute confidence score from label match + numeric plausibility + OCR certainty

### 7.3 Nearby queries
- Store stations with geo indexing (e.g., geohash).
- Query by radius + sort by distance.



## 8) Non-functional requirements
- **Performance**: nearby results <1.5s average; station detail <1s cached.
- **Reliability**: OCR failures fall back to manual entry (still attach photo).
- **Security**: strict Firebase security rules; admin-only publish permissions.
- **Privacy**:
  - clear consent for camera/location
  - do not show contributor identity publicly
  - define retention policy for raw images (e.g., delete originals after X days if not needed)
- **Scalability**: start in pilot region, expand to nationwide.
- **Cost controls**: compress images; quotas/rate limits; batch processing.



## 9) Trust, safety, and abuse prevention
- Rate-limit submissions (per user/device/day).
- Reputation-based thresholds for auto-approval.
- Duplicate detection and anomaly detection (price jumps, out-of-range, far-from-station).
- User reporting of wrong prices with rollback capability.



## 10) MVP definition (recommended)

### Pilot geography
Start with 1–2 local areas (e.g., a primary city and nearby communities) to validate the loop.

### MVP features
- Seeded station list for pilot region.
- Map/list of nearby stations with prices and “last updated”.
- Photo submission → OCR → user review → submit.
- Admin moderation queue (approve/reject).
- Filters: fuel type, radius, updated within.

### MVP non-goals
- Full promos/partnership program.
- Advanced amenities coverage.
- Route planning / trip optimizer.



## 11) Dependencies & assumptions
- Initial station dataset: public sources/manual import/user-discovered candidates.
- OCR service availability and acceptable cost at pilot scale.
- Firebase used for auth, storage, database, and server-side processing (e.g., Cloud Functions).



## 12) Risks & mitigations
- **Low data quality** → moderation + confidence scoring + reputation system.
- **Low coverage** → seed data + contributor incentives (Phase 2).
- **OCR errors (glare/angles)** → capture guidance + retake prompts + manual edit fallback.
- **High OCR cost** → image compression, quotas, selective OCR, consider on-device OCR where feasible.
- **Brand/legal concerns** → use publicly visible boards; provide takedown/report channel; avoid implying affiliation.



## 13) Launch & rollout
- Private alpha (small group of drivers) → pilot city release → expand regions.
- Iterate on capture UX + parsing accuracy based on moderation outcomes and user reports.



## 14) MVP acceptance criteria
- User can view **nearest stations** and see at least one fuel price (when available).
- User can submit a photo and see **extracted prices** pre-filled for review.
- Submission stores **GPS + timestamp + image** and appears in moderation queue.
- Approved submission updates prices visible in-app quickly.
- Station prices show **last updated time** and **verification status** (verified vs unverified).

