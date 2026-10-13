import os
from pathlib import Path

import firebase_admin
from firebase_admin import auth, credentials, firestore, messaging

_DEFAULT_CREDS = Path(__file__).resolve().parent.parent / "firebase-adminsdk.json"
_CREDENTIALS_PATH = Path(os.getenv("FIREBASE_CREDENTIALS_PATH", str(_DEFAULT_CREDS)))

STORAGE_BUCKET = os.getenv("FIREBASE_STORAGE_BUCKET", "sharemate-d7299.firebasestorage.app")


def get_firebase_app() -> firebase_admin.App:
    if firebase_admin._apps:
        return firebase_admin.get_app()
    creds = credentials.Certificate(str(_CREDENTIALS_PATH))
    try:
        return firebase_admin.initialize_app(creds, {"storageBucket": STORAGE_BUCKET})
    except ValueError:
        return firebase_admin.get_app()


def get_auth_client():
    get_firebase_app()
    return auth


def get_firestore_client():
    get_firebase_app()
    return firestore.client()


def get_messaging_client():
    get_firebase_app()
    return messaging
