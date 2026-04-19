# LFA Reader

An automated reading and classification system for **veterinary lateral flow assay (LFA)** test strips. The project supports three disease workflows:

- **FIV/FeLV** for cats
- **Tick Borne** for dogs
- **Canine Urothelial Carcinoma** for dogs

The current product uses a **single-image, image-based workflow** across both the web app and the native iOS app. Each uploaded image can be preprocessed, classified, manually corrected, and reviewed together with workflow-specific patient metadata.

The source code is published under a **source-available, noncommercial** license.
This repository is **not** distributed under an OSI-approved open source license.

**Live Demo**: https://16.59.11.102:8080  
The site uses a self-signed certificate, so browsers will show a warning the first time you open it.

## Highlights

| Feature | Web | iOS |
|---------|:---:|:---:|
| Camera capture with scan-guide overlay | ✅ | ✅ |
| Photo library upload | ✅ | ✅ |
| Workflow-first single-image upload flow | ✅ | ✅ |
| Disease workflow selection | ✅ | ✅ |
| Automatic image preprocessing | ✅ | ✅ |
| OpenCV classification | ✅ | ✅ |
| Manual correction override | ✅ | ✅ |
| Backend-generated advisories | ✅ | ✅ |
| User-facing timestamps normalized to US Eastern Time (`ET`) | ✅ | ✅ |
| Statistics dashboard with per-disease filtering | ✅ | ✅ |
| Area code geographic heatmap | ✅ | ✅ |
| Admin user management | ✅ | — |

### Classification Categories

- **Negative**: control (`C`) band only
- **Positive L**: `C` + `L` band
- **Positive I**: `C` + `I` band
- **Positive L+I**: `C` + both `L` and `I` bands
- **Invalid**: no valid control band detected

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **iOS App** | Swift, SwiftUI, AVFoundation, async/await |
| **Web Frontend** | React 19, React Router 7, Vite 7, Ant Design 6.3, Leaflet, react-webcam |
| **Backend** | Python 3.12, FastAPI, SQLAlchemy 2, Pydantic 2, Uvicorn |
| **Computer Vision** | OpenCV headless, LAB color-space band detection |
| **Database** | SQLite |
| **Auth** | JWT via python-jose, bcrypt via passlib |

## Quick Start

### Prerequisites

- Python 3.12+
- Node.js 20.19+
- Xcode 15+ for iOS development on macOS

### Backend

```bash
cd apps/backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

cat > .env << EOF
SECRET_KEY=your-secret-key-here
CORS_ORIGINS=http://localhost:5173
DATABASE_URL=sqlite:///./lfa_reader.db
UPLOAD_DIR=./uploads
EOF

uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Swagger UI is available at `http://127.0.0.1:8000/docs`.

### Web Frontend

```bash
cd apps/web
npm install

cat > .env.local << EOF
VITE_API_BASE_URL=http://localhost:8000
EOF

npm run dev
```

If `VITE_API_BASE_URL` is unset, the web app assumes same-origin API routing.

### iOS App

```bash
open apps/ios/LFAReader.xcodeproj
```

Or build from the command line:

```bash
xcodebuild -project apps/ios/LFAReader.xcodeproj -scheme LFAReader \
  -destination 'generic/platform=iOS Simulator' build
```

The app requires iOS 17.0+.

## Repository Layout

```text
lfa-reader/
├── apps/backend/    # FastAPI backend
├── apps/web/        # React web app
├── apps/ios/        # SwiftUI iOS app
├── shared/data/     # Shared workflow and reference data
└── scripts/         # Operational helper scripts
```

## API

The backend exposes authentication, upload, reading, and statistics endpoints.
Run the backend locally and open `/docs` for the current Swagger UI.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## License

This repository is licensed under the **PolyForm Noncommercial License 1.0.0**.
Commercial use is not allowed under that license.
See [LICENSE](LICENSE) and [NOTICE](NOTICE) for details.
