# How to Run AURA Mobile on Your Phone

## Prerequisites
1. **Enable Developer Mode** on your Android phone.
2. **Enable USB Debugging** in Developer Options.
3. Connect your phone to your PC via USB.

## Steps

1. **Verify Connection**:
   Open a terminal in the `aura_mobile` directory and run:
   ```bash
   flutter devices
   ```
   You should see your phone listed.

2. **Run the App**:
   Execute the following command:
   ```bash
   flutter run --release
   ```
   *Note: The first build might take a few minutes.*

## Troubleshooting
- **"No devices found"**: proper drivers are installed or try reconnecting the USB cable.
- **Permission Denied**: Accept the USB debugging prompt on your phone screen.

## Features to Test
- **Chat**: Type a message and see the streaming response.
- **Memory**: Type "Remember that I like coffee" and then "What do I like?".
- **Offline Mode**: Turn on Airplane mode and try chatting (Simulated).
