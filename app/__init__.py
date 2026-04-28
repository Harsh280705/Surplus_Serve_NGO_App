# app/__init__.py
from dotenv import load_dotenv
load_dotenv()

import os
from flask import Flask
from flask_cors import CORS
import firebase_admin
from firebase_admin import credentials, firestore


def create_app():
    app = Flask(__name__)
    CORS(app)

    if not firebase_admin._apps:
        cred_path = os.getenv("FIREBASE_CREDENTIALS", "firebase-credentials.json")
        print("Using Firebase credentials:", cred_path)  # temporary
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)

    from app.delivery.routes import delivery_bp
    app.register_blueprint(delivery_bp)

    return app


app = create_app()
db = firestore.client()
