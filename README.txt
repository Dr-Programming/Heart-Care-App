===============================================================================
 LIBU CARE (Heart-Care App) - INSTALLATION AND RUN GUIDE
 UOW CSIT321 Capstone Project 29 - Group 3
 Version 1.2.1 (mobile app 1.2.1+3), October 2026
===============================================================================

 Libu Care is an offline-first heart-health system for people living with
 coronary heart disease (CHD) in Ethiopia. This file explains how to install,
 configure and run every part of the system on a new computer.

 Team:  Lachlan Smith (8838926), Ihab Al-Nasheei (8867197),
        Saif Abdulsattar (7978418), Thi Thuy Trang Nguyen (8693638),
        Prince Jiteshbhai Khakhariya (8909891), Jacqueline Tran (8827692)
 Client: Tesema Etefa Birhanu
 Supervisors: Dr Elena Vlahu-Gjorgievska, Prof. Khin Than Win


-------------------------------------------------------------------------------
 CONTENTS
-------------------------------------------------------------------------------
  1. What is in this package
  2. Prerequisites and required versions
  3. Configuration (.env file)
  4. Install and run the server side (database, API, web portals)
  5. Check that the server side works
  6. First use: admin portal, research portal
  7. Install and run the mobile app
  8. Optional: System Control Centre (monitoring dashboard)
  9. Optional: demonstration data (synthetic patients)
 10. Running the automated tests
 11. Stopping, restarting and resetting
 12. Troubleshooting
 13. Known limitations of this release


===============================================================================
 1. WHAT IS IN THIS PACKAGE
===============================================================================

 Folder                   What it is                          Runs at
 ------------------------ ----------------------------------- ------------------------
 backend/                 REST API (Java 21, Spring Boot)     http://localhost:8080/api/v1
                          and database schema (Flyway V1-V16)
 admin-web/               Admin portal for clinic staff       http://localhost:3000
                          (React, served by nginx)
 research-web/            Research portal for approved        http://localhost:3001
                          researchers (React, served by nginx)
 mobile/                  Patient mobile app (Flutter,        Android emulator, Android
                          Android and iOS)                    phone or iPhone
 system-control-centre/   Optional monitoring dashboard       http://localhost:3002
 monitoring-api/          API behind that dashboard           (internal only)
 monitoring/              Prometheus and exporter config,     (internal only)
                          JMeter load-test plan
 tools/synthetic-patients Optional script that creates       -
                          demonstration patients
 docs/                    Design specifications and plans     -
 docker-compose.yml       Starts PostgreSQL, the API and both web portals
 docker-compose.monitoring.yml   Optional monitoring add-on
 .env.example             Configuration template (copy to .env)

 The server side (database, API and both web portals) runs in Docker, so you
 do not need Java, Maven or Node.js installed just to run it. You only need
 those to run the automated tests or to develop the code (see Section 10).

 The three kinds of user each have their own app and their own sign-in:

   Patient     mobile app      Ethiopian phone number (+251...) and 4-digit PIN
   Admin       admin portal    username and password (set in .env)
   Researcher  research portal username and password (created by an admin)


===============================================================================
 2. PREREQUISITES AND REQUIRED VERSIONS
===============================================================================

 The versions in the "Tested with" column are the ones the team used to build
 and test this release. Newer patch versions should also work.

 A. To run the server side (required)
 ----------------------------------------------------------------------------
 Software                 Minimum           Tested with
 ------------------------ ----------------- ----------------------------------
 Docker Desktop (Windows  Docker Engine 24+ Docker 28.5.1,
   or macOS) or Docker    and Compose v2    Docker Compose v2.40.3
   Engine (Linux)
 A web browser            Any current       Chromium / Google Chrome
                          version
 Free ports on the host   5432, 8080, 3000, 3001 (and 3002 for monitoring)
 Disk space               About 3 GB for the Docker images and build cache

 Docker downloads everything else it needs (PostgreSQL 16, Java 21 runtime,
 Maven 3.9, Node.js 24, nginx 1.29) the first time you build. The first build
 needs an internet connection and takes about 5 to 10 minutes.

 B. To run the mobile app (required for patients)
 ----------------------------------------------------------------------------
 Software                 Minimum           Tested with
 ------------------------ ----------------- ----------------------------------
 Flutter SDK (stable)     3.47.0            Flutter 3.47.0 (Dart 3.13.0)
 Android Studio, with     Android SDK       Android emulator API 35;
   Android SDK and an     platform 37       Samsung Android phone
   Android emulator       installed (the
                          app compiles
                          against SDK 37)
 Android device or        Android 7.0       -
   emulator to run on     (API 24) or later
 For iOS only: a Mac      Xcode with iOS    iOS build tested on an iPhone
   with Xcode             15 SDK; device    with iOS 15 or later
                          on iOS 15+

 Run "flutter doctor" after installing Flutter. Every item you plan to use
 (Android toolchain, and Xcode on a Mac) should show a green tick.

 C. To run the tests or develop the code (optional)
 ----------------------------------------------------------------------------
 Software                 Version           Needed for
 ------------------------ ----------------- ----------------------------------
 Java JDK                 21                backend/ and monitoring-api/
 Apache Maven             3.9+              backend/ and monitoring-api/
 Node.js and npm          Node 24, npm 11   admin-web/, research-web/,
                                            system-control-centre/
 Python                   3.12+             tools/synthetic-patients/ only
 Git                      Any               Cloning the repository

 Tested with: Java 21.0.9, Maven 3.9.14, Node 24.12.0, npm 11.12.1.


