# Masjid Namaz App - Setup (Roman Urdu)

## Step 1: Firebase (backend) - 10 minute
1. https://console.firebase.google.com par jayein, **Add project** karein.
2. **Build > Realtime Database > Create database** (test mode nahi, locked mode chunein).
3. **Rules** tab mein ye paste karke Publish karein (ADMIN_EMAIL ki jagah apni admin email likhein):
```json
{
  "rules": {
    ".read": true,
    ".write": "auth != null && auth.token.email == 'ADMIN_EMAIL'"
  }
}
```
4. **Build > Authentication > Sign-in method > Email/Password** enable karein.
5. **Users > Add user**: wohi ADMIN_EMAIL aur password banayein (ye masjid committee ka login hai).
6. **Project settings > General > Your apps > Web (</>)**: app register karke `firebaseConfig` copy karein.

## Step 2: Config bharein
- `lib/main.dart` mein `dbUrl` ki line badlein (Realtime Database page par URL milega, aakhir mein `/masjid.json` rakhein).
- `admin/index.html` mein `firebaseConfig` paste karein.

## Step 3: APK banayein (Android Studio ke baghair)
1. GitHub par naya repository banayein aur ye poora folder upload/push karein.
2. **Actions** tab > **Build APK** > **Run workflow**.
3. 5-8 minute baad run khol kar neeche **Artifacts > masjid-app-apk** download karein. Us mein `app-release.apk` hoga.
4. Phone mein APK install karein (Unknown sources allow karna hoga).

## Step 4: Admin panel (timings badalna)
- `admin/index.html` ko **Firebase Hosting** par daalein (`firebase deploy`), ya kisi bhi free hosting par.
- Local test ke liye: `cd admin && python3 -m http.server 8000`, phir http://localhost:8000
- Login karein, timings / donation details badlein, **Save** dabayein. App mein pull-to-refresh ya dobara kholne par update ho jati hai.

## Notes
- Reminder har namaz se 15 minute pehle aata hai, Jumma ka sirf Friday ko.
- Kuch phones (Xiaomi, Oppo, Vivo, Samsung) battery saver notifications rok dete hain. App ko "Unrestricted / No battery restrictions" par set karein.
- Play Store par dalne ke liye apni signing key banani hogi. Seedhe APK share karne ke liye ye zaroori nahi.
