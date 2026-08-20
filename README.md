# Sky Map App

This is a beautiful, interactive Flutter mobile application that provides users with a 60fps Augmented Reality map of the night sky. Point your phone at the sky (or the ground!) to discover planets, stars, and galaxies right where they actually are in real life.

## How It Works

### Augmented Reality Tracking
The app determines your location using the device's **GPS**. It then uses the device's **accelerometer** and **magnetometer** to calculate the real-time pitch, roll, and yaw of your device. 
To ensure a buttery smooth experience without jitter, the app samples the sensors at 60Hz and applies a finely-tuned exponential moving average (EMA) filter. The screen rendering is decoupled from the state manager (BLoC) using a dedicated `ValueNotifier`, allowing the 3D projection to update instantly at 60 frames per second as you pan your phone around.

### Celestial Mechanics
Using this orientation and location data, the app implements **Keplerian Orbital Mechanics** calculated from the J2000 epoch to find the exact Heliocentric and Geocentric coordinates of the Sun, Moon, and Planets. The 3D equatorial coordinates (Right Ascension and Declination) are then mathematically projected into horizontal coordinates (Altitude and Azimuth) based on your exact longitude, latitude, and current UTC time. 

The app features a 360-degree rendering sphere. If a planet is currently below the horizon (on the other side of the Earth), you can simply point your phone down at the floor to find it!

## Celestial Objects Displayed

- **The Sun** and **The Moon**
- **All 8 Planets**: Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune
- **Deep Sky Objects & Famous Stars**: The Andromeda Galaxy (M31), Orion Nebula (M42), Pleiades (M45), Sirius, Betelgeuse, and Polaris (The North Star).
- **Constellations**: The app reads a local data file (`assets/constellations.json`) which defines the Right Ascension and Declination of major stars, and the lines connecting them. The app dynamically projects these 2D lines onto the 3D viewing sphere, allowing you to trace out Orion, Ursa Major, Cassiopeia, and more.

## Wikipedia Summary API

When you tap on any highlighted object (Planet, Star, or Galaxy), the app fetches real-time data using the **Wikipedia Summary API** (`https://en.wikipedia.org/api/rest_v1/page/summary/`). 
This provides a rich, highly accurate description of the celestial body. Since the API is completely open and public, it requires no authentication or API keys, ensuring it works flawlessly out of the box.

*(Note: Earlier iterations of this app used the `le-systeme-solaire` API. A `.env` file is still supported if you wish to expand the app with authenticated APIs in the future).*

## Architecture

The application uses the **BLoC pattern** (`flutter_bloc`) to manage its state architecture. The BLoC is responsible for:
1. Connecting to the GPS and acquiring the initial position.
2. Managing the heavy lifting of calculating J2000 orbital mechanics in the background.
3. Loading the local `constellations.json` file.
4. Hooking into the Android/iOS hardware sensors and running the low-pass filters.

## How to Run the Project

1. **Install Flutter**: Make sure you have Flutter installed on your machine.
2. **Initialize Platform Code** (If `android`/`ios` folders are missing):
   Open a terminal in the `sky-map` directory and run:
   ```bash
   flutter create .
   ```
3. **Get Dependencies**:
   ```bash
   flutter pub get
   ```
4. **Permissions Configuration**:
   Ensure you have the required location permissions set up in your platform folders:
   *   **Android**: Ensure `android/app/src/main/AndroidManifest.xml` has:
       `<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />`
       `<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />`
   *   **iOS**: Ensure `ios/Runner/Info.plist` has `NSLocationWhenInUseUsageDescription`.
5. **Run the App**:
   Run the app on a **physical device** (emulators do not have accurate accelerometer/magnetometer sensors):
   ```bash
   flutter run
   ```

## Controls
- **Look Around:** Move your phone around in 3D space to look at different parts of the sky. Point it down to see what's below the horizon!
- **Discover:** **Tap** on any highlighted planet, star, or galaxy to open an information sheet and read its Wikipedia summary.
