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
  not found. Tokens are verified with the Firebase Admin SDK and the user
  identity is taken from the verified token's `uid` and `phone_number`.

* **Local development (insecure).** Set `BAATA_DEV_INSECURE_AUTH=1` to skip
  Firebase verification. Any non-empty token is accepted (legacy behaviour)
  and the backend logs a loud warning at startup. Never use this mode in
  production.

# Built With

* Flutter
* Firebase
* Python
* MongoDb
* nginx
* Flask
* OpenCV

# Download the latest version of Baata and experience seamless messaging today!