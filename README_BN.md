# Noor AI — Flutter Android source (v1.2)

বাংলা setup guide এবং project status নিচে দেওয়া হলো। এই ZIP-এ Flutter source, offline JSON assets এবং আলাদা Node.js backend আছে। এখানে Android SDK/Flutter SDK ইনস্টল করা নেই, তাই এই পরিবেশে APK build বা `flutter analyze` চালিয়ে সফলতার দাবি করা হচ্ছে না।

## কী আছে

- Premium emerald/ivory/gold UI, পাঁচটি স্থায়ী bottom tab: Home, Quran, Ask Noor AI, Library, Settings
- বাংলা/English UI toggle
- Panchagarh-এর আনুমানিক স্থানাঙ্কে `adhan` package দিয়ে local prayer calculation, upcoming prayer countdown, calculation method, Hanafi/Shafi'i Asr এবং manual minute offsets
- Bundled Quran dataset: 114 surah, 6,236 ayah records; Arabic + Bengali + English fields; keyword/surah search; offline reading
- Offline dua list and basic halal/haram guide
- Imported adhkar category data retained in `assets/data/adhkar.json`
- Gemini এবং OpenRouter আলাদাভাবে test, configurable model IDs, save/clear key, provider activation, gallery image caption requests
- Node backend supports server-side Gemini/OpenRouter keys and live `/test-provider` requests
- Favorites for Quran ayahs saved locally

## Important content accuracy / licensing notice

This project preserves data from the supplied `NamazApp (1).zip`. The original dataset did not provide a complete, independently verifiable license/source manifest for every Arabic string and Bengali/English translation. The Quran JSON has 114 surahs and 6,236 ayah entries structurally, but this alone does **not** prove every character, translation, attribution, or license is correct. The dua collection is not every dua available on the internet and should not be described as exhaustive. Hadith grading and the full halal/haram dataset have not undergone independent scholar review. Do not publish it as a certified religious reference until the dataset is checked against licensed sources by qualified reviewers.

The library shows a warning that its rulings are introductory guidance. An item missing from the database is not automatically Haram. No special choking dua is fabricated; choking/breathing difficulty requires immediate emergency care.

## Windows 11 + VS Code setup (বাংলা)

### 1. প্রয়োজনীয় সফটওয়্যার
1. Flutter SDK ইনস্টল করে PATH-এ `flutter\bin` যোগ করুন।
2. Android Studio ইনস্টল করুন এবং Android SDK / platform tools সেটআপ করুন।
3. VS Code-এ Flutter ও Dart extension ইনস্টল করুন।
4. ZIP extract করে `noor_ai_flutter` folder VS Code-এ খুলুন।

### 2. Android platform ও packages তৈরি
এই source ZIP-এ Android Gradle wrapper/platform folder অন্তর্ভুক্ত নেই। প্রথমবার project folder-এর terminal-এ চালান:

```powershell
flutter doctor
flutter create . --platforms=android
flutter pub get
dart format lib
flutter analyze
```

`flutter create .` existing `lib/` এবং `pubspec.yaml` রেখে missing Android platform scaffolding তৈরি করবে। যদি Flutter কোনো project metadata overwrite করতে চায়, আগে backup নিন।

### 3. Run
```powershell
flutter devices
flutter run
```

### 4. APK build (সহজ পদ্ধতি)
1. VS Code-এ `noor_ai_flutter` folder খুলুন।
2. Windows-এ Flutter SDK ও Android Studio/Android SDK সেটআপ করা থাকতে হবে।
3. প্রথমবারের জন্য internet চালু রেখে project folder-এর `build_apk.bat`-এ double-click করুন। এটি Android platform folder না থাকলে তৈরি করবে, packages install করবে এবং release APK build করবে।
4. চাইলে VS Code Terminal-এ নিচের command-গুলো একে একে চালাতে পারেন:
```powershell
flutter create --platforms=android --project-name noor_ai .
flutter pub get
flutter build apk --release
```
Expected output: `build\app\outputs\flutter-apk\app-release.apk`

এই build command সফলভাবে চালাতে হবে local Flutter/Android SDK-তে; এই deliverable তৈরি করার পরিবেশে Flutter SDK ছিল না, তাই APK এখানে build করা হয়নি।

## AI API setup

