"""Tests for the Baata backend: upload cap removal, auth modes, startup."""

import glob
import os

from conftest import run_startup

MB = 1024 * 1024


# ---------------------------------------------------------------------------
# 1. Upload cap removal
# ---------------------------------------------------------------------------
def test_150mb_upload_succeeds(secure_app):
    app = secure_app
    client = app.app.test_client()

    # Sparse 150 MB file generated in /tmp, streamed from disk.
    path = "/tmp/baata_test_150mb.bin"
    with open(path, "wb") as f:
        f.seek(150 * MB - 1)
        f.write(b"\0")
    assert os.path.getsize(path) == 150 * MB

    with open(path, "rb") as stream:
        resp = client.post(
            "/profile/upload",
            data={"image": (stream, "big.jpg")},
            headers={"jwt": "valid-token"},
            content_type="multipart/form-data",
        )

    try:
        assert resp.status_code == 200
        saved = glob.glob(os.path.join(app.UPLOAD_FOLDER, "profile_*.jpg"))
        assert saved, "upload was not saved"
        assert os.path.getsize(saved[0]) == 150 * MB
    finally:
        os.remove(path)
        for p in saved:
            os.remove(p)


# ---------------------------------------------------------------------------
# 2. Token verification (Firebase mocked)
# ---------------------------------------------------------------------------
def test_valid_token_accepted(secure_app):
    client = secure_app.app.test_client()
    resp = client.post("/profile/Getname", headers={"jwt": "valid-token"})
    assert resp.status_code == 200

    # The user row must be keyed by the verified token's uid / phone number.
    conn = secure_app.get_db()
    try:
        row = conn.execute(
            "SELECT * FROM users WHERE firebase_uid = 'firebase-uid-1'"
        ).fetchone()
        assert row is not None
        assert row["phone_number"] == "+15550001111"
    finally:
        conn.close()


def test_invalid_token_gets_401(secure_app):
    client = secure_app.app.test_client()
    resp = client.post("/profile/Getname", headers={"jwt": "forged-token"})
    assert resp.status_code == 401
    assert resp.get_json()["error"] == "invalid token"


def test_missing_token_gets_401(secure_app):
    client = secure_app.app.test_client()
    resp = client.post("/profile/Getname")
    assert resp.status_code == 401
    assert resp.get_json()["error"] == "missing jwt"


def test_validation_is_required_in_secure_mode(app_factory, monkeypatch):
    """Without a monkeypatched verifier, valid tokens fail (no real SDK use)."""
    mod = app_factory(insecure=False)
    client = mod.app.test_client()
    resp = client.post("/profile/Getname", headers={"jwt": "anything"})
    assert resp.status_code == 401


def test_dev_insecure_mode_accepts_any_token(app_factory):
    mod = app_factory(insecure=True)
    assert mod.FIREBASE_AUTH_ENABLED is False
    client = mod.app.test_client()
    resp = client.post("/profile/Getname", headers={"jwt": "any-non-empty-string"})
    assert resp.status_code == 200


# ---------------------------------------------------------------------------
# 3. Startup behaviour
# ---------------------------------------------------------------------------
def test_startup_refuses_without_credentials():
    result = run_startup(
        {"GOOGLE_APPLICATION_CREDENTIALS": None, "BAATA_DEV_INSECURE_AUTH": None}
    )
    assert result.returncode != 0
    assert "GOOGLE_APPLICATION_CREDENTIALS" in result.stderr


def test_startup_refuses_when_credential_file_missing():
    result = run_startup(
        {
            "GOOGLE_APPLICATION_CREDENTIALS": "/nonexistent/baata-fake.json",
            "BAATA_DEV_INSECURE_AUTH": None,
        }
    )
    assert result.returncode != 0
    assert "GOOGLE_APPLICATION_CREDENTIALS" in result.stderr


def test_startup_succeeds_with_dev_insecure_auth():
    result = run_startup(
        {
            "BAATA_DEV_INSECURE_AUTH": "1",
        }
    )
    assert result.returncode == 0
    assert "insecure dev auth mode" in result.stderr
