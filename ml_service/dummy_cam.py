import cv2
import asyncio
import numpy as np
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from datetime import datetime

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

def generate_frames():
    """Generate dummy video frames with timestamp."""
    width, height = 640, 480
    
    while True:
        # Create a dark gray background
        frame = np.ones((height, width, 3), dtype=np.uint8) * 40
        
        # Add some "camera noise" (static)
        noise = np.random.randint(0, 30, (height, width, 3), dtype=np.uint8)
        frame = cv2.add(frame, noise)
        
        # Draw a simulated "Gate Area" box
        cv2.rectangle(frame, (100, 150), (540, 350), (0, 255, 0), 2)
        cv2.putText(frame, "GATE DETECTION AREA", (110, 140), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)
        
        # Overlay timestamp
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S.%f")[:-3]
        cv2.putText(frame, f"LIVE CAM - {timestamp}", (20, 30), 
                    cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        
        # Simulate a car license plate
        cv2.rectangle(frame, (220, 220), (420, 280), (200, 200, 200), -1)
        cv2.rectangle(frame, (220, 220), (420, 280), (0, 0, 0), 2)
        cv2.putText(frame, "G 7090 AB", (235, 260), 
                    cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 0, 0), 3)

        # Encode frame as JPEG
        ret, buffer = cv2.imencode('.jpg', frame)
        if not ret:
            continue
            
        frame_bytes = buffer.tobytes()
        
        # Yield in multipart format
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
        
        # Simulate ~15 FPS
        time.sleep(0.06)

import time

@app.get("/stream")
def video_stream():
    """Endpoint for MJPEG stream."""
    return StreamingResponse(
        generate_frames(), 
        media_type="multipart/x-mixed-replace; boundary=frame"
    )

if __name__ == "__main__":
    print("="*50)
    print("[DUMMY LIVE CAMERA BERJALAN]")
    print("URL Stream: http://127.0.0.1:8080/stream")
    print("="*50)
    uvicorn.run(app, host="0.0.0.0", port=8080)
