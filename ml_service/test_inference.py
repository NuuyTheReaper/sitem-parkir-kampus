import sys
import os
import cv2
import re

# Tambahkan path ml_service ke import path
current_dir = os.path.dirname(os.path.abspath(__file__))
sys.path.append(current_dir)

import ml_plate_service

# Path ke gambar uji
image_path = os.path.join(
    os.path.dirname(current_dir),
    "temp_extracted",
    "anpr-parking-system-main",
    "dataset_anpr",
    "test",
    "images",
    "G3540DV_jpg.rf.2a4921d77e04c16a8a8b3827a47f0a87.jpg"
)

if not os.path.exists(image_path):
    print(f"Error: Gambar uji tidak ditemukan di {image_path}")
    sys.exit(1)

print(f"Membaca gambar dari: {image_path}")
img = cv2.imread(image_path)
img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
height, width, _ = img.shape

print("Menjalankan model YOLOv8...")
if ml_plate_service.yolo_model is None:
    print("Error: Model tidak dimuat. Pastikan dependencies terinstal.")
    sys.exit(1)

results = ml_plate_service.yolo_model(img, conf=0.40)[0]

if len(results.boxes) > 0:
    print(f"\nBerhasil mendeteksi {len(results.boxes)} area plat nomor.\n")
    
    for box in results.boxes:
        x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())
        confidence = box.conf[0].item()
        
        crop_y1 = max(0, y1 - 5)
        crop_y2 = min(height, y2 + 5)
        crop_x1 = max(0, x1 - 5)
        crop_x2 = min(width, x2 + 5)
        plate_crop = img[crop_y1:crop_y2, crop_x1:crop_x2]
        
        if plate_crop.size > 0:
            gray_crop = cv2.cvtColor(plate_crop, cv2.COLOR_BGR2GRAY)
            resized_crop = cv2.resize(gray_crop, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
            thresh_crop = cv2.threshold(resized_crop, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]
            
            ocr_results = ml_plate_service.ocr_reader.readtext(thresh_crop)
            teks_list = []
            for (bbox, text, prob) in ocr_results:
                teks_list.append(text)
            
            teks_mentah = "".join(teks_list)
            plat_final = ml_plate_service.format_plat_indonesia(teks_mentah)
            
            print(f"--- HASIL EKSTRAKSI SISTEM ---")
            print(f"Teks Mentah OCR     : {teks_mentah}")
            print(f"Hasil Akhir (Bersih): {plat_final}")
            print(f"Akurasi Bounding Box: {confidence:.2f}\n")
            
            # --- Visualisasi Hasil ---
            cv2.rectangle(img_rgb, (x1, y1), (x2, y2), (0, 255, 0), 4)
            cv2.putText(img_rgb, plat_final, (x1, y1 - 15), 
                        cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 255, 0), 3)
else:
    print("YOLOv8 tidak menemukan area plat nomor pada gambar ini.")

# Tampilkan Gambar Akhir
try:
    import matplotlib.pyplot as plt
    print("Membuka window visualisasi dengan matplotlib...")
    plt.figure(figsize=(10, 10))
    plt.imshow(img_rgb)
    plt.axis('off')
    plt.title("Hasil Deteksi Plat Nomor")
    plt.show()
except ImportError:
    # Fallback ke cv2.imshow jika matplotlib tidak ada
    print("matplotlib tidak ditemukan, menggunakan OpenCV window...")
    cv2.imshow("Hasil Deteksi Plat Nomor", cv2.cvtColor(img_rgb, cv2.COLOR_RGB2BGR))
    cv2.waitKey(0)
    cv2.destroyAllWindows()
