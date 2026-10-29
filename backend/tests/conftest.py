"""Shared fixtures for the Baata backend tests.

The Firebase Admin SDK is replaced by a minimal fake so tests are
deterministic and never touch the network; tests monkeypatch
``firebase_auth.verify_id_token`` to control the outcome of verification.
"""

import importlib
import os
import pathlib
import subprocess
import sys
import types

import pytest

BACKEND_DIR = pathlib.Path(__file__).resolve().parents[1]


def _install_fake_firebase_admin():
    """Inject a minimal fake firebase_admin package into sys.modules."""
    fb = types.ModuleType("firebase_admin")

    credentials = types.ModuleType("firebase_admin.credentials")

    class Certificate:
        def __init__(self, path):
            self.path = path

    credentials.Certificate = Certificate

    auth = types.ModuleType("firebase_admin.auth")
    auth.verify_id_token = lambda token, app=None: (_ for _ in ()).throw(
        AssertionError("tests must monkeypatch firebase_auth.verify_id_token")
    )

    def initialize_app(cred=None, options=None):
        fb._cred = cred

    fb.credentials = credentials
    fb.auth = auth
    fb.initialize_app = initialize_app

    sys.modules["firebase_admin"] = fb
    sys.modules["firebase_admin.credentials"] = credentials
    sys.modules["firebase_admin.auth"] = auth


@pytest.fixture
def app_factory(monkeypatch):
    """Import backend/app.py fresh with a chosen auth mode.

    The module is re-imported for every app instance so module-level state
    (FIREBASE_AUTH_ENABLED) matches the requested configuration, and each
    instance gets its own temporary database and upload folder.
    """
    sys.path.insert(0, str(BACKEND_DIR))

    def factory(*, insecure=False):
        sys.modules.pop("app", None)
        monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)
        monkeypatch.delenv("BAATA_DEV_INSECURE_AUTH", raising=False)
        _install_fake_firebase_admin()
        if insecure:
            monkeypatch.setenv("BAATA_DEV_INSECURE_AUTH", "1")
        else:
            # A real dummy credential file: the fake SDK never reads it.
            import tempfile

            fd, cred_path = tempfile.mkstemp(suffix=".json")
            os.close(fd)
            monkeypatch.setenv("GOOGLE_APPLICATION_CREDENTIALS", cred_path)
        mod = importlib.import_module("app")
        tmp = importlib.import_module("tempfile").mkdtemp()
        mod.DB_PATH = os.path.join(tmp, "test.db")
        mod.UPLOAD_FOLDER = os.path.join(tmp, "uploads")
        os.makedirs(mod.UPLOAD_FOLDER, exist_ok=True)
        mod.init_db()
        return mod

    return factory


@pytest.fixture
def secure_app(app_factory, monkeypatch):
    """App instance with Firebase verification enabled and a valid token."""
    mod = app_factory(insecure=False)

    claims = {"uid": "firebase-uid-1", "phone_number": "+15550001111"}

    def verify_id_token(token, app=None):
        if token == "valid-token":
            return claims
        raise Exception("invalid token")

    monkeypatch.setattr(mod.firebase_auth, "verify_id_token", verify_id_token)
    return mod


def run_startup(env_overrides):
    """Run `python -c "import app"` from backend/ with the given env tweaks."""
    env = dict(os.environ)
    for key, value in env_overrides.items():
        if value is None:
            env.pop(key, None)
        else:
            env[key] = value
    return subprocess.run(
        [sys.executable, "-c", "import app"],
        cwd=str(BACKEND_DIR),
        env=env,
        capture_output=True,
        text=True,
        timeout=120,
    )
