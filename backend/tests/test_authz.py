"""Authorization tests: the acting identity comes only from the verified
Firebase ID token, and a user can only read or write chats they take part in.

firebase_admin is faked (see conftest.py): token "A" verifies as uid "A",
token "B" as uid "B" and token "C" as uid "C"; anything else is rejected.
The two startup tests run the real firebase-admin SDK in a subprocess on a
copy of app.py, with HTTP(S) proxies pointed at a closed port so nothing can
reach Google.
"""

import io
import json
import os
import shutil
import subprocess
import sys
import time
import base64

import pytest
from werkzeug.datastructures import FileStorage

from conftest import BACKEND_DIR

TOKENS = {
    "A": {"uid": "A", "phone_number": "+15550000001"},
    "B": {"uid": "B", "phone_number": "+15550000002"},
    "C": {"uid": "C", "phone_number": "+15550000003"},
}


def fake_verify_id_token(token, app=None, check_revoked=False, clock_skew_seconds=0):
    if token in TOKENS:
        return dict(TOKENS[token])
    raise ValueError("invalid token")


@pytest.fixture
def mod(app_factory, monkeypatch):
    m = app_factory(insecure=False)
    monkeypatch.setattr(m.firebase_auth, "verify_id_token", fake_verify_id_token)
    return m


@pytest.fixture
def client(mod):
    return mod.app.test_client()


def as_user(token):
    return {"jwt": token}


def make_chat(mod, chat_id, u1, u2, messages=()):
    """Insert a chat and its messages directly, independent of the routes."""
    conn = mod.get_db()
    try:
        conn.execute(
            "INSERT INTO chats (chat_id, u1, u2, n1, n2, last_message_time, created_at) "
            "VALUES (?, ?, ?, '', '', 1, 'now')",
            (chat_id, u1, u2),
        )
        for i, (sender, text, media_path) in enumerate(messages):
            conn.execute(
                "INSERT INTO messages (id, chat_id, sender, message_time, message_text, "
                "is_media, media_type, media_path, thumb_path) "
                "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                (
                    f"{chat_id}-{i}",
                    chat_id,
                    sender,
                    i + 1,
                    text,
                    1 if media_path else 0,
                    "Image" if media_path else None,
                    media_path,
                    media_path,
                ),
            )
        conn.commit()
    finally:
        conn.close()


def query(mod, sql, args=()):
    conn = mod.get_db()
    try:
        return [dict(r) for r in conn.execute(sql, args).fetchall()]
    finally:
        conn.close()


def media_form(chat_id, field, **meta):
    return {
        "data": json.dumps({"id": chat_id, "MessageText": "", **meta}),
        field: (io.BytesIO(b"media-bytes"), "clip.mp4" if field == "video" else "pic.jpg"),
    }


# ---------------------------------------------------------------------------
# StartMessagingWithNewContact: selfUid must not be trusted
# ---------------------------------------------------------------------------
def test_start_messaging_ignores_client_self_uid(mod, client):
    resp = client.post(
        "/StartMessagingWithNewContact",
        json={"contactUid": "C", "selfUid": "B", "messageText": "hi, this is B"},
        headers=as_user("A"),
    )
    assert resp.status_code == 200
    chats = query(mod, "SELECT u1, u2 FROM chats")
    assert chats == [{"u1": "A", "u2": "C"}], chats
    senders = [m["sender"] for m in query(mod, "SELECT sender FROM messages")]
    assert senders == ["A"], senders
    assert not query(mod, "SELECT id FROM users WHERE firebase_uid = 'B'")


def test_self_uid_cannot_rebind_account_to_read_another_users_chat(mod, client):
    make_chat(mod, "chat-BC", "B", "C", [("B", "B-to-C secret", None)])
    client.post(
        "/StartMessagingWithNewContact",
        json={"contactUid": "X", "selfUid": "B", "messageText": "x"},
        headers=as_user("A"),
    )
    resp = client.get("/GetChatFromUid/uid=C", headers=as_user("A"))
    assert b"B-to-C secret" not in resp.data
    assert resp.data == b"notFound"


# ---------------------------------------------------------------------------
# postMessageToId
# ---------------------------------------------------------------------------
def test_post_message_sender_comes_from_token(mod, client):
    make_chat(mod, "chat-AB", "A", "B")
    resp = client.post(
        "/postMessageToId",
        json={"id": "chat-AB", "Sender": "B", "MessageText": "I owe A $100"},
        headers=as_user("A"),
    )
    assert resp.status_code == 200
    senders = [m["sender"] for m in query(mod, "SELECT sender FROM messages")]
    assert senders == ["A"], senders


def test_post_message_into_another_users_chat_is_403(mod, client):
    make_chat(mod, "chat-BC", "B", "C")
    resp = client.post(
        "/postMessageToId",
        json={"id": "chat-BC", "Sender": "B", "MessageText": "injected"},
        headers=as_user("A"),
    )
    assert resp.status_code == 403
    assert not query(mod, "SELECT id FROM messages")


def test_post_message_cannot_create_a_chat_for_someone_else(mod, client):
    resp = client.post(
        "/postMessageToId",
        json={"id": "fresh-chat", "Sender": "B", "MessageText": "from 'B'"},
        headers=as_user("A"),
    )
    assert resp.status_code == 404
    assert not query(mod, "SELECT chat_id FROM chats")
    assert not query(mod, "SELECT id FROM messages")


# ---------------------------------------------------------------------------
# getMessageFormid
# ---------------------------------------------------------------------------
def test_reading_another_users_chat_is_403(mod, client):
    make_chat(mod, "chat-BC", "B", "C", [("B", "B-to-C secret", None)])
    resp = client.post("/getMessageFormid", json={"id": "chat-BC"}, headers=as_user("A"))
    assert resp.status_code == 403
    assert b"secret" not in resp.data
    # A participant still reads it.
    resp = client.post("/getMessageFormid", json={"id": "chat-BC"}, headers=as_user("C"))
    assert resp.status_code == 200
    assert resp.get_json()[0]["MessageText"] == "B-to-C secret"


# ---------------------------------------------------------------------------
# PostImageToId / PostVideoToId
# ---------------------------------------------------------------------------
@pytest.mark.parametrize("route,field", [("/PostImageToId", "image"), ("/PostVideoToId", "video")])
def test_post_media_into_another_users_chat_is_403_and_saves_nothing(mod, client, route, field):
    make_chat(mod, "chat-BC", "B", "C")
    resp = client.post(
        route,
        data=media_form("chat-BC", field, Sender="B"),
        headers=as_user("A"),
        content_type="multipart/form-data",
    )
    assert resp.status_code == 403
    assert not query(mod, "SELECT id FROM messages")
    assert os.listdir(mod.UPLOAD_FOLDER) == []


@pytest.mark.parametrize("route,field", [("/PostImageToId", "image"), ("/PostVideoToId", "video")])
def test_post_media_sender_comes_from_token(mod, client, route, field):
    make_chat(mod, "chat-AB", "A", "B")
    resp = client.post(
        route,
        data=media_form("chat-AB", field, Sender="B"),
        headers=as_user("A"),
        content_type="multipart/form-data",
    )
    assert resp.status_code == 200
    senders = [m["sender"] for m in query(mod, "SELECT sender FROM messages")]
    assert senders == ["A"], senders


# ---------------------------------------------------------------------------
# messageimage / messageVideo / getVidThumb
# ---------------------------------------------------------------------------
@pytest.mark.parametrize("route", ["/messageimage", "/messageVideo", "/getVidThumb"])
def test_downloading_another_users_chat_media_is_403(mod, client, route):
    path = os.path.join(mod.UPLOAD_FOLDER, "private.bin")
    with open(path, "wb") as f:
        f.write(b"B-and-C-private-photo")
    make_chat(mod, "chat-BC", "B", "C", [("B", "", path)])

    resp = client.get(f"{route}?id=chat-BC&i=0", headers=as_user("A"))
    assert resp.status_code == 403
    assert b"private-photo" not in resp.data

    resp = client.get(f"{route}?id=chat-BC&i=0", headers=as_user("C"))
    assert resp.status_code == 200
    assert resp.data == b"B-and-C-private-photo"


# ---------------------------------------------------------------------------
# Upload file names: no client-controlled path components
# ---------------------------------------------------------------------------
@pytest.fixture
def saved_paths(monkeypatch):
    paths = []
    original = FileStorage.save

    def spy(self, dst, buffer_size=16384):
        paths.append(os.fspath(dst))
        return original(self, dst, buffer_size)

    monkeypatch.setattr(FileStorage, "save", spy)
    return paths


def _directly_in(folder, path):
    return os.path.dirname(os.path.normpath(path)) == os.path.normpath(folder)


@pytest.mark.parametrize(
    "filename",
    [
        "x./../../../escaped",  # traversal through the "extension"
        "Dr./Who|||DeLimitMe|||jpg",  # pfpselect's name payload, name has "./"
    ],
)
@pytest.mark.parametrize("route", ["/profile/upload", "/UpdateProfile"])
def test_profile_upload_filename_cannot_pick_the_path(mod, client, saved_paths, route, filename):
    data = {"image": (io.BytesIO(b"img"), filename)}
    if route == "/UpdateProfile":
        data["data"] = json.dumps({"hasImage": True})
    resp = client.post(route, data=data, headers=as_user("A"), content_type="multipart/form-data")
    assert resp.status_code == 200
    assert saved_paths, "nothing was saved"
    for p in saved_paths:
        assert _directly_in(mod.UPLOAD_FOLDER, p), p
        assert "|" not in os.path.basename(p) and " " not in os.path.basename(p), p


def test_media_upload_chat_id_cannot_pick_the_path(mod, client, saved_paths):
    resp = client.post(
        "/PostImageToId",
        data=media_form("../../../escaped", "image"),
        headers=as_user("A"),
        content_type="multipart/form-data",
    )
    outside = [p for p in saved_paths if not _directly_in(mod.UPLOAD_FOLDER, p)]
    assert not outside, outside
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# Identity resolution
# ---------------------------------------------------------------------------
def test_phone_number_does_not_hand_over_another_uids_account(mod, client):
    """A row bound to a different Firebase uid (e.g. a deleted account whose
    phone number was reassigned) must not become the caller's identity."""
    conn = mod.get_db()
    conn.execute(
        "INSERT INTO users (id, firebase_uid, phone_number, name, created_at) "
        "VALUES ('row-old', 'OLD', '+15550000001', 'Old Owner', 'now')"
    )
    conn.commit()
    conn.close()
    make_chat(mod, "chat-old", "OLD", "C", [("OLD", "old owner's secret", None)])

    assert client.post("/profile/Getname", headers=as_user("A")).data == b""
    resp = client.get("/GetChatFromUid/uid=C", headers=as_user("A"))
    assert resp.data == b"notFound"
    client.post(
        "/UpdateProfile",
        data={"data": json.dumps({"hasName": True, "Name": "Mallory"})},
        headers=as_user("A"),
        content_type="multipart/form-data",
    )
    assert query(mod, "SELECT name FROM users WHERE id = 'row-old'") == [{"name": "Old Owner"}]


def test_unclaimed_row_adopted_by_phone_is_bound_to_the_uid(mod, client):
    conn = mod.get_db()
    conn.execute(
        "INSERT INTO users (id, phone_number, name, created_at) "
        "VALUES ('row-legacy', '+15550000001', 'Alice', 'now')"
    )
    conn.commit()
    conn.close()
    assert client.post("/profile/Getname", headers=as_user("A")).data == b"Alice"
    assert query(mod, "SELECT firebase_uid FROM users WHERE id = 'row-legacy'") == [
        {"firebase_uid": "A"}
    ]


def test_token_is_verified_once_per_request(mod, client, monkeypatch):
    """A second verification inside the same request used to turn a token
    that expired mid-request into a 500."""
    calls = []

    def verify_then_expire(token, app=None, check_revoked=False, clock_skew_seconds=0):
        calls.append(token)
        if len(calls) > 1:
            raise ValueError("Token expired")
        return dict(TOKENS["A"])

    monkeypatch.setattr(mod.firebase_auth, "verify_id_token", verify_then_expire)
    resp = client.post("/profile/SetFmcToken", json={"Fmc": "x"}, headers=as_user("A"))
    assert resp.status_code == 200
    assert len(calls) == 1


def test_dev_mode_identity_comes_from_token_claims(app_factory):
    """Insecure dev mode reads the uid from the (unverified) JWT payload, so
    the identity survives the client's hourly token refresh."""
    mod = app_factory(insecure=True)
    client = mod.app.test_client()

    def jwt_for(uid, nonce):
        b64 = lambda d: base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b"=").decode()
        return f"{b64({'alg': 'RS256'})}.{b64({'sub': uid, 'iat': nonce})}.sig"

    make_chat(mod, "chat-DC", "dev-uid", "C", [("dev-uid", "hello", None)])
    for nonce in (1, 2):
        resp = client.post("/getMessageFormid", json={"id": "chat-DC"}, headers=as_user(jwt_for("dev-uid", nonce)))
        assert resp.status_code == 200
        assert resp.get_json()[0]["MessageText"] == "hello"
    resp = client.post("/getMessageFormid", json={"id": "chat-DC"}, headers=as_user(jwt_for("other", 3)))
    assert resp.status_code == 403


# ---------------------------------------------------------------------------
# Startup with the real firebase-admin SDK (subprocess, no network)
# ---------------------------------------------------------------------------
def _service_account(tmp_path):
    crypto = pytest.importorskip("cryptography.hazmat.primitives.asymmetric.rsa")
    from cryptography.hazmat.primitives import serialization

    key = crypto.generate_private_key(public_exponent=65537, key_size=2048)
    pem = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    ).decode()
    info = {
        "type": "service_account",
        "project_id": "baata-test",
        "private_key_id": "k1",
        "private_key": pem,
        "client_email": "backend@baata-test.iam.gserviceaccount.com",
        "client_id": "1",
        "token_uri": "https://oauth2.googleapis.com/token",
    }
    path = tmp_path / "service-account.json"
    path.write_text(json.dumps(info))
    return str(path)


def _run_real_sdk(tmp_path, script, extra_env):
    shutil.copy(BACKEND_DIR / "app.py", tmp_path / "app.py")
    env = {k: v for k, v in os.environ.items() if k not in ("BAATA_DEV_INSECURE_AUTH", "FIREBASE_AUTH_EMULATOR_HOST")}
    env.update(
        GOOGLE_APPLICATION_CREDENTIALS=_service_account(tmp_path),
        HTTP_PROXY="http://127.0.0.1:9",
        HTTPS_PROXY="http://127.0.0.1:9",
        NO_PROXY="",
        **extra_env,
    )
    prelude = (
        "import sys\n"
        "try:\n    import firebase_admin\nexcept ImportError:\n    sys.exit(77)\n"
        f"sys.path.insert(0, {str(tmp_path)!r})\n"
    )
    result = subprocess.run(
        [sys.executable, "-c", prelude + script],
        cwd=str(tmp_path),
        env=env,
        capture_output=True,
        text=True,
        timeout=120,
    )
    if result.returncode == 77:
        pytest.skip("real firebase-admin is not installed")
    return result


def test_secure_mode_refuses_to_start_with_auth_emulator_host(tmp_path):
    """With FIREBASE_AUTH_EMULATOR_HOST set, firebase-admin accepts unsigned
    tokens, so 'secure' mode would let anyone pick any uid."""
    now = int(time.time())
    script = (
        "import base64, json\n"
        "import app\n"
        "b64 = lambda d: base64.urlsafe_b64encode(json.dumps(d).encode()).rstrip(b'=').decode()\n"
        "forged = b64({'alg': 'none'}) + '.' + b64({'aud': 'baata-test', "
        "'iss': 'https://securetoken.google.com/baata-test', 'sub': 'VICTIM', "
        f"'iat': {now}, 'exp': {now + 3600}}}) + '.'\n"
        "r = app.app.test_client().post('/profile/Getname', headers={'jwt': forged})\n"
        "print('forged unsigned token ->', r.status_code)\n"
    )
    result = _run_real_sdk(tmp_path, script, {"FIREBASE_AUTH_EMULATOR_HOST": "127.0.0.1:9"})
    assert result.returncode != 0, f"backend started: {result.stdout.strip()}"
    assert "FIREBASE_AUTH_EMULATOR_HOST" in result.stderr


def test_secure_mode_does_not_run_the_debugger(tmp_path):
    """`python app.py` must not expose the Werkzeug debugger on 0.0.0.0."""
    script = (
        "import json, runpy, flask\n"
        "flask.Flask.run = lambda self, *a, **kw: print('RUN', json.dumps(kw))\n"
        f"runpy.run_path({str(tmp_path / 'app.py')!r}, run_name='__main__')\n"
    )
    result = _run_real_sdk(tmp_path, script, {})
    assert result.returncode == 0, result.stderr
    run_line = [line for line in result.stdout.splitlines() if line.startswith("RUN ")]
    assert run_line, result.stdout
    assert json.loads(run_line[0][4:]).get("debug") is False
