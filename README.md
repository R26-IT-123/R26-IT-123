# ShareMate: A Socially Connected Smart Mobility & Community Support App

ShareMate is a university research project that brings student mobility, academic resource sharing, and community support into one Flutter application. The app connects to a FastAPI gateway and six Python services. Firebase supplies authentication, data storage, file storage, and push messaging. The current code targets student use cases such as public transport information, shared private rides, study notes, groceries, and a community chat.

> **Project status:** This repository contains the application and service implementations, but a complete local launch needs project-specific Firebase configuration. `flts_service` and `route_sharing_service` currently import `services.firebase`, which is absent from those two directories; those services cannot start until that module is supplied. See [Known setup gaps](#known-setup-gaps).

## Project objectives

- Make student travel easier to coordinate through shared public transport information and private ride bookings.
- Help students report route incidents, view timetable data, and share live journey information.
- Support academic collaboration through topic-based notes, content scoring, and note interactions.
- Connect shoppers and requesters for shared grocery errands, with chat and feedback.
- Provide a common student account and notification experience across these activities.

## Key features

| Area | Features visible in the code |
| --- | --- |
| Accounts and profiles | Student registration with email OTP, Firebase-based login, profile updates, and profile photo upload. |
| Public transport (`flts_service`) | Bus routes, passenger sharing sessions, incident reports, feedback, timetable search, and a scheduled timetable scraper. The Flutter client includes map and ETA views. |
| Private rides (`route_sharing_service`) | Route publishing and search, booking approval and decline, fare calculation, ride sessions and location updates, payment-slip submission and verification, feedback, and notifications. |
| Academic notes (`anie_service`) | Note validation and topic scoring using embeddings and keywords, topic PDF generation, note browsing, wallet and purchase actions, downloads, likes, and comments. |
| Groceries (`grocery_service`) | Shopper announcements, item requests, request handling, chats, notifications, feedback, and trust profiles. |
| Community chat (`community_chat_service`) | A Firestore-backed chat screen in the Flutter app and a service endpoint that sends Firebase Cloud Messaging notifications for new messages. |
| API gateway (`api_gateway`) | Proxies `/api/*` routes to the six services and builds combined OpenAPI documentation from their schemas. |

These are implemented code paths, not a claim that every flow has been deployed or fully tested.

## Technology stack

| Layer | Technologies identified in the repository |
| --- | --- |
| Mobile | Dart, Flutter, Android and iOS project files; `http`, `google_maps_flutter`, `geolocator`, `flutter_local_notifications`, and PDF/file/image picker packages. |
| Backend | Python, FastAPI, Uvicorn, Pydantic, HTTPX, and `python-dotenv`. Each service has its own `requirements.txt`. |
| Firebase | Firebase Authentication, Cloud Firestore, Cloud Storage, and Firebase Cloud Messaging through `firebase-admin` and Flutter Firebase packages. |
| Note analysis | `sentence-transformers`, Transformers, PyTorch, NumPy, EasyOCR, PyMuPDF, Pillow, and ReportLab; data files under `model/`. |
| Transport data | Google Maps Flutter and Google Maps Directions API; FLTS timetable scraping uses Requests, Beautiful Soup, lxml, and APScheduler. |
| Collaboration | Git and GitHub. |

## Project folder structure

```text
.
├── anie_service/             # Academic note API, scoring, and note workflows
├── api_gateway/              # API proxy and combined OpenAPI schema
├── auth_service/             # Registration, OTP, login, and profiles
├── community_chat_service/   # Community-chat push notification endpoint
├── flts_service/             # Public transport routes, sharing, incidents, timetables
├── grocery_service/          # Grocery announcements, requests, chats, trust
├── model/                    # ANIE embeddings and topic/reference data
├── route_sharing_service/    # Private routes, bookings, rides, payments, feedback
└── sharemate_mobile/         # Flutter app: lib/, android/, ios/, web/, test/
```

The Python services use `main.py` entry points and organize endpoints under `routers/`, data models under `schemas/`, and business logic under `services/`. `sharemate_mobile/lib/features/` groups screens and API clients by application area.

## Installation and setup

The commands below use a macOS/Linux shell. Use a Python interpreter compatible with the pinned packages and the code's Python 3.10+ syntax, plus a Flutter SDK compatible with the Dart `^3.6.0` constraint in `sharemate_mobile/pubspec.yaml`. Android development also needs an Android SDK and an available emulator or device. iOS development needs the Apple toolchain.

1. Clone the repository and enter it:

   ```bash
   git clone https://github.com/R26-IT-123/R26-IT-123.git
   cd R26-IT-123
   ```

2. Create a separate virtual environment and install dependencies for each Python component:

   ```bash
   for service in anie_service api_gateway auth_service community_chat_service flts_service grocery_service route_sharing_service; do
     python3 -m venv "$service/.venv"
     "$service/.venv/bin/python" -m pip install -r "$service/requirements.txt"
   done
   ```

3. Configure Firebase and service settings as described below. Use credentials for a Firebase project that has the Auth, Firestore, Storage, and Messaging services required by the selected flows. Keep service-account JSON files and `.env` files out of commits.

4. Install Flutter packages and check your device setup:

   ```bash
   cd sharemate_mobile
   flutter pub get
   flutter doctor
   flutter devices
   ```

5. Start the Python services and gateway in separate terminals, then run the Flutter app as shown in [How to run the application](#how-to-run-the-application).

## Configuration

Each Python `main.py` calls `load_dotenv()`, so a service-specific `.env` file can be placed in that service's working directory. The following are the settings read by the source code. Values shown are placeholders; obtain real values from the project maintainers or the relevant provider.

| Component | Setting | Purpose |
| --- | --- | --- |
| Firebase-backed services | `FIREBASE_CREDENTIALS_PATH` | Path to a Firebase Admin service-account JSON file. The implemented Firebase helpers default to `firebase-adminsdk.json` in their service directory. |
| Firebase-backed services | `FIREBASE_STORAGE_BUCKET` | Cloud Storage bucket name; the implemented helpers have a project-specific default. |
| `auth_service` | `FIREBASE_WEB_API_KEY` | Required by the `/api/auth/login` Firebase Identity Toolkit call. |
| `auth_service` | `SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASSWORD`, `FROM_EMAIL` | SMTP settings for registration OTP email; host and port have code defaults. |
| `anie_service` | `MODEL_DIR` | Directory containing `embeddings.npy`, `faiss_metadata.json`, `topics.json`, `topic_keywords.json`, and `topic_calibration.json`. Set this to the absolute path of this repo's `model/` directory; the code default points elsewhere. |
| `route_sharing_service` | `GOOGLE_MAPS_API_KEY` | Optional Google Maps Directions API key; the code falls back to straight-line distance without it. |
| `route_sharing_service` | `GEMINI_API_KEY` | Used by the feedback summary code when configured. |
| `route_sharing_service` | `ROUTE_MATCH_RADIUS_KM`, `WEEKLY_DISCOUNT_PCT`, `FARE_BAND1_THRESHOLD_KM`, `FARE_BAND2_THRESHOLD_KM`, `FARE_BAND1_RATE_MIN`, `FARE_BAND1_RATE_MAX`, `FARE_BAND2_RATE_MIN`, `FARE_BAND2_RATE_MAX`, `FARE_BAND3_RATE_MIN`, `FARE_BAND3_RATE_MAX`, `PICKME_RATE_PER_KM` | Optional route matching and fare parameters with defaults in the code. |
| `api_gateway` | `AUTH_SERVICE_URL`, `FLTS_SERVICE_URL`, `ANIE_SERVICE_URL`, `ROUTESHARING_SERVICE_URL`, `GROC_SERVICE_URL`, `COMMUNITY_CHAT_SERVICE_URL` | Upstream addresses; defaults are `http://localhost:8001` through `:8006` in the order shown below. |

For example, a local `auth_service/.env` can contain:

```dotenv
FIREBASE_CREDENTIALS_PATH=/absolute/path/to/service-account.json
FIREBASE_STORAGE_BUCKET=your-project-bucket
FIREBASE_WEB_API_KEY=your-web-api-key
SMTP_HOST=your-smtp-host
SMTP_PORT=587
SMTP_USER=your-smtp-user
SMTP_PASSWORD=your-smtp-password
FROM_EMAIL=your-sender-address
```

`anie_service/.env` should contain `MODEL_DIR=/absolute/path/to/R26-IT-123/model` and its Firebase settings. The other implemented Firebase helpers are in `community_chat_service` and `grocery_service`; see the gap below for `flts_service` and `route_sharing_service`.

The Flutter app initializes Firebase through `sharemate_mobile/lib/firebase_options.dart`. Android also has `sharemate_mobile/android/app/google-services.json` and a Google Maps key entry in `AndroidManifest.xml`. The HTTP gateway URL is currently a literal default in `sharemate_mobile/lib/config/api_client.dart`, not an environment variable. For local testing, that URL must point to a gateway address reachable from the chosen device. Do not copy service-account credentials into the mobile app.

## How to run the application

After installing dependencies and configuration, run each command in a **separate terminal from the repository root**. The ports match the gateway defaults in `api_gateway/main.py`.

| Terminal | Command | Local port |
| --- | --- | --- |
| Auth | `cd auth_service && .venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8001` | 8001 |
| FLTS | `cd flts_service && .venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8002` | 8002 |
| ANIE | `cd anie_service && .venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8003` | 8003 |
| Route sharing | `cd route_sharing_service && .venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8004` | 8004 |
| Grocery | `cd grocery_service && .venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8005` | 8005 |
| Community chat | `cd community_chat_service && .venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8006` | 8006 |
| API gateway | `cd api_gateway && .venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8000` | 8000 |

Start the services before the gateway so its combined OpenAPI schema can load their routes. Check the gateway at `http://127.0.0.1:8000/health` and its docs at `http://127.0.0.1:8000/docs`. The gateway's `POST /refresh-docs` endpoint rebuilds its schema after services become available.

Run the mobile app in another terminal:

```bash
cd sharemate_mobile
flutter run
```

`flutter devices` lists available targets; use `flutter run -d DEVICE_ID` to choose one. A phone or emulator must be able to reach the configured gateway URL. A server bound to `127.0.0.1` is reachable only on its own host, so expose or map the gateway appropriately for the selected device.

### Known setup gaps

- `flts_service` and `route_sharing_service` import `services.firebase`, but those files are absent from the repository. **[To be added: the Firebase helper implementation for these two services.]** Their startup commands above will fail until this is resolved.
- `anie_service` loads its scoring model on startup. Its default `MODEL_DIR` points to `../shortnotescore/model`, not this repository's `model/`; set `MODEL_DIR` explicitly.
- The mobile API gateway address is hard-coded in `sharemate_mobile/lib/config/api_client.dart`. **[To be added: an environment-based endpoint configuration.]** A local run requires a reachable address there.
- The iOS tree does not contain `GoogleService-Info.plist`. **[To be added: verified iOS Firebase and Maps setup instructions.]** The steps above describe the verifiable Flutter/Android path.

## Team collaboration

The repository's existing contribution guidance asks contributors to work through branches and pull requests rather than push directly to `main`.

1. Sync with `main`: `git checkout main && git pull origin main`.
2. Create a topic branch: `git checkout -b feature/short-description`.
3. Make a focused change, review `git diff`, and stage only intended files: `git add path/to/file`.
4. Commit with a clear message: `git commit -m "Describe the change"`.
5. Push the branch: `git push -u origin feature/short-description`.
6. Open a GitHub pull request targeting `main`, describe the change and any tests, and request review before merging.

Never include `.env` files, service-account JSON, tokens, or local build output in a commit.

## Contributors

| Role | Name | Contribution |
| --- | --- | --- |
| Research team member 1 | [To be added] | [To be added] |
| Research team member 2 | [To be added] | [To be added] |
| Research team member 3 | [To be added] | [To be added] |
| Research team member 4 | [To be added] | [To be added] |
| Supervisor(s) | [To be added] | [To be added] |

## University research project

| Item | Details |
| --- | --- |
| University | [To be added] |
| Academic year | [To be added] |
| Research group ID | [To be added] |
| Course or program | [To be added] |
| Research title or registration details | [To be added] |
| Project status or evaluation details | [To be added] |
