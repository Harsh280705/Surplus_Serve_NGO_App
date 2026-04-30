Usage Notice
This project is intended for educational and non-commercial use only.
You are free to use, modify, and learn from this project. However:
Commercial use, resale, or monetization of this project is not permitted.
Proper credit must be given to the original authors.
If you wish to use this project for commercial purposes, please contact the authors for permission.

# SurplusServe 🍲

A real-time food redistribution platform that connects event organizers, donors, and NGOs to reduce food waste and help communities in need.

----

## 🚨 Problem

Large amounts of food are wasted at weddings, events, and restaurants, while many people still lack access to proper meals.

There is no efficient real-time system to connect food donors with NGOs for quick distribution.

---

## 💡 Solution

**SurplusServe** solves this by enabling:

- Instant food donation posting  
- Real-time NGO notifications  
- Quick coordination and pickup  
- Location-based matching  
- Secure donation support  

---

## ⚙️ Key Features

### 📱 Mobile App (Flutter)
- User authentication (Email, Google Sign-In)  
- Post surplus food with location & details  
- Real-time notifications (Firebase Cloud Messaging)  
- In-app messaging system  
- Google Maps integration (navigation & tracking)  
- Donation system (Razorpay)  

---

### ☁️ Backend
- Firebase Authentication (user management)  
- Cloud Firestore (real-time database)  
- Firebase Cloud Messaging (notifications)  
- Firebase Storage (image handling)  
- Flask API (delivery logic & pricing)  

---

### 🌍 External Integrations
- Google Maps API → location & navigation  
- Distance Matrix API → delivery calculation  
- Razorpay → secure payments  

---

## 🏗️ Architecture Overview

<img width="1536" height="1024" alt="Image" src="https://github.com/user-attachments/assets/b544a5aa-e3ef-407a-ba05-e74440acb6ee" />

---

## 🔄 Working Flow

1. User logs in  
2. Organizer posts food details  
3. Data stored in Firestore  
4. NGOs receive notifications  
5. NGO accepts request  
6. Real-time chat starts  
7. NGO navigates using Maps  
8. Food is collected and marked complete  

---

## 🎬 Demo Video

👉 https://drive.google.com/drive/folders/1Hwivv2gvAG4cRjKwgy75uTVgWhD-8EpC?usp=drive_link

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK  
- Python 3.10+  
- Node.js  
- Firebase CLI  

---

### Setup

```bash
git clone https://github.com/Harsh280705/Surplus_Serve_NGO_App
cd Surplus_Serve_NGO_App

flutter pub get
flutter run

Backend Setup (Flask)
cd app
pip install -r requirements.txt
python app.py

👥 Team & Contribution

This project was developed in a team of 4.

