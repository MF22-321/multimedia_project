# Driver Drowsiness Detection System

Real-time **Driver Monitoring System (DMS)** that combines **driver identification** and **drowsiness detection** using computer vision.

The system detects driver fatigue using **Eye Aspect Ratio (EAR)**, **Mouth Aspect Ratio (MAR)**, and a **composite drowsiness score**, while simultaneously identifying the driver using **LBPH face recognition**.

The project follows a **modular architecture based on the Single Responsibility Principle (SRP)** to maintain clean separation between vision processing, driver identity management, and drowsiness analysis.

# System Overview

Pipeline:

Camera → Face Detection → Face Identification → Driver Profile → Drowsiness Analysis → Alert

Detailed flow:

Camera Input
↓
Face Landmark Detection (MediaPipe)
↓
Face Identification (LBPH + Stabilizer)
↓
Driver Profile Loading
↓
Drowsiness Analysis

* EAR (Eye Aspect Ratio)
* MAR (Mouth Aspect Ratio)
* Yawn Detection
* Drowsiness Score
  ↓
  Driver Alert

If an **unknown driver** is detected:

Press N → Register new driver
Press G → Continue as guest

# Features

## Driver Identification

- LBPH face recognition
- Temporal vote stabilizer
- Multi-driver recognition
- Driver profile system
- Baseline calibration per driver

## Drowsiness Detection

- Eye Aspect Ratio (EAR)
- Mouth Aspect Ratio (MAR)
- Yawn detection
- Composite drowsiness score
- Temporal smoothing
- Alert trigger

## Driver Enrollment

- Real-time dataset capture
- Automatic LBPH model retraining
- Driver profile generation
- Automatic baseline calibration

## System Architecture

- Modular SRP-based design
- Clean separation of modules
- Configurable parameters
- Expandable system architecture


# Project Structure

Drowsiness_detection
│
├── dataset
│
├── faceid
│   ├── identifier.py
│   ├── lbph_model.py
│   ├── stabilizer.py
│   ├── landmarker_bbox.py
│   ├── enroll_runtime.py
│   ├── enrollment.py
│   ├── labels_store.py
│   └── profile_manager.py
│
├── models
│   ├── face_landmarker.task
│   ├── blaze_face_short_range.tflite
│   ├── labels.json
│   └── lbph_model.yml
│
├── profiles
│   ├── Pakde.json
│   ├── Raihan.json
│   ├── reiner.json
│   └── Sukit.json
│
├── src
│   ├── app.py
│   ├── config.py
│   ├── enroll_driver.py
│   ├── reset_faceid_data.py
│   ├── test_faceid.py
│   ├── ui.py
│   │
│   ├── drowsy
│   │   ├── engine.py
│   │   └── metrics.py
│   │
│   ├── identity
│   │   └── controller.py
│   │
│   └── vision
│       └── landmarker.py
│
├── requirements.txt
└── README.md


# Core Modules

## Vision Module

Location:

src/vision/landmarker.py

Responsibilities:

- Face landmark detection
- Eye landmark extraction
- Mouth landmark extraction
- EAR computation
- MAR computation

Uses:

- MediaPipe Face Landmarker


## Identity Module

Location:

src/identity/controller.py


Responsibilities:

- Driver recognition
- Unknown driver detection
- Driver enrollment
- Driver profile loading
- FaceID stabilization

Uses:

- LBPH Face Recognition
- Stabilizer voting system

## Drowsiness Module

Location:

src/drowsy/

Files:

engine.py
metrics.py

Responsibilities:

- EAR monitoring
- MAR monitoring
- Yawn detection
- Fatigue score computation
- Alert triggering

# Drowsiness Score Model

The system uses a weighted fatigue score.

Score = w_eye * EyeScore + w_yawn * YawnScore

Where:
EyeScore  = function(EAR / baseline_EAR)
YawnScore = normalized_yawn_frequency

Typical configuration:
w_eye  = 0.75
w_yawn = 0.25
alert_threshold = 0.70

# Driver Baseline Calibration

Each driver has a personal **baseline EAR** stored in:

profiles/<driver_name>.json

Example:

profiles/reiner.json

Example content:

{
"baseline_ear": 0.26
}

Baseline calibration happens when:

- New driver is registered
- Profile baseline is missing
- Manual recalibration is triggered

# Installation

## 1 Create Virtual Environment

python -m venv .venv

Activate environment (Windows):

.venv\Scripts\activate

## 2 Install Dependencies

pip install -r requirements.txt

Or manually:

pip install opencv-python
pip install opencv-contrib-python
pip install mediapipe
pip install numpy

# Required Models

Place the following files inside the `models/` folder:

models/
├── face_landmarker.task
├── blaze_face_short_range.tflite
├── lbph_model.yml
└── labels.json

# Running the System

Run from project root:

python -m src.app

# Utility Scripts

### Enroll Driver

python src/enroll_driver.py

Used to manually enroll a new driver.

### Reset FaceID Data

python src/reset_faceid_data.py

Clears existing labels, models, and profiles.

### Test FaceID

python src/test_faceid.py

```

Used to test face recognition independently.

---

# Keyboard Controls

| Key | Action |
|----|------|
| q | Quit application |
| r | Recalibrate baseline |
| n | Register new driver |
| g | Continue as guest |

---

# Example System Output

Typical UI overlay:

```

Driver: Reiner
BaselineSrc: PROFILE

EAR: 0.24
MAR: 0.35
YAWN: NO

Score: 0.42
Status: NORMAL

If fatigue is detected:

DROWSY ALERT


# Future Improvements

Planned system upgrades:

- CNN based face recognition
- PERCLOS eye closure metric
- Head pose estimation
- Driver attention monitoring
- Fleet monitoring integration
- Edge device deployment

# Author

Muhammad Reiner Akbar Prakoso  
Electrical Engineering — Universitas Indonesia

Focus areas:

- Driver Monitoring Systems
- Computer Vision
- ADAS Safety Systems