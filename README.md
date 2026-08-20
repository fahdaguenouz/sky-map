# Sky Map App

This is a Flutter mobile application that provides users with an interactive map of the night sky, fulfilling the requirements of the Sky Map project.

## How It Works

The app determines your location using the device's **GPS** and uses the **accelerometer** and **magnetometer** to calculate the real-time pitch, roll, and yaw of your device. 

Using this orientation data, it calculates the horizontal coordinates (Altitude and Azimuth) of celestial bodies using the `astronomy` package, which accurately tracks the Sun, Moon, and Planets. The 3D coordinates are then mapped to 2D screen coordinates using spherical projection. The screen updates at least 10 times per second to provide a smooth, real-time representation of the sky as you move your phone around.

The application uses the **BLoC pattern** (`flutter_bloc`) to manage state effectively. The BLoC is responsible for listening to sensor streams, fetching API data, and recalculating the positions of celestial objects continuously.

## Celestial Objects Displayed

- **The Sun** and **The Moon** (accurate positions)
- **All planets of the solar system** (Mercury, Venus, Mars, Jupiter, Saturn, Uranus, Neptune)
- **Constellations**: Orion, Ursa Major, and Cassiopeia. These are loaded from `assets/constellations.json` which acts as a valid local data file.

## API Usage and `.env` File

This project utilizes the **Solar System OpenData API** (`https://api.le-systeme-solaire.net`) to retrieve detailed information (such as mass, density, and naming) about planets and the Sun when tapped.

To securely manage the API base URL, this project uses a `.env` file (loaded via `flutter_dotenv`).

**What to put in your `.env` file:**
Create a `.env` file in the root of the project with the following content:
```env
SOLAR_SYSTEM_API_URL=https://api.le-systeme-solaire.net/rest/bodies
```
Since this specific API does not require an authentication key, only the base URL is stored here. However, this pattern allows you to easily drop in an `API_KEY` environment variable in the future if you migrate to a more restricted API.

## How to Run the Project

> **Note:** If you only have the source files (`lib/`, `pubspec.yaml`, `assets/`, `.env`), you need to generate the Flutter platform code first.

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
   Run the app on a physical device (emulators may not have accurate accelerometer/magnetometer sensors):
   ```bash
   flutter run
   ```

## Controls
- Move your phone around to look at different parts of the sky.
- **Tap** on any visible planet, the Sun, or the Moon to retrieve its short description from the Solar System API.
