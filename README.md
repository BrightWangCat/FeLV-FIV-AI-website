# FeLV/FIV LFA Reader

A web application for automated reading and classification of **FeLV/FIV lateral flow assay (LFA)** test strips used in veterinary diagnostics. Upload photos of test cassettes and get AI-powered classification results.

## Features

- **Dual classification pipelines**
  - **Claude AI (LLM)**: Sends preprocessed strip images to the Anthropic Claude API for vision-based classification
  - **OpenCV (CV)**: Local computer-vision pipeline using LAB color-space analysis and band detection — no API calls required
- **Image preprocessing**: Automatic cassette detection, contour straightening, orientation correction, and contrast enhancement
- **Batch processing**: Upload multiple test strip images at once with real-time progress tracking
- **Result categories**: Negative, Positive L (FeLV), Positive I (FIV), Positive L+I (both), Invalid
- **Manual correction**: Review and override AI classifications when needed
- **Patient metadata**: Attach species, age, sex, breed, and zip code to each test image
- **Statistics dashboard**: View aggregated classification results across batches
- **Export**: Download results as Excel spreadsheets
- **User management**: Registration, login (JWT auth), and admin controls

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **Frontend** | React 19, Vite 7, Ant Design 6, React Router 7 |
| **Backend** | Python 3.12, FastAPI, SQLAlchemy, Uvicorn |
| **AI/CV** | Anthropic Claude API, OpenCV (headless) |
| **Database** | SQLite |
| **Auth** | JWT (python-jose), bcrypt (passlib) |

## Project Structure

```
lfa-reader/
├── backend/
│   ├── app/
│   │   ├── main.py              # FastAPI app, startup migrations
│   │   ├── config.py            # Environment-based configuration
│   │   ├── database.py          # SQLAlchemy engine & session
│   │   ├── models.py            # User, UploadBatch, Image, PatientInfo
│   │   ├── schemas.py           # Pydantic request/response schemas
│   │   ├── auth.py              # JWT token utilities
│   │   ├── routers/
│   │   │   ├── users.py         # Registration, login, user management
│   │   │   ├── upload.py        # Image upload & batch creation
│   │   │   ├── reading.py       # AI/CV classification triggers
│   │   │   ├── stats.py         # Statistics endpoints
│   │   │   └── export.py        # Excel export
│   │   └── services/
│   │       ├── claude_inference.py           # Claude API classification
│   │       ├── cv_inference.py               # OpenCV band detection
│   │       └── image_preprocessor_for_LLM.py # Strip preprocessing
│   ├── requirements.txt
│   └── .env.example
├── frontend/
│   ├── src/
│   │   ├── App.jsx
│   │   ├── main.jsx
│   │   ├── services/api.js      # Axios API client
│   │   ├── context/AuthContext.jsx
│   │   ├── components/          # Navbar, Layout, ProtectedRoute
│   │   └── pages/               # Login, Register, Upload, Results, History, Stats, UserManagement
│   ├── package.json
│   └── vite.config.js
└── README.md
```

## Getting Started

### Prerequisites

- Python 3.12+
- Node.js 18+
- npm 9+

### Backend Setup

```bash
cd backend

# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env — set SECRET_KEY and optionally ANTHROPIC_API_KEY

# Start the server
uvicorn app.main:app --host 127.0.0.1 --port 8000 --workers 2
```

### Frontend Setup

```bash
cd frontend

# Install dependencies
npm install

# Start the dev server
npm run dev
```

The frontend dev server runs on `http://localhost:5173` and proxies API requests to the backend at `http://localhost:8000`.

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SECRET_KEY` | Yes | `dev-secret-key-...` | JWT signing key |
| `ANTHROPIC_API_KEY` | No | — | Required for Claude AI classification |
| `CLAUDE_DEFAULT_MODEL` | No | `claude-sonnet-4-6` | Claude model ID |
| `DATABASE_URL` | No | `sqlite:///./lfa_reader.db` | Database connection string |
| `CORS_ORIGINS` | No | `http://localhost:5173` | Comma-separated allowed origins |
| `UPLOAD_DIR` | No | `./uploads` | Directory for uploaded images |

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/health` | Health check |
| `POST` | `/api/users/register` | User registration |
| `POST` | `/api/users/login` | User login (returns JWT) |
| `POST` | `/api/upload` | Upload test strip images |
| `POST` | `/api/reading/{batch_id}/start` | Start AI/CV classification |
| `GET` | `/api/reading/{batch_id}/status` | Poll classification progress |
| `GET` | `/api/stats` | Get classification statistics |
| `GET` | `/api/export/{batch_id}` | Export results as Excel |

## Classification Pipeline

### Claude AI Pipeline
1. Detect and crop the test cassette from the photo
2. Straighten, orient, and enhance the strip region
3. Send the preprocessed image to Claude with a structured classification prompt
4. Parse the JSON response into category + confidence

### OpenCV CV Pipeline
1. Detect and crop the cassette (shared preprocessing)
2. Extract the analysis region covering the strip opening
3. Convert to LAB color space; compute column-wise a-channel profile
4. Two-stage band detection:
   - **Stage 1**: Zone-based 99th percentile scoring (sensitivity)
   - **Stage 2**: Column profile prominence validation (specificity)
5. Apply deterministic rules: C/L/I band presence → category

## License

This project is for research and educational purposes.