===============================================================================
 3. CONFIGURATION (.env FILE)
===============================================================================

 All secrets and settings for the server side live in one file called ".env"
 in the top folder of the project (next to docker-compose.yml). It is never
 committed to Git. A template with placeholder values is provided.

 Step 3.1  Copy the template

     Windows (PowerShell or Command Prompt):   copy .env.example .env
     macOS / Linux / Git Bash:                 cp .env.example .env

 Step 3.2  Open .env in a text editor and set these values

 Variable                   Required?  What to put
 -------------------------- ---------- ----------------------------------------
 JWT_SECRET                 YES        A random secret, at least 32 bytes long.
                                       Signs all sign-in tokens.
 RESEARCH_PSEUDONYM_SECRET  YES        A different random secret, at least 32
                                       bytes. Creates the patient codes that
                                       researchers see. Do not change it later,
                                       or every patient gets a new code.
 POSTGRES_PASSWORD          Recommended  A strong database password.
 POSTGRES_DB, POSTGRES_USER No         Leave as "heartcare".
 ADMIN_USERNAME             Recommended  Admin portal username, e.g. "admin".
 ADMIN_PASSWORD             Recommended  Admin portal password, AT LEAST 12
                                       characters. If either admin value is
                                       blank, no admin account is created and
                                       you cannot sign in to the admin portal.
 CORS_ALLOWED_ORIGINS       No         Leave as "http://localhost:*".

 The MONITORING_DB_PASSWORD, SCC_* and NGROK_API_URL values are only needed
 for the optional monitoring dashboard (Section 8).

 Step 3.3  Generate the two random secrets

   macOS, Linux or Git Bash:
       openssl rand -base64 48

   Windows PowerShell (no extra software needed):
       $b = New-Object byte[] 48
       [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
       [Convert]::ToBase64String($b)

   Run it twice and paste one result into JWT_SECRET and the other into
   RESEARCH_PSEUDONYM_SECRET. Do not put quotes around the values.

 Example of a completed .env (use your own values, not these):

     POSTGRES_DB=heartcare
     POSTGRES_USER=heartcare
     POSTGRES_PASSWORD=Use-A-Strong-Password-1
     JWT_SECRET=q3N0...(64 random characters)...Zk8=
     CORS_ALLOWED_ORIGINS=http://localhost:*
     ADMIN_USERNAME=admin
     ADMIN_PASSWORD=ClinicAdmin-2026!
     RESEARCH_PSEUDONYM_SECRET=Hc7X...(64 random characters)...p0w=

 IMPORTANT: the admin account is created only the first time the API starts.
 Changing ADMIN_PASSWORD in .env afterwards does NOT change the password of
 the existing account (see Section 12, problem 5).


===============================================================================
 4. INSTALL AND RUN THE SERVER SIDE (database, API, web portals)
===============================================================================

 Step 4.1  Start Docker Desktop and wait until it says it is running.

 Step 4.2  Open a terminal in the top folder of the project (the folder that
           contains docker-compose.yml and .env).

 Step 4.3  Build and start everything:

     docker compose up -d --build

   This builds and starts four containers:

     heartcare-postgres       PostgreSQL 16 database       port 5432
     heartcare-backend        Spring Boot REST API         port 8080
     heartcare-admin-web      Admin portal (nginx)         port 3000
     heartcare-research-web   Research portal (nginx)      port 3001

   On first start the API creates all database tables automatically (Flyway
   migrations V1 to V16) and creates the admin account from .env. Database
   data is kept in the Docker volume "heartcare-pgdata", so it survives
   restarts.

 Step 4.4  Check that all four containers are running:

     docker compose ps

   All four should show "running" (PostgreSQL also shows "healthy"). If
   heartcare-backend is missing or keeps restarting, see Section 12, problem 1.


===============================================================================
 5. CHECK THAT THE SERVER SIDE WORKS
===============================================================================

 1. API health check. Open this address in a browser:

        http://localhost:8080/api/v1/health

    It should return a short JSON reply containing "status":"UP". (From a
    terminal you can use: curl http://localhost:8080/api/v1/health)

 2. Admin portal. Open http://localhost:3000. You should see the Libu Care
    Admin sign-in page.

 3. Research portal. Open http://localhost:3001. You should see the Libu Care
    Research sign-in page.

 4. Backend log. If anything looks wrong, read the API log:

        docker logs heartcare-backend

    A healthy start ends with a line saying the application "Started" and
    shows no ERROR lines.


===============================================================================
 6. FIRST USE: ADMIN PORTAL AND RESEARCH PORTAL
===============================================================================

 Admin portal (http://localhost:3000)
   1. Sign in with ADMIN_USERNAME and ADMIN_PASSWORD from your .env file.
   2. The Overview, Patients, Flagged vitals and Urgent symptoms pages are
      empty until a patient registers and syncs from the mobile app
      (Section 7), or until you load demonstration data (Section 9).
   3. Patient data is read-only in the admin portal.

 Research portal (http://localhost:3001)
   There is no sign-up. A researcher account must be created by an admin:
   1. In the admin portal, go to Researchers -> Add a researcher.
   2. Enter a name, username and organisation, choose the access level and at
      least one dataset, then save.
   3. The portal shows a TEMPORARY PASSWORD once. Copy it.
   4. Open http://localhost:3001, sign in with that username and temporary
      password, and choose a new password (12+ characters) when asked.

   Note: research results that describe fewer patients than the minimum
   group size (default 5) are hidden. With only one or two test patients most
   results will show as hidden. This is expected. Load demonstration data
   (Section 9) to see full results.

 Other computers on the same network can open the portals with
   http://<server-IP-address>:3000 and http://<server-IP-address>:3001.


===============================================================================
 7. INSTALL AND RUN THE MOBILE APP
===============================================================================

 The server side (Section 4) must be running first, so the app can register
 and sync patients.

 IMPORTANT - server address: the address of the API is built into the app
 when it is compiled. Always pass it with --dart-define=API_BASE_URL=...
 as shown below. If you leave it out, the app uses the default in
 mobile/lib/core/config/env.dart, which is the development team's ngrok
 tunnel. That tunnel is not running for you, so the app would not be able to
 register or sync.

 Step 7.1  Open a terminal in the mobile folder:

     cd mobile

 Step 7.2  Download the Flutter packages:

     flutter pub get

 Step 7.3  Generate the code (REQUIRED - generated files are not included):

     dart run build_runner build --delete-conflicting-outputs

   This takes 1 to 3 minutes. Without it the app does not compile (you would
   see errors about missing ".g.dart" files).

 Step 7.4  Start a device:
   - Android emulator: in Android Studio open Device Manager and start a
     virtual device (API 24 or later; API 35 was used for testing), or
   - Android phone: turn on Developer options and USB debugging, connect it
     by USB and accept the prompt on the phone, or
   - iPhone (Mac only): connect it, or start an iOS Simulator.

   Check that Flutter can see it:

     flutter devices

 Step 7.5  Run the app with the right server address:

   Where the app runs                   Command
   ------------------------------------ ---------------------------------------
   Android emulator on the same         flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
     computer as Docker
   iOS Simulator on the same Mac        flutter run --dart-define=API_BASE_URL=http://localhost:8080
   Real phone on the same Wi-Fi         flutter run --dart-define=API_BASE_URL=http://<computer-IP>:8080
     network as the computer

   10.0.2.2 is how the Android emulator reaches the host computer. It does not
   work on a real phone. To find <computer-IP>, run "ipconfig" (Windows) or
   "ipconfig getifaddr en0" (macOS) and use the IPv4 address, for example
   http://192.168.1.20:8080. The computer's firewall must allow incoming
   connections on port 8080.

   When more than one device is connected, add "-d <device-id>" (from
   "flutter devices") to the command.

 Step 7.6  First launch on the phone:
   1. Choose English or Amharic.
   2. Allow notifications when asked (needed for medicine and appointment
      reminders on Android 13 and later).
   3. Tap Sign up. Enter a +251 Ethiopian phone number, your name and a 4-digit
      PIN, then answer three security questions (used if the PIN is forgotten).
   4. Complete the short setup wizard (CHD stage, goals, clinic contact).
   The patient now appears in the admin portal under Patients.

   The first sign-in on a phone needs the server. After that, the same patient
   can sign in and use the app offline; records sync when the phone is back
   online.

 Step 7.7  (Optional) Build an installable Android app (APK):

     flutter build apk --release --dart-define=API_BASE_URL=http://<server-address>:8080

   The file is created at:
     mobile/build/app/outputs/flutter-apk/app-release.apk
   Copy it to an Android phone and open it to install (allow "Install unknown
   apps" when asked). The server address cannot be changed after the build;
   to point the app at a different server, build it again.

   For iOS (Mac only): open mobile/ios/Runner.xcworkspace in Xcode once to
   choose your Apple development team for signing, then run:

     flutter build ios --release --dart-define=API_BASE_URL=https://<server-address>

   The minimum supported version is iOS 15.


===============================================================================
 8. OPTIONAL: SYSTEM CONTROL CENTRE (MONITORING DASHBOARD)
===============================================================================

 A separate dashboard showing live performance of the API, database and
 server, with a Demonstration Mode that produces a performance report. The
 main system works the same with or without it.

 Step 8.1  In .env, set:
     MONITORING_DB_PASSWORD   a strong password
     SCC_ADMIN_USERNAME       e.g. scc-admin
     SCC_ADMIN_PASSWORD       at least 12 characters
     SCC_JWT_SECRET           a random secret (generate it as in Step 3.3)

 Step 8.2  Start the system with the monitoring add-on:

     docker compose -f docker-compose.yml -f docker-compose.monitoring.yml up -d --build

 Step 8.3  Open http://localhost:3002 and sign in with the SCC account.

 More detail (host metrics, container metrics, load testing with JMeter):
 monitoring/README.md.


===============================================================================
 9. OPTIONAL: DEMONSTRATION DATA (SYNTHETIC PATIENTS)
===============================================================================

 The script in tools/synthetic-patients/ creates realistic made-up patients
 with three months of history, by calling the same API the mobile app uses.
 This fills the admin and research portals with data. Use it ONLY on a test
 database, never on real patient data.

 Requires Python 3.12 or later (no extra packages). Because the API allows
 only 10 sign-ups per hour from one address, the limit must be raised for the
 run. Full instructions are in tools/synthetic-patients/README.md. In short:

     cd tools/synthetic-patients
     python simulate.py preview --patients 5      (look at a sample first)
     python simulate.py run --patients 200        (create the patients)
     python simulate.py backdate --run out/run-<id>
     python simulate.py cleanup --run out/run-<id>   (to remove them again)


===============================================================================
 10. RUNNING THE AUTOMATED TESTS
===============================================================================

 Run each command from the folder named. Docker must be running for the
 backend tests, because they start their own temporary PostgreSQL database
 (Testcontainers).

   Part                     Command                                Result at release
   ------------------------ -------------------------------------- -----------------
   backend/                 mvn test                               359 / 359 pass
   mobile/                  flutter analyze                        No issues found
   mobile/                  flutter test                           916 / 916 pass
   admin-web/               npm install, npm run build,            build passes,
                            npm run lint                           0 lint errors
   research-web/            npm install, npm run build,            build passes
                            npm run lint
   monitoring-api/          mvn test   (no Docker needed)          pass
   system-control-centre/   npm install, npm run build,            build passes
                            npm run lint

 Test cases and results are described in TEST_SUITE.md and TEST_REPORT.md.

 To run the web portals in development mode (live reload) instead of Docker,
 keep the API running on port 8080 and run "npm install" then "npm run dev"
 in admin-web/ (http://localhost:5173) or research-web/ (http://localhost:5174).


===============================================================================
 11. STOPPING, RESTARTING AND RESETTING
===============================================================================

   Stop everything (data is kept):          docker compose down
   Start again (no rebuild):                docker compose up -d
   Rebuild after changing source code:      docker compose up -d --build
   Restart only the API:                    docker compose restart backend
   View live API logs:                      docker logs -f heartcare-backend

   DELETE ALL DATA and start with an empty database (cannot be undone):

       docker compose down -v
       docker compose up -d --build

   With the monitoring add-on running, use the same two -f options as in
   Step 8.2 for each of these commands.


===============================================================================
 12. TROUBLESHOOTING
===============================================================================

 1. The API (heartcare-backend) stops or keeps restarting
    Run "docker logs heartcare-backend" and read the last lines. Usual causes:
    - JWT_SECRET or RESEARCH_PSEUDONYM_SECRET is missing, or shorter than 32
      bytes. Generate new ones (Step 3.3).
    - ADMIN_PASSWORD is shorter than 12 characters.
    - .env is not in the top project folder, or was saved as ".env.txt"
      (Windows Notepad does this). Rename it to exactly ".env".
    After fixing .env, run: docker compose up -d

 2. "port is already allocated" / "address already in use"
    Another program is using 5432, 8080, 3000 or 3001. A local PostgreSQL
    installation often uses 5432. Stop that program, or change the left-hand
    port number in docker-compose.yml (for example "5433:5432").

 3. "Conflict. The container name ... is already in use"
    The containers were created before under a different project name. Start
    with the original name to keep the existing data, for example:
        docker compose -p heart-care-app-main up -d --build
    To see the project name of the existing containers:
        docker ps -a --format "{{.Names}}\t{{.Label \"com.docker.compose.project\"}}"
    Or, if you do not need the old data, remove the old containers with
    "docker rm -f heartcare-postgres heartcare-backend heartcare-admin-web
    heartcare-research-web" and start again.

 4. Docker commands fail with "cannot connect to the Docker daemon" or
    "pipe/dockerDesktopLinuxEngine"
    Docker Desktop is not running. Start it and wait until it is ready.

 5. Cannot sign in to the admin portal
    - Check that ADMIN_USERNAME and ADMIN_PASSWORD were set before the API
      first started. The account is created only once.
    - If you changed the password in .env later, the old password still
      applies. To start again with the new values, reset the database
      (Section 11; this deletes all data).
    - After 5 wrong passwords the account is locked for a short time.
      Restarting the API clears this lock.

 6. The mobile app shows "no connection", cannot sign up, or never syncs
    - The app was built without --dart-define=API_BASE_URL, so it is trying
      the team's ngrok address. Run it again with the correct address (Step 7.5).
    - On a real phone, 10.0.2.2 and localhost do not work. Use the computer's
      IP address, make sure the phone and computer are on the same Wi-Fi, and
      allow port 8080 through the computer's firewall.
    - Check the API is up: open http://<address>:8080/api/v1/health from a
      browser ON THE PHONE.

 7. Flutter build errors mentioning ".g.dart", "part of" or undefined
    "_$..." classes
    The generated code is missing or out of date. In mobile/ run:
        dart run build_runner build --delete-conflicting-outputs

 8. Android build fails asking for a newer SDK, or "compileSdk 37"
    Open Android Studio -> SDK Manager and install Android SDK Platform 37 and
    the latest build tools. Then run "flutter doctor --android-licenses" and
    accept the licences.

 9. Sign-up in the app fails after many test accounts
    The API allows 10 sign-ups per hour from one network address. Wait an
    hour, or restart the API ("docker compose restart backend").

 10. A patient is locked out of the app
    Five wrong PINs lock the account for 15 minutes. Wait, or use "Forgot
    PIN" with the security questions (five wrong answers lock recovery for
    60 minutes).

 11. Medicine reminders do not appear on Android
    Allow notifications for Libu Care in the phone's Settings -> Apps. On
    Android 12 and later also allow "Alarms and reminders".

 12. The research portal shows most results as "hidden" or "Too few to
    analyse"
    This is the privacy protection working: groups smaller than the minimum
    group size (default 5) are hidden. Add more patients (Section 9), or an
    admin can lower the minimum group size on the Researchers page.

 13. The first "docker compose up --build" is very slow or fails while
    downloading
    The first build downloads several hundred megabytes of images and
    packages. Check the internet connection and run the command again; it
    continues from where it stopped.


===============================================================================
 13. KNOWN LIMITATIONS OF THIS RELEASE
===============================================================================

 - This setup uses plain HTTP. Before real patients use the system, the API
   must be put behind HTTPS (for example a reverse proxy with a TLS
   certificate) and the app rebuilt with the https:// address.
 - Records on the phone are stored in a standard (unencrypted) SQLite
   database. Sign-in tokens and the offline PIN check are kept in the phone's
   secure storage.
 - The iOS app needs iOS 15 or later.
 - Appointments, clinic contact and caregiver contact are stored on the phone
   only and are not backed up to the server.
 - Activity advice uses general rules until the care team supplies its own.

 The full list, with the reasons, is in Section 2.2 of the technical report.

 Further documentation:
   README.md                    project overview
   ARCHITECTURE.md              original architecture document
   FUNCTIONAL_REQUIREMENTS.md   requirements with IDs and priorities
   backend/README.md            API configuration and endpoints
   backend/docs/API.md          API reference
   mobile/README.md             mobile app details
   admin-web/README.md          admin portal guide
   research-web/README.md       research portal guide
   monitoring/README.md         monitoring dashboard

===============================================================================
 END OF README.txt
===============================================================================
