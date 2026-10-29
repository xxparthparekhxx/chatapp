# Baata: A Real-time Communication App
## Features:
* Send and receive real-time messages and multimedia files without size limitations
* Cloud storage for all messages and files
* Available for download at baata.ml

## Backend authentication

The Flask backend verifies Firebase ID tokens sent by the Flutter client
(the `jwt` header). Install backend dependencies with:

```
pip install -r backend/requirements.txt
```

Two modes are supported:

* **Production (token verification on).** Point
  `GOOGLE_APPLICATION_CREDENTIALS` at a Firebase service-account JSON file:

  ```
  export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
  ```

  The backend refuses to start if the credentials are missing or the file is
  not found, or if `FIREBASE_AUTH_EMULATOR_HOST` is set (firebase-admin then
  accepts unsigned tokens). Tokens are verified with the Firebase Admin SDK
  and the user identity is taken from the verified token's `uid` and
  `phone_number`. The Flask debugger is off in this mode.

* **Local development (insecure).** Set `BAATA_DEV_INSECURE_AUTH=1` (exactly
  `1`) to skip Firebase verification. Any non-empty token is accepted: the
  uid is read from the token's payload without checking its signature, or
  the whole token string is used as the uid when it is not a JWT. The
  backend logs a loud warning at startup and runs with the Flask debugger
  on. Never use this mode in production.

The token is the only source of identity. Request fields such as `selfUid`
or `Sender` are ignored: chats are created and messages are sent as the
token's uid. Chat messages and chat media can only be read or posted by the
chat's two participants. A missing or invalid token gets `401`, a chat the
caller is not part of gets `403`, and an unknown chat id gets `404`.
Profile name, status and photo stay readable by any signed-in user, so the
contact list can show them. Uploaded files are stored under server-chosen
names and are only served through these routes.

# Built With

* Flutter
* Firebase
* Python
* MongoDb
* nginx
* Flask
* OpenCV

# Download the latest version of Baata and experience seamless messaging today!