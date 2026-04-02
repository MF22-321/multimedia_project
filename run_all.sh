#!/bin/bash

PROJECT_ROOT="/home/febrian/development/multimedia_project"
FLUTTER_ROOT="/home/febrian/development/multimedia_project/frontend"

# Run FastAPI backend
gnome-terminal -- bash -c "cd $PROJECT_ROOT && ./.drwosy/bin/python -m uvicorn backend.fastAPI.main:app --host 127.0.0.1 --port 8000 --reload; exec bash"

sleep 2

# Run Flutter
gnome-terminal -- bash -c "cd $FLUTTER_ROOT && flutter run -d linux; exec bash"