### Personal development mode (app settings)
1. App চালিয়ে **Settings → AI API connection center** খুলুন।
2. Gemini key-এর জন্য Google AI Studio থেকে key নিন; OpenRouter key-এর জন্য OpenRouter account ব্যবহার করুন।
3. Provider card-এ API key লিখে **Save key** চাপুন।
4. **Test connection** চাপুন। `SUCCESS` শুধু real provider response এলে দেখানো হয়।
5. প্রয়োজনীয় model ID সেট করুন; তারপর **Activate** করুন।
6. Gemini এবং OpenRouter স্বাধীনভাবে ব্যবহার করা যায়। Chat-এ selected provider ব্যবহৃত হয়; failure হলে provider স্বয়ংক্রিয়ভাবে পাল্টায় না।

**Security:** Personal development mode-এ key Android device-এর SharedPreferences-এ রাখা হয়। এটি production secret storage নয়। APK decompile/rooted device থেকে key উদ্ধার হতে পারে। Public release-এ এই direct-key flow ব্যবহার করবেন না।

### Production backend mode
Backend folder-এ:

```powershell
cd backend
npm install
copy .env.example .env
```

`backend/.env`-এ server-only secret দিন:

```env
PORT=3000
API_ACCESS_TOKEN=generate_a_long_random_secret_for_app_authentication
GEMINI_API_KEY=your_server_side_gemini_key
GEMINI_MODEL=gemini-2.5-flash
OPENROUTER_API_KEY=your_server_side_openrouter_key
OPENROUTER_MODEL=openrouter/auto
DEFAULT_PROVIDER=gemini
PROVIDER_TIMEOUT_MS=45000
CORS_ORIGIN=
```

তারপর:
```powershell
npm start
```
Health check: `http://localhost:3000/health`

Backend routes:
- `POST /ask` JSON: `{"provider":"gemini","message":"What is dua?"}`; optional `model`, `imageBase64`, `imageMimeType`; requires `Authorization: Bearer <API_ACCESS_TOKEN>`
- `POST /test-provider` JSON: `{"provider":"gemini"}`; requires the same bearer token and returns success only after a real provider response
- `GET /health`

**Production deployment note:** Deploy behind HTTPS, use a long random `API_ACCESS_TOKEN` (or replace it with proper per-user authentication), add rate limits/abuse monitoring before public release, restrict CORS to your real web origin, and keep `.env` out of version control. The supplied Flutter app currently uses its device-entered key directly for personal development; it is not automatically wired to this server-side mode. Do not treat the backend as production-secure until authentication and rate limiting are implemented.

## Data files

- `assets/data/quran.json`: imported Quran/translation dataset
- `assets/data/duas.json`: supplied starter dua records
- `assets/data/adhkar.json`: supplied adhkar categories and Arabic text
- `assets/data/titles.json`: category labels
- `assets/data/guide.json`: introductory halal/haram and FAQ entries

Re-run structural validation:
```powershell
node scripts/verify_data.mjs
```

## Test checklist

- [ ] `flutter pub get`
- [ ] `dart format lib`
- [ ] `flutter analyze` (fix any environment/version-specific findings)
- [ ] App starts on Android emulator and physical phone
- [ ] Switch all five bottom tabs repeatedly; state should remain mounted
- [ ] Change language Bangla ↔ English
- [ ] Quran opens offline; search by surah name and translation keyword
- [ ] Open an ayah and save favorite
- [ ] Search dua list and each halal/haram category
- [ ] Prayer calculation refresh; compare with a trusted Panchagarh mosque timetable for the same date/method
- [ ] Adjust Hanafi/Shafi'i, method and offsets; check next prayer after midnight
- [ ] Test Gemini valid key, invalid key, quota error, unsupported model, offline timeout
- [ ] Test OpenRouter valid key, invalid key, quota error, unsupported model, offline timeout
- [ ] Confirm provider switching is explicit and failure does not silently switch
- [ ] Pick a photo and request an Islamic caption
- [ ] Verify emergency wording for choking/severe illness
- [ ] Build release APK with `flutter build apk --release`

## Current known limitations

- No release APK is included because Flutter/Android SDK are not available in the build environment.
- No automatic mosque timetable feed is connected; prayer times are calculated locally.
- Device-side API key storage is for personal development only.
- Response streaming, hadith search corpus, full Juz browsing, licensed/verified translation metadata, connecting the Flutter app to the authenticated production backend, rate limiting, and exhaustive scholar-reviewed halal/haram content remain future work.
