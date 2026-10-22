# RepoViewer — GitHub Repository Viewer with Claude AI

A Flutter tablet app for browsing GitHub repositories, downloading ZIPs, 
and generating AI-powered lab reports via the Claude API.

---

## Features

- **Browse** any public GitHub repository with a file tree
- **View** source files with syntax highlighting (Verilog, Dart, Python, etc.)
- **Download ZIP** of the entire repository directly to your Downloads folder
- **AI Explain** — tap "Explain" on any Verilog file for a concise Claude summary
- **Generate Report** — select files and generate a full EQSemi lab report via Claude
- **Actions** — see GitHub Actions runs, download a run's artifacts and install APKs straight from the app
- **Two-pane tablet layout** — file tree on left, file content on right
- **Dark GitHub theme** throughout

---

## Install on a phone

Every successful CI build is published as a GitHub Release. Open
**https://github.com/SincerelyAdel/repo-viewer/releases/latest**, download
`RepoViewer.apk` and open it (allow "Install unknown apps" when asked).

---

## Setup

### Prerequisites
- Flutter SDK >= 3.0.0
- Android Studio or VS Code with Flutter extension
- Android tablet (the app is optimized for tablet sizing)

### Install dependencies
```bash
flutter pub get
```

### Run on connected tablet
```bash
flutter run
```

### Build APK
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Configuration (in-app)

Open **Settings** (gear icon) and enter:

| Field | Description |
|-------|-------------|
| Claude API Key | Your `sk-ant-api03-...` key from console.anthropic.com |
| GitHub Token | Optional `github_pat_...` for private repos or higher rate limits |

The Claude API key is required for:
- File explanation (AI button in file viewer)
- Report generation

For public repos like `SincerelyAdel/RTL`, no GitHub token is needed.

---

## Usage

1. Launch the app — it pre-fills with `https://github.com/SincerelyAdel/RTL`
2. Tap **Open** to browse the repository
3. Navigate folders, tap files to view them
4. Tap **Download ZIP** in the toolbar to save the repo to Downloads
5. Tap **Actions** (▶ icon) to see CI runs; open a run and tap **Get** on an
   artifact to download it, then **Install** on an APK. Downloading artifacts
   needs a GitHub token in Settings (GitHub requires sign-in for artifacts).
6. Tap **Report** to open the AI report generator
   - Select which Verilog files to include
   - Enter a lab number (optional)
   - Tap **Generate Report**

---

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   ├── repo_item.dart           # RepoItem, RepoInfo data classes
│   └── actions.dart             # WorkflowRun, Artifact data classes
├── services/
│   ├── github_service.dart      # GitHub API calls
│   ├── claude_service.dart      # Anthropic Claude API
│   ├── download_service.dart    # ZIP download with progress
│   ├── artifact_service.dart    # Actions artifact download, unzip, install
│   └── prefs_service.dart       # SharedPreferences (API keys, recent repos)
├── screens/
│   ├── home_screen.dart         # Repo URL input + recent repos
│   ├── repo_browser_screen.dart # Two-pane file tree browser
│   ├── file_viewer_screen.dart  # Syntax-highlighted file viewer
│   ├── report_screen.dart       # Claude report generation
│   ├── actions_screen.dart      # Actions runs + artifact download/install
│   └── settings_screen.dart    # API keys configuration
└── widgets/
    └── file_icon.dart           # File type icons and helpers
```

---

## Model Used

Claude **claude-sonnet-4-6** via the Anthropic API (`https://api.anthropic.com/v1/messages`)

---

## Notes

- Storage permission is requested on first ZIP download
- API keys are stored locally using `shared_preferences` (never sent anywhere except their respective APIs)
- The app works offline for browsing previously cached directory listings
