#!/bin/bash

cd /home/febrian/development/multimedia_project

# kill port lama
fuser -k 8000/tcp

# backend jalan background beneran
nohup /home/febrian/miniconda3/envs/drwosy/bin/python -m uvicorn backend.fastAPI.main:app --host 127.0.0.1 --port 8000 > backend.log 2>&1 &

sleep 5

# buka flutter
/home/febrian/development/multimedia_project/frontend/build/linux/x64/release/bundle/frontend