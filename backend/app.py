import os
import io
import json
import uuid
import logging
import sqlite3
from datetime import datetime
from functools import wraps

from flask import Flask, request, jsonify, send_file, send_from_directory, Response
from flask_cors import CORS

# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads")
DB_PATH = os.path.join(BASE_DIR, "baata.db")

os.makedirs(UPLOAD_FOLDER, exist_ok=True)

app = Flask(__name__)
app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER
# Deliberately no MAX_CONTENT_LENGTH: uploads must support any file size and
# are streamed straight to disk with file.save().

CORS(app)  # allow Flutter app (any origin) to call the backend


# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------
def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn


def init_db():
    conn = get_db()
    c = conn.cursor()
    c.execute(
        """
        CREATE TABLE IF NOT EXISTS users (
            id           TEXT PRIMARY KEY,
            jwt_token    TEXT UNIQUE,
            firebase_uid TEXT,
            phone_number TEXT,
            name         TEXT,
            status       TEXT,
            profile_image_path TEXT,
            fcm_token    TEXT,
            created_at   TEXT
        )
        """
    )
    c.execute(
        """
        CREATE TABLE IF NOT EXISTS chats (
            chat_id           TEXT PRIMARY KEY,
            u1                TEXT,
            u2                TEXT,
            n1                TEXT,
            n2                TEXT,
            last_message_time INTEGER,
            unread_u1         INTEGER DEFAULT 0,
            unread_u2         INTEGER DEFAULT 0,
            created_at        TEXT
        )
        """
    )
    c.execute(
        """
        CREATE TABLE IF NOT EXISTS messages (
            id             TEXT PRIMARY KEY,
            chat_id        TEXT,
            sender         TEXT,
            message_time   INTEGER,
            message_text   TEXT,
            is_media       INTEGER DEFAULT 0,
            media_type     TEXT,
            media_path     TEXT,
            thumb_path     TEXT,
            up             TEXT,
            FOREIGN KEY(chat_id) REFERENCES chats(chat_id)
        )
        """
    )
    conn.commit()
    conn.close()


init_db()


# ---------------------------------------------------------------------------
# Auth helpers
# ---------------------------------------------------------------------------
DEV_INSECURE_AUTH_ENV = "BAATA_DEV_INSECURE_AUTH"

try:
    import firebase_admin
    from firebase_admin import auth as firebase_auth
    from firebase_admin import credentials as firebase_credentials
except ImportError:  # firebase-admin is only required outside insecure dev mode
    firebase_admin = None
    firebase_auth = None
    firebase_credentials = None


def _init_firebase_auth():
    """Initialise Firebase Admin SDK ID-token verification.

    Returns True when Firebase token verification is enabled, False when
    running in insecure dev mode (BAATA_DEV_INSECURE_AUTH=1), and refuses to
    start when no credentials are available.
    """
    logging.basicConfig(level=logging.INFO)
    if os.environ.get(DEV_INSECURE_AUTH_ENV) == "1":
        logging.getLogger(__name__).warning(
            "*** BAATA_DEV_INSECURE_AUTH=1: insecure dev auth mode is ON. "
            "Any non-empty token is accepted and no Firebase ID-token "
            "verification happens. Never use this in production. ***"
        )
        return False

    if firebase_admin is None:
        raise SystemExit(
            "firebase-admin is not installed: run 'pip install -r "
            "requirements.txt' (or set BAATA_DEV_INSECURE_AUTH=1 for insecure "
            "local development)."
        )

    cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not cred_path or not os.path.isfile(cred_path):
        raise SystemExit(
            "Baata requires Firebase Admin credentials to verify ID tokens: "
            "point GOOGLE_APPLICATION_CREDENTIALS at a service-account JSON "
            "file (or set BAATA_DEV_INSECURE_AUTH=1 for insecure local "
            "development)."
        )

    firebase_admin.initialize_app(firebase_credentials.Certificate(cred_path))
    return True


FIREBASE_AUTH_ENABLED = _init_firebase_auth()


def verify_firebase_token(token):
    """Verify a Firebase ID token and return its claims, or None when invalid."""
    if firebase_auth is None:
        return None
    try:
        return firebase_auth.verify_id_token(token)
    except Exception:
        logging.getLogger(__name__).warning("Firebase ID-token verification failed")
        return None


def get_jwt():
    """Extract jwt from header, query param, or URL path parameter."""
    jwt = request.headers.get("jwt") or request.args.get("jwt")
    if not jwt:
        jwt = request.view_args.get("jwt") if request.view_args else None
    return jwt


def get_user_by_jwt(create_if_missing=True):
    """Return the user Row for the current request's token.

    With Firebase verification enabled, the token is a Firebase ID token: it
    is verified and the user identity comes from the token's uid (and phone
    number when present). In insecure dev mode the legacy behaviour of keying
    users by the raw token string is kept.
    """
    jwt = get_jwt()
    if not jwt:
        return None

    if FIREBASE_AUTH_ENABLED:
        claims = verify_firebase_token(jwt)
        if claims is None:
            return None
        uid = claims.get("uid") or ""
        phone = claims.get("phone_number") or ""
        if not uid:
            return None
        conn = get_db()
        try:
            row = conn.execute(
                "SELECT * FROM users WHERE firebase_uid = ?", (uid,)
            ).fetchone()
            if row is None and phone:
                row = conn.execute(
                    "SELECT * FROM users WHERE phone_number = ?", (phone,)
                ).fetchone()
            if row is None and create_if_missing:
                user_id = str(uuid.uuid4())
                now = datetime.utcnow().isoformat()
                conn.execute(
                    "INSERT INTO users (id, firebase_uid, phone_number, created_at) "
                    "VALUES (?, ?, ?, ?)",
                    (user_id, uid, phone, now),
                )
                conn.commit()
                row = conn.execute(
                    "SELECT * FROM users WHERE id = ?", (user_id,)
                ).fetchone()
            elif row is not None and not row["firebase_uid"]:
                conn.execute(
                    "UPDATE users SET firebase_uid = ? WHERE id = ?", (uid, row["id"])
                )
            return row
        finally:
            conn.close()

    # Insecure dev mode: legacy behaviour, keyed by the raw token string.
    conn = get_db()
    try:
        row = conn.execute("SELECT * FROM users WHERE jwt_token = ?", (jwt,)).fetchone()
        if row is None and create_if_missing:
            uid = str(uuid.uuid4())
            now = datetime.utcnow().isoformat()
            conn.execute(
                "INSERT INTO users (id, jwt_token, created_at) VALUES (?, ?, ?)",
                (uid, jwt, now),
            )
            conn.commit()
            row = conn.execute("SELECT * FROM users WHERE jwt_token = ?", (jwt,)).fetchone()
        return row
    finally:
        conn.close()


def get_user_by_uid(uid):
    """Look up a user by firebase_uid, phone_number, or internal id."""
    if not uid:
        return None
    conn = get_db()
    try:
        row = (
            conn.execute(
                "SELECT * FROM users WHERE firebase_uid = ? OR phone_number = ? OR id = ?",
                (uid, uid, uid),
            ).fetchone()
        )
        return row
    finally:
        conn.close()


def require_jwt(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        jwt = get_jwt()
        if not jwt:
            return jsonify({"error": "missing jwt"}), 401
        if FIREBASE_AUTH_ENABLED and verify_firebase_token(jwt) is None:
            return jsonify({"error": "invalid token"}), 401
        return f(*args, **kwargs)

    return decorated


# ---------------------------------------------------------------------------
# Placeholder media generation
# ---------------------------------------------------------------------------
def make_placeholder_png(color=(255, 140, 0, 255), size=(200, 200)):
    """Return a small placeholder PNG as bytes (PIL if available, else hardcoded)."""
    try:
        from PIL import Image

        img = Image.new("RGBA", size, color)
        buf = io.BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()
    except Exception:
        # Minimal valid 1x1 orange PNG
        return (
            b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01"
            b"\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\nIDATx\x9cc\xf8\x0f"
            b"\x00\x00\x01\x01\x00\x05\xde\xd4\x00\x00\x00\x00IEND\xaeB`\x82"
        )


PLACEHOLDER_PNG = make_placeholder_png()


def serve_file_or_placeholder(file_path, mimetype):
    if file_path and os.path.isfile(file_path):
        return send_file(file_path, mimetype=mimetype)
    # fallback placeholder
    if mimetype and mimetype.startswith("image"):
        return Response(PLACEHOLDER_PNG, mimetype="image/png")
    return Response(b"", status=200, mimetype=mimetype or "application/octet-stream")


# ---------------------------------------------------------------------------
# Routes
# ---------------------------------------------------------------------------

# 1. POST /profile/uudetails
@app.route("/profile/uudetails", methods=["POST"])
@require_jwt
def profile_uudetails():
    user = get_user_by_jwt(create_if_missing=True)
    if user and user["name"]:
        return jsonify(
            {
                "name": user["name"],
                "phonenumber": user["phone_number"] or "",
                "profileUrl": f"{request.host_url.rstrip('/')}/profile/get/jwt={get_jwt()}&uid={user['id']}",
            }
        )
    # new user
    return jsonify({})


# Bonus: POST /profile/Getname (called by drawer)
@app.route("/profile/Getname", methods=["POST"])
@require_jwt
def profile_getname():
    user = get_user_by_jwt(create_if_missing=True)
    name = user["name"] if (user and user["name"]) else ""
    return Response(name, mimetype="text/plain")


# 2. GET /profile/getMessage/metadata/jwt=$token
@app.route("/profile/getMessage/metadata/jwt=<jwt>", methods=["GET"])
@require_jwt
def profile_get_message_metadata(jwt):
    user = get_user_by_jwt(create_if_missing=True)
    me = user["id"]
    conn = get_db()
    try:
        rows = conn.execute(
            "SELECT * FROM chats WHERE u1 = ? OR u2 = ? ORDER BY last_message_time DESC",
            (me, me),
        ).fetchall()
        result = []
        for r in rows:
            other = r["u2"] if r["u1"] == me else r["u1"]
            other_user = get_user_by_uid(other)
            result.append(
                {
                    "u1": r["u1"],
                    "u2": r["u2"],
                    "n1": r["n1"] or "",
                    "n2": r["n2"] or "",
                    "lastMessageTime": r["last_message_time"] or 0,
                    "unReadMessages": {
                        "u1": r["unread_u1"] or 0,
                        "u2": r["unread_u2"] or 0,
                    },
                }
            )
        return jsonify(result)
    finally:
        conn.close()


# 3. POST /profile/SetFmcToken
@app.route("/profile/SetFmcToken", methods=["POST"])
@require_jwt
def profile_set_fmc_token():
    user = get_user_by_jwt(create_if_missing=True)
    data = request.get_json(silent=True) or {}
    fmc = data.get("Fmc", "")
    conn = get_db()
    try:
        conn.execute("UPDATE users SET fcm_token = ? WHERE id = ?", (fmc, user["id"]))
        conn.commit()
    finally:
        conn.close()
    return "", 200


# 4. GET /profile/get/jwt=$token&uid=$uid
@app.route("/profile/get", methods=["GET"])
@require_jwt
def profile_get():
    uid = request.args.get("uid", "")
    user = get_user_by_uid(uid)
    path = user["profile_image_path"] if user else None
    return serve_file_or_placeholder(path, "image/png")


# 5. POST /profile/upload
@app.route("/profile/upload", methods=["POST"])
@require_jwt
def profile_upload():
    user = get_user_by_jwt(create_if_missing=True)
    if "image" not in request.files:
        return jsonify({"error": "no image"}), 400
    file = request.files["image"]
    ext = file.filename.rsplit(".", 1)[-1] if file.filename and "." in file.filename else "jpg"
    fname = f"profile_{user['id']}_{uuid.uuid4().hex[:8]}.{ext}"
    fpath = os.path.join(UPLOAD_FOLDER, fname)
    file.save(fpath)
    conn = get_db()
    try:
        conn.execute(
            "UPDATE users SET profile_image_path = ? WHERE id = ?", (fpath, user["id"])
        )
        conn.commit()
    finally:
        conn.close()
    return "", 200


# 6. GET /status/get/jwt=$token&uid=$phoneNumber
@app.route("/status/get", methods=["GET"])
@require_jwt
def status_get():
    uid = request.args.get("uid", "")
    user = get_user_by_uid(uid)
    if not user or not user["status"]:
        return Response("Not Found", mimetype="text/plain")
    return jsonify({"status": user["status"], "name": user["name"] or ""})


# 7. GET /contact/get/jwt=$token&pno=$phoneNumber
@app.route("/contact/get", methods=["GET"])
@require_jwt
def contact_get():
    pno = request.args.get("pno", "")
    user = get_user_by_uid(pno)
    path = user["profile_image_path"] if user else None
    return serve_file_or_placeholder(path, "image/png")


# 8. POST /UpdateProfile
@app.route("/UpdateProfile", methods=["POST"])
@require_jwt
def update_profile():
    user = get_user_by_jwt(create_if_missing=True)
    data_raw = request.form.get("data")
    data = json.loads(data_raw) if data_raw else {}

    has_image = data.get("hasImage", False)
    has_name = data.get("hasName", False)
    has_status = data.get("hasStatus", False)
    name = data.get("Name", "")
    status = data.get("Status", "")

    fields = {}
    if has_name:
        fields["name"] = name
    if has_status:
        fields["status"] = status
    if has_image and "image" in request.files:
        file = request.files["image"]
        ext = (
            file.filename.rsplit(".", 1)[-1]
            if file.filename and "." in file.filename
            else "jpg"
        )
        fname = f"profile_{user['id']}_{uuid.uuid4().hex[:8]}.{ext}"
        fpath = os.path.join(UPLOAD_FOLDER, fname)
        file.save(fpath)
        fields["profile_image_path"] = fpath

    if fields:
        set_clause = ", ".join(f"{k} = ?" for k in fields)
        values = list(fields.values()) + [user["id"]]
        conn = get_db()
        try:
            conn.execute(f"UPDATE users SET {set_clause} WHERE id = ?", values)
            conn.commit()
        finally:
            conn.close()

    return "", 200


# 9. GET /GetChatFromUid/uid=$uid
@app.route("/GetChatFromUid/uid=<uid>", methods=["GET"])
@require_jwt
def get_chat_from_uid(uid):
    user = get_user_by_jwt(create_if_missing=True)
    me = user["id"]
    me_firebase = user["firebase_uid"]
    me_ids = {x for x in (me, me_firebase) if x}
    conn = get_db()
    try:
        rows = conn.execute(
            "SELECT * FROM chats WHERE u1 = ? OR u2 = ?", (uid, uid)
        ).fetchall()
        chat = None
        for r in rows:
            other = r["u2"] if r["u1"] == uid else r["u1"]
            if other in me_ids:
                chat = r
                break
        if chat is None:
            return Response("notFound", mimetype="text/plain")
        messages = conn.execute(
            "SELECT * FROM messages WHERE chat_id = ? ORDER BY message_time ASC",
            (chat["chat_id"],),
        ).fetchall()
        msg_list = []
        for m in messages:
            msg_list.append(
                {
                    "Sender": m["sender"],
                    "messageTime": m["message_time"],
                    "MessageText": m["message_text"] or "",
                    "isMedia": bool(m["is_media"]),
                    "MediaType": m["media_type"],
                    "up": m["up"],
                }
            )
        return jsonify({"_id": chat["chat_id"], "messages": msg_list})
    finally:
        conn.close()


# 10. POST /getMessageFormid
@app.route("/getMessageFormid", methods=["POST"])
@require_jwt
def get_message_formid():
    data = request.get_json(silent=True) or {}
    chat_id = data.get("id", "")
    conn = get_db()
    try:
        messages = conn.execute(
            "SELECT * FROM messages WHERE chat_id = ? ORDER BY message_time ASC",
            (chat_id,),
        ).fetchall()
        msg_list = []
        for m in messages:
            msg_list.append(
                {
                    "Sender": m["sender"],
                    "messageTime": m["message_time"],
                    "MessageText": m["message_text"] or "",
                    "isMedia": bool(m["is_media"]),
                    "MediaType": m["media_type"],
                    "up": m["up"],
                }
            )
        return jsonify(msg_list)
    finally:
        conn.close()


# 11. POST /StartMessagingWithNewContact
@app.route("/StartMessagingWithNewContact", methods=["POST"])
@require_jwt
def start_messaging_with_new_contact():
    user = get_user_by_jwt(create_if_missing=True)
    data = request.get_json(silent=True) or {}
    contact_uid = data.get("contactUid", "")
    self_uid = data.get("selfUid", user["id"])
    ismedia = data.get("ismedia", False)
    message_text = data.get("messageText", "")

    me = user["id"]
    # Use selfUid if provided (frontend sends firebase uid), else internal id
    participant_self = self_uid or me

    chat_id = str(uuid.uuid4())
    now = int(datetime.utcnow().timestamp() * 1000)
    n1 = user["name"] or ""
    n2 = ""
    other = get_user_by_uid(contact_uid)
    if other:
        n2 = other["name"] or ""

    # Remember the jwt user's firebase uid so GetChatFromUid can match chats
    conn = get_db()
    try:
        if self_uid:
            conn.execute(
                "UPDATE users SET firebase_uid = ? WHERE id = ?", (self_uid, me)
            )
        conn.execute(
            "INSERT INTO chats (chat_id, u1, u2, n1, n2, last_message_time, created_at) "
            "VALUES (?, ?, ?, ?, ?, ?, ?)",
            (chat_id, participant_self, contact_uid, n1, n2, now, datetime.utcnow().isoformat()),
        )
        if message_text:
            msg_id = str(uuid.uuid4())
            conn.execute(
                "INSERT INTO messages (id, chat_id, sender, message_time, message_text, is_media) "
                "VALUES (?, ?, ?, ?, ?, ?)",
                (msg_id, chat_id, participant_self, now, message_text, 1 if ismedia else 0),
            )
            conn.execute(
                "UPDATE chats SET last_message_time = ? WHERE chat_id = ?", (now, chat_id)
            )
        conn.commit()
    finally:
        conn.close()

    return Response(chat_id, mimetype="text/plain")


# 12. POST /postMessageToId
@app.route("/postMessageToId", methods=["POST"])
@require_jwt
def post_message_to_id():
    data = request.get_json(silent=True) or {}
    chat_id = data.get("id", "")
    sender = data.get("Sender", "")
    message_time = data.get("messageTime", int(datetime.utcnow().timestamp() * 1000))
    message_text = data.get("MessageText", "")
    is_media = 1 if data.get("isMedia", False) else 0

    conn = get_db()
    try:
        chat = conn.execute("SELECT * FROM chats WHERE chat_id = ?", (chat_id,)).fetchone()
        if chat is None:
            # create the chat on the fly
            conn.execute(
                "INSERT INTO chats (chat_id, u1, u2, n1, n2, last_message_time, created_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                (chat_id, sender, "", "", "", message_time, datetime.utcnow().isoformat()),
            )
        msg_id = str(uuid.uuid4())
        conn.execute(
            "INSERT INTO messages (id, chat_id, sender, message_time, message_text, is_media) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (msg_id, chat_id, sender, message_time, message_text, is_media),
        )
        conn.execute(
            "UPDATE chats SET last_message_time = ? WHERE chat_id = ?",
            (message_time, chat_id),
        )
        conn.commit()
    finally:
        conn.close()
    return "", 200


# 13. POST /PostImageToId
@app.route("/PostImageToId", methods=["POST"])
@require_jwt
def post_image_to_id():
    return _post_media_to_id("image", "Image")


# 14. POST /PostVideoToId
@app.route("/PostVideoToId", methods=["POST"])
@require_jwt
def post_video_to_id():
    return _post_media_to_id("video", "Video")


def _post_media_to_id(field_name, media_type):
    data_raw = request.form.get("data")
    data = json.loads(data_raw) if data_raw else {}
    chat_id = data.get("id", "")
    sender = data.get("Sender", "")
    message_time = data.get("messageTime", int(datetime.utcnow().timestamp() * 1000))
    message_text = data.get("MessageText", "")

    if field_name not in request.files:
        return jsonify({"error": "no media file"}), 400
    file = request.files[field_name]
    ext = file.filename.rsplit(".", 1)[-1] if file.filename and "." in file.filename else "bin"
    fname = f"msg_{chat_id}_{uuid.uuid4().hex[:8]}.{ext}"
    fpath = os.path.join(UPLOAD_FOLDER, fname)
    file.save(fpath)

    conn = get_db()
    try:
        chat = conn.execute("SELECT * FROM chats WHERE chat_id = ?", (chat_id,)).fetchone()
        if chat is None:
            conn.execute(
                "INSERT INTO chats (chat_id, u1, u2, n1, n2, last_message_time, created_at) "
                "VALUES (?, ?, ?, ?, ?, ?, ?)",
                (chat_id, sender, "", "", "", message_time, datetime.utcnow().isoformat()),
            )
        msg_id = str(uuid.uuid4())
        conn.execute(
            "INSERT INTO messages (id, chat_id, sender, message_time, message_text, is_media, media_type, media_path) "
            "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (msg_id, chat_id, sender, message_time, message_text, 1, media_type, fpath),
        )
        conn.execute(
            "UPDATE chats SET last_message_time = ? WHERE chat_id = ?",
            (message_time, chat_id),
        )
        conn.commit()
    finally:
        conn.close()
    return "", 200


# 15. GET /messageVideo/id=$messageId&i=$index
@app.route("/messageVideo", methods=["GET"])
@require_jwt
def message_video():
    return _message_media("video/mp4")


# 16. GET /getVidThumb/id=$messageId&idx=$index
@app.route("/getVidThumb", methods=["GET"])
@require_jwt
def get_vid_thumb():
    return _message_media("image/png", thumb=True)


# 17. GET /messageimage/id=$messageId&i=$index
@app.route("/messageimage", methods=["GET"])
@require_jwt
def message_image():
    return _message_media("image/png")


def _message_media(default_mimetype, thumb=False):
    message_id = request.args.get("id", "")
    index = request.args.get("i", request.args.get("idx", "0"))
    try:
        index = int(index)
    except ValueError:
        index = 0

    conn = get_db()
    try:
        chat = conn.execute("SELECT * FROM chats WHERE chat_id = ?", (message_id,)).fetchone()
        if chat is None:
            return serve_file_or_placeholder(None, default_mimetype)
        messages = conn.execute(
            "SELECT * FROM messages WHERE chat_id = ? ORDER BY message_time ASC",
            (message_id,),
        ).fetchall()
        if index < 0 or index >= len(messages):
            return serve_file_or_placeholder(None, default_mimetype)
        m = messages[index]
        path = m["thumb_path"] if thumb else m["media_path"]
        mimetype = default_mimetype
        if m["media_type"] == "Video":
            mimetype = "video/mp4" if not thumb else "image/png"
        elif m["media_type"] == "Image":
            mimetype = "image/png"
        return serve_file_or_placeholder(path, mimetype)
    finally:
        conn.close()


# ---------------------------------------------------------------------------
# Run
# ---------------------------------------------------------------------------
if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True, threaded=True)
