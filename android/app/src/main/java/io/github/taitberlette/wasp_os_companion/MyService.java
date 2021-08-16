package io.github.taitberlette.wasp_os_companion;

import android.Manifest;
import android.app.IntentService;
import android.bluetooth.le.BluetoothLeScanner;
import android.bluetooth.le.ScanCallback;
import android.bluetooth.le.ScanResult;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.media.AudioManager;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.SystemClock;
import android.provider.ContactsContract;
import android.telecom.TelecomManager;
import android.telephony.TelephonyManager;
import android.view.KeyEvent;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCallback;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.BluetoothProfile;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationCompat;

import android.util.Log;

import com.androidnetworking.AndroidNetworking;
import com.androidnetworking.common.ANRequest;
import com.androidnetworking.common.Priority;
import com.androidnetworking.error.ANError;
import com.androidnetworking.interfaces.JSONArrayRequestListener;
import com.androidnetworking.interfaces.JSONObjectRequestListener;
import com.androidnetworking.interfaces.StringRequestListener;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.UnsupportedEncodingException;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.Calendar;
import java.util.Date;
import java.util.List;
import java.util.UUID;
import java.util.Vector;

import static androidx.core.app.ActivityCompat.startActivityForResult;

public class MyService extends IntentService {

    private static BluetoothManager bleManager;
    private static BluetoothAdapter bleAdapter;
    private static BluetoothLeScanner bleScanner;
    private static String bleDeviceAddress;
    private static BluetoothGatt bleGatt;
    public static int connectionState = 0;

    public final static UUID uartServiceUUID = UUID.fromString("6e400001-b5a3-f393-e0a9-e50e24dcca9e");
    public final static UUID uartRXUUID = UUID.fromString("6e400002-b5a3-f393-e0a9-e50e24dcca9e");
    public final static UUID uartTXUUID = UUID.fromString("6e400003-b5a3-f393-e0a9-e50e24dcca9e");
    public final static UUID cccdUUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");

    public static BluetoothGattService uartService;

    public static BluetoothGattCharacteristic uartRX;
    public static BluetoothGattCharacteristic uartTX;
    public static BluetoothGattDescriptor cccd;

    public static Vector<String> commandList = new Vector<String>();

    public static String commandText = "";
    public static String responseText = "";
    public static String actionText = "";

    public static boolean responseWaiting = false;
    public static boolean haltCommands = false;

    public static byte[] currentPacket = new byte[0];
    public static byte[] sentPacket = new byte[0];

    public static String nowPlayingArtist = "";
    public static String nowPlayingAlbum = "";
    public static String nowPlayingTrack = "";

    public static String nowCallingNumber = "";
    public static String nowCallingName = "";

    public static int lastNotificationId = -1;

    public static String[] quickRing = new String[0];
    public static String[] launcherRing = new String[0];

    PhoneReceiver phoneReceiver;
    MediaReceiver mediaReceiver;
    NotificationReceiver notificationReceiver;


    public static boolean scanning = false;
    public static boolean foundDevice = false;

    private ScanCallback leScanCallback = new ScanCallback() {
        @Override
        public void onScanResult(int callbackType, ScanResult result) {
            super.onScanResult(callbackType, result);
            String name = result.getDevice().getName();
            String address = result.getDevice().getAddress();
            if (foundDevice || name == null) {
                return;
            }
            if (name.equals("PineTime") || name.equals("P8") || name.equals("K9")) {
                foundDevice = true;
                connectToWatch(address, name);
            }
        }
    };

    private Handler handler = new Handler();

    public final BluetoothGattCallback gattCallback = new BluetoothGattCallback() {
        @Override
        public void onConnectionStateChange(BluetoothGatt gatt, int status, int newState) {

            super.onConnectionStateChange(gatt, status, newState);
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                connectionState = 2;

                gatt.discoverServices();

                bleGatt = gatt;


                if (phoneReceiver == null) {

                    IntentFilter phoneFilter = new IntentFilter();
                    phoneFilter.addAction("android.intent.action.PHONE_STATE");
                    phoneReceiver = new PhoneReceiver();
                    registerReceiver(phoneReceiver, phoneFilter);

                }
                if (mediaReceiver == null) {
                    IntentFilter mediaFilter = new IntentFilter();
                    mediaFilter.addAction("com.android.music.metachanged");
                    mediaFilter.addAction("com.android.music.playstatechanged");
                    mediaFilter.addAction("com.android.music.playbackcomplete");
                    mediaFilter.addAction("com.android.music.queuechanged");
                    mediaFilter.addAction("fm.last.android.metachanged");
                    mediaFilter.addAction("com.sec.android.app.music.metachanged");
                    mediaFilter.addAction("com.nullsoft.winamp.metachanged");
                    mediaFilter.addAction("com.amazon.mp3.metachanged");
                    mediaFilter.addAction("com.miui.player.metachanged");
                    mediaFilter.addAction("com.real.IMP.metachanged");
                    mediaFilter.addAction("com.sonyericsson.music.metachanged");
                    mediaFilter.addAction("com.rdio.android.metachanged");
                    mediaFilter.addAction("com.samsung.sec.android.MusicPlayer.metachanged");
                    mediaFilter.addAction("com.andrew.apollo.metachanged");
                    mediaFilter.addAction("com.spotify.music.metadatachanged");
                    mediaReceiver = new MediaReceiver();
                    registerReceiver(mediaReceiver, mediaFilter);
                }
                if (notificationReceiver == null) {
                    IntentFilter notificationFilter = new IntentFilter();
                    notificationFilter.addAction("io.github.taitberlette.wasp_os_companion.notificationEvent");
                    notificationReceiver = new NotificationReceiver();
                    registerReceiver(notificationReceiver, notificationFilter);
                }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                connectionState = 0;

                broadcastUpdate("io.github.taitberlette.wasp_os_companion.watchDisconnected");

                unregisterReceiver(phoneReceiver);
                unregisterReceiver(mediaReceiver);
                unregisterReceiver(notificationReceiver);

                phoneReceiver = null;
                mediaReceiver = null;
                notificationReceiver = null;

                responseWaiting = false;
                haltCommands = false;
                responseText = "";
                commandText = "";
                actionText = "";
                commandList.clear();
                currentPacket = new byte[0];
                sentPacket = new byte[0];
                lastNotificationId = -1;
                nowPlayingArtist = "";
                nowPlayingAlbum = "";
                nowPlayingTrack = "";
                uartService = null;
                uartRX = null;
                uartTX = null;
                cccd = null;
            }
        }

        @Override
        public void onServicesDiscovered(BluetoothGatt gatt, int status) {
            super.onServicesDiscovered(gatt, status);
            if (status == BluetoothGatt.GATT_SUCCESS) {

                uartService = gatt.getService(uartServiceUUID);
                uartRX = uartService.getCharacteristic(uartRXUUID);
                uartTX = uartService.getCharacteristic(uartTXUUID);
                cccd = uartTX.getDescriptor(cccdUUID);

                boolean canNotify = (uartTX.getProperties() & BluetoothGattCharacteristic.PROPERTY_NOTIFY) > 0;
                boolean canIndicate = (uartTX.getProperties() & BluetoothGattCharacteristic.PROPERTY_INDICATE) > 0;
                byte[] notifyType = new byte[0];

                if (canIndicate) {
                    notifyType = BluetoothGattDescriptor.ENABLE_INDICATION_VALUE;
                }
                if (canNotify) {
                    notifyType = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE;
                }

                bleGatt.setCharacteristicNotification(uartTX, true);
                cccd.setValue(notifyType);
                bleGatt.writeDescriptor(cccd);

                responseWaiting = false;
                haltCommands = false;
                responseText = "";
                commandText = "";
                actionText = "";
                commandList.clear();
                currentPacket = new byte[0];
                sentPacket = new byte[0];
                lastNotificationId = -1;
                nowPlayingArtist = "";
                nowPlayingAlbum = "";
                nowPlayingTrack = "";

            } else {
                bleGatt.disconnect();
                broadcastUpdate("io.github.taitberlette.wasp_os_companion.watchDisconnected");
            }
        }

        @Override
        public void onDescriptorWrite(BluetoothGatt gatt, BluetoothGattDescriptor descriptor, int status) {
            super.onDescriptorWrite(gatt, descriptor, status);

            connectionState = 3;

            broadcastUpdate("io.github.taitberlette.wasp_os_companion.watchConnected", bleGatt.getDevice().getName(), bleGatt.getDevice().getAddress());
            backgroundSync();
        }

        @Override
        public void onCharacteristicChanged(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic) {
            super.onCharacteristicChanged(gatt, characteristic);
            try {

                if (characteristic.getUuid().equals(uartTXUUID)) {
                    String text = new String(uartTX.getValue());


                    broadcastUpdate("io.github.taitberlette.wasp_os_companion.watchUart", text);
                    if (responseWaiting) {
                        if (text.trim().startsWith(">>>") || text.trim().startsWith("...")) {
                            responseText = responseText.replace(commandText.trim(), "");
                            if (responseText.trim() != "") {
                                handleResponse(commandText, responseText);
                            }
                            commandText = "";
                            responseText = "";
                            responseWaiting = false;
                            if (commandList.toArray().length >= 1) {
                                writeData(commandList.get(0));
                                commandList.remove(0);
                            }
                        } else {
                            responseText += text;
                        }
                    } else {

                        if (!haltCommands) {
                            haltCommands = true;
                            actionText = "";
                        }

                        if (text.equals("\n") && actionText.trim() != "") {

                            actionText = actionText.trim();
                            actionText = actionText.replaceAll("None", "null");
                            actionText = actionText.replaceAll("True", "true");
                            actionText = actionText.replaceAll("False", "false");

                            handleCommand(actionText);
                            actionText = "";
                            haltCommands = false;
                        } else if (text != "\r") {
                            actionText += text;
                        }
                    }
                }
            } catch (Exception e) {

            }
        }

        @Override
        public void onCharacteristicWrite(BluetoothGatt gatt, BluetoothGattCharacteristic characteristic, int status) {
            super.onCharacteristicWrite(gatt, characteristic, status);
            if (characteristic.getUuid().equals(uartRXUUID)) {
                try {
                    if (status != BluetoothGatt.GATT_SUCCESS) {
                        writeBytes(sentPacket, uartRX, bleGatt);
                        return;
                    }
                    if (currentPacket.length > 0) {
                        sendChunk(currentPacket);
                    }
                } catch (Exception e) {

                }
            }
        }
    };

    private void scanForWatch() {
        if (bleAdapter == null) {
            return;
        }
        if (!scanning) {
            foundDevice = false;
            handler.postDelayed(new Runnable() {
                                    @Override
                                    public void run() {
                                        scanning = false;
                                        bleScanner.stopScan(leScanCallback);
                                        if (foundDevice == false) {
                                            broadcastUpdate("io.github.taitberlette.wasp_os_companion.watchDisconnected");
                                        }
                                    }
                                },
                    5000);

            scanning = true;
            bleScanner.startScan(leScanCallback);
        } else {
            scanning = false;
            bleScanner.stopScan(leScanCallback);
            broadcastUpdate("io.github.taitberlette.wasp_os_companion.watchDisconnected");
        }
    }

    private void connectToWatch(String address, String name) {
        if (bleAdapter == null || address == null) {
            return;
        }

        broadcastUpdate("io.github.taitberlette.wasp_os_companion.watchConnecting", name);

        // Previously connected device.  Try to reconnect.
        if (address.equals(bleDeviceAddress) && bleGatt != null) {

            if (bleGatt.connect()) {
                connectionState = 1;
                return;

            } else {
                return;
            }
        }

        final BluetoothDevice device = bleAdapter.getRemoteDevice(address);

        if (device == null) {
            return;
        }

        // We want to directly connect to the device, so we are setting the autoConnect
        // parameter to false.
        bleGatt = device.connectGatt(this, true, gattCallback);
        bleDeviceAddress = address;
        connectionState = 1;
    }

    private void disconnectFromWatch() {
        if (bleAdapter == null || bleGatt == null) {
            return;
        }
        foundDevice = true;
        bleGatt.disconnect();
    }

    public void writeData(String data) {

        if (connectionState != 3) {
            return;
        }

        if (responseWaiting || haltCommands) {
            commandList.add(data);
            return;
        }

        responseWaiting = true;
        commandText = data;
        responseText = "";

        data += "\r";

        byte[] bytes = new byte[0];
        try {
            bytes = data.getBytes("UTF8");
        } catch (UnsupportedEncodingException e) {
            e.printStackTrace();
        }

        sendChunk(bytes);
    }

    private void sendChunk(byte[] data) {
        if (connectionState != 3) {
            return;
        }

        if (data.length == 0) {
            return;
        }

        sentPacket = Arrays.copyOfRange(data, 0, Math.min(data.length, 20));

        if (data.length > 20) {
            currentPacket = Arrays.copyOfRange(data, 20, data.length);
        } else {
            currentPacket = new byte[0];
        }

        writeBytes(sentPacket, uartRX, bleGatt);

    }

    public void writeBytes(byte[] data, BluetoothGattCharacteristic characteristic, BluetoothGatt gatt) {
        characteristic.setValue(data);
        characteristic.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT);
        gatt.writeCharacteristic(characteristic);
    }

    public void initialize() {

        if (bleManager == null) {
            bleManager = (BluetoothManager) getSystemService(Context.BLUETOOTH_SERVICE);

            if (bleManager == null) {
                return;
            }
        }

        bleAdapter = bleManager.getAdapter();
        bleScanner = BluetoothAdapter.getDefaultAdapter().getBluetoothLeScanner();

    }

    public void backgroundSync() {
        if (connectionState == 3) {

            Date now = Calendar.getInstance().getTime();

            int year = now.getYear() + 1900;
            int month = now.getMonth() + 1;
            int date = now.getDate();
            int hour = now.getHours();
            int minute = now.getMinutes();
            int second = now.getSeconds();

            String currentTime = "watch.rtc.set_localtime((" + year + ", " + month + ", " + date + ", " + hour + ", " + minute + ", " + second + "))";
            writeData(currentTime);

            AndroidNetworking.get("https://wasp-os-companion.glitch.me/api/app/weather").setPriority(Priority.HIGH).build().getAsString(new StringRequestListener() {
                @Override
                public void onResponse(String response) {
                    //this is currently just to help me pass the data easier, I'll probably change this in the future.
                    response += "END";
                    writeData("wasp.system.weatherinfo = {\"type\": \"weather\", "+response.replace("{\"error\":false,\"data\":{", "").replace("}END", ""));
                }

                @Override
                public void onError(ANError anError) {

                }
            });
        }
    }

    public void handleCommand(String command) {
        command = command.replace("\r", "");
        command = command.replace("\n", "");
        command = command.replace("True", "true");
        command = command.replace("False", "false");
        command = command.replace("None", "null");
        command = command.trim();
        if (command.equals("")) {
            return;
        }

        JSONObject json;
        try {
            json = new JSONObject(command);
        } catch(JSONException e) {
            return;
        }

        String action = "";

        try {
            action = json.getString("t");
        } catch(Exception e) {}

        try {
            if (action.equals("music")) {
                String info = json.getString("n");
                switch (info) {
                    case "play":
                        playTrack();
                        break;
                    case "pause":
                        pauseTrack();
                        break;
                    case "volumedown":
                        volDown();
                        break;
                    case "volumeup":
                        volUp();
                        break;
                    case "next":
                        nextTrack();
                        break;
                    case "previous":
                        lastTrack();
                        break;
                }
            } else if(action.equals("call")){
                String cmd = json.getString("n");
                switch(cmd.toLowerCase()){
                    case "accept":
                    case "start":
                        acceptCall();
                        break;
                    case "reject":
                    case "end":
                        rejectCall();
                        break;
                    case "ignore":
                        //do nothing
                        break;
                }

            }else if (action.equals("fetch")) {
                String method = json.getString("m");
                String url = json.getString("u");
                String app = json.getString("a");

                if (appPath(app, 2).equals("")) {
                    return;
                }

                switch (method) {
                    case "post":
                        AndroidNetworking.post(url).setPriority(Priority.HIGH).build().getAsString(networkResponse(app));
                        break;
                    case "put":
                        AndroidNetworking.put(url).setPriority(Priority.HIGH).build().getAsString(networkResponse(app));
                        break;
                    case "patch":
                        AndroidNetworking.patch(url).setPriority(Priority.HIGH).build().getAsString(networkResponse(app));
                        break;
                    case "delete":
                        AndroidNetworking.delete(url).setPriority(Priority.HIGH).build().getAsString(networkResponse(app));
                        break;
                    case "head":
                        AndroidNetworking.head(url).setPriority(Priority.HIGH).build().getAsString(networkResponse(app));
                        break;
                    case "options":
                        AndroidNetworking.options(url).setPriority(Priority.HIGH).build().getAsString(networkResponse(app));
                        break;
                    default:
                        AndroidNetworking.get(url).setPriority(Priority.HIGH).build().getAsString(networkResponse(app));
                        break;
                }
            }
        } catch(Exception e) {}

        broadcastUpdate("io.github.taitberlette.wasp_os_companion.watchCommand", command);

    }

    public String appPath(String appPackage, int ring) {
        String path = "";
        if (ring == 0) {
            for (int i = 0; i < quickRing.length; i++) {
                if (quickRing[i].equals(appPackage)) {
                    path = "wasp.system.quick_ring[" + i + "]";
                }
            }
        } else if (ring == 1) {
            for (int i = 0; i < launcherRing.length; i++) {
                if (launcherRing[i].equals(appPackage)) {
                    path = "wasp.system.launcher_ring[" + i + "]";
                }
            }
        } else {
            for (int i = 0; i < quickRing.length; i++) {
                if (quickRing[i].equals(appPackage)) {
                    path = "wasp.system.quick_ring[" + i + "]";
                }
            }
            for (int i = 0; i < launcherRing.length; i++) {
                if (launcherRing[i].equals(appPackage)) {
                    path = "wasp.system.launcher_ring[" + i + "]";
                }
            }
        }

        return path;
    }

    public void parseRing(String ring, int type) {
        ring = ring.replaceAll("(<|>|object at )", "");
        ring = ring.replace("[", "");
        ring = ring.replace("]", "");

        String[] ringApps = ring.split(", ");
        for (int i = 0; i < ringApps.length; i++) {
            ringApps[i] = ringApps[i].split(" ")[0].trim();
        }

        if (type == 0) {
            quickRing = ringApps;
        } else if (type == 1) {
            launcherRing = ringApps;
        }

    }

    public void handleResponse(String command, String response) {

        if (command.trim().equals("wasp.system.quick_ring")) {
            parseRing(response, 0);
        }
        if (command.trim().equals("wasp.system.launcher_ring")) {
            parseRing(response, 1);
        }

        broadcastUpdate("io.github.taitberlette.wasp_os_companion.watchResponse", response, command);
    }

    public MyService() {
        super("MyService");
    }

    @Override
    public void onCreate() {
        super.onCreate();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationCompat.Builder builder = new NotificationCompat.Builder(this, "messages");
            builder.setContentText("wasp-os companion is running in the background.");
            builder.setContentTitle("wasp-os companion");
            builder.setSmallIcon(R.drawable.icon);
            startForeground(1, builder.build());
        }

        AndroidNetworking.initialize(getApplicationContext());

        initialize();
    }

    @Nullable@Override
    public IBinder onBind(Intent intent) {
        return super.onBind(intent);
    }

    @Override
    protected void onHandleIntent(@Nullable Intent intent) {

        try {
            if (intent == null) {
                return;
            }

            String action = intent.getAction();

            if (action == null) {
                return;
            }

            switch (action) {
                case "io.github.taitberlette.wasp_os_companion.initBluetooth":
                    initialize();
                    break;
                case "io.github.taitberlette.wasp_os_companion.checkBluetooth":
                    if (connectionState != 0) {
                        broadcastUpdate("io.github.taitberlette.wasp_os_companion.watchConnected", bleGatt.getDevice().getName(), bleGatt.getDevice().getAddress());
                        backgroundSync();
                    }
                    break;
                case "io.github.taitberlette.wasp_os_companion.connectToBluetooth":
                    if (connectionState != 0) {
                        broadcastUpdate("io.github.taitberlette.wasp_os_companion.watchConnected", bleGatt.getDevice().getName(), bleGatt.getDevice().getAddress());
                        backgroundSync();
                        break;
                    }
                    scanForWatch();
                    break;
                case "io.github.taitberlette.wasp_os_companion.disconnectFromBluetooth":
                    disconnectFromWatch();
                    break;
                case "io.github.taitberlette.wasp_os_companion.writeToBluetooth":
                    String data = intent.getStringExtra("io.github.taitberlette.wasp_os_companion.writeToBluetooth.data");
                    writeData(data);
                    break;
                default:
                    break;
            }
        } catch(Exception e) {
            Log.e("background service", "onHandleIntent() " + e.toString() + " \non line " + e.getStackTrace()[0].getLineNumber());
        }

    }

    private void broadcastUpdate(final String action) {
        final Intent intent = new Intent(action);
        sendBroadcast(intent);
    }

    private void broadcastUpdate(final String action, final String data) {
        final Intent intent = new Intent(action);
        intent.putExtra("io.github.taitberlette.wasp_os_companion.data", data);
        sendBroadcast(intent);
    }

    private void broadcastUpdate(final String action, final String main, final String extra) {
        final Intent intent = new Intent(action);
        intent.putExtra("io.github.taitberlette.wasp_os_companion.main", main);
        intent.putExtra("io.github.taitberlette.wasp_os_companion.extra", extra);
        sendBroadcast(intent);
    }

    private void acceptCall() {
        TelecomManager tm = (TelecomManager) getApplicationContext().getSystemService(Context.TELECOM_SERVICE);

        if (tm != null) {
            try{
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    tm.acceptRingingCall();
                }
            }catch(SecurityException exception){
                Log.e("background", exception.toString());
            }
        }
    }

    private void rejectCall() {
        TelecomManager tm = (TelecomManager) getApplicationContext().getSystemService(Context.TELECOM_SERVICE);

        if (tm != null) {
            try{
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    tm.endCall();
                }
            }catch(SecurityException exception){
                Log.e("background", exception.toString());
            }
        }
    }

    private void volDown() {
        AudioManager audioManager = (AudioManager) getApplicationContext().getSystemService(Context.AUDIO_SERVICE);
        audioManager.adjustVolume(AudioManager.ADJUST_LOWER, AudioManager.FLAG_PLAY_SOUND);
    }

    private void volUp() {
        AudioManager audioManager = (AudioManager) getApplicationContext().getSystemService(Context.AUDIO_SERVICE);
        audioManager.adjustVolume(AudioManager.ADJUST_RAISE, AudioManager.FLAG_PLAY_SOUND);
    }

    private void nextTrack() {
        AudioManager audioManager = (AudioManager) getApplicationContext().getSystemService(Context.AUDIO_SERVICE);
        long eventTime = SystemClock.uptimeMillis();

        KeyEvent downEvent = new KeyEvent(eventTime, eventTime, KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_NEXT, 0);
        audioManager.dispatchMediaKeyEvent(downEvent);

        KeyEvent upEvent = new KeyEvent(eventTime, eventTime, KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_NEXT, 0);
        audioManager.dispatchMediaKeyEvent(upEvent);
    }

    private void lastTrack() {
        AudioManager audioManager = (AudioManager) getApplicationContext().getSystemService(Context.AUDIO_SERVICE);
        long eventTime = SystemClock.uptimeMillis();

        KeyEvent downEvent = new KeyEvent(eventTime, eventTime, KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PREVIOUS, 0);
        audioManager.dispatchMediaKeyEvent(downEvent);

        KeyEvent upEvent = new KeyEvent(eventTime, eventTime, KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PREVIOUS, 0);
        audioManager.dispatchMediaKeyEvent(upEvent);
    }

    private void playTrack() {
        AudioManager audioManager = (AudioManager) getApplicationContext().getSystemService(Context.AUDIO_SERVICE);
        long eventTime = SystemClock.uptimeMillis();

        KeyEvent downEvent = new KeyEvent(eventTime, eventTime, KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY, 0);
        audioManager.dispatchMediaKeyEvent(downEvent);

        KeyEvent upEvent = new KeyEvent(eventTime, eventTime, KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PLAY, 0);
        audioManager.dispatchMediaKeyEvent(upEvent);
    }

    private void pauseTrack() {
        AudioManager audioManager = (AudioManager) getApplicationContext().getSystemService(Context.AUDIO_SERVICE);
        long eventTime = SystemClock.uptimeMillis();

        KeyEvent downEvent = new KeyEvent(eventTime, eventTime, KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE, 0);
        audioManager.dispatchMediaKeyEvent(downEvent);

        KeyEvent upEvent = new KeyEvent(eventTime, eventTime, KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PAUSE, 0);
        audioManager.dispatchMediaKeyEvent(upEvent);
    }

    private StringRequestListener networkResponse (String app) {
        return new StringRequestListener() {@Override
            public void onResponse(String response) {
                response = response.replaceAll("[\r\n]+", " ");
                writeData(appPath(app, 2) + "._network(True, \"\"\"" + response + "\"\"\")");

            }@Override
            public void onError(ANError error) {
                writeData(appPath(app, 2) + "._network(False, '')");
            }
        };
    };

    public class PhoneReceiver extends BroadcastReceiver {

        @Override
        public void onReceive(Context context, Intent intent) {

            if (intent == null) {
                return;
            }

            String callingNumber = intent.getStringExtra("incoming_number");
            String callingName = getContactDisplayNameByNumber(callingNumber);
            String state = intent.getStringExtra("state");
            String cmd = "incoming";

            if(callingNumber == null){
                return;
            }

            if(callingName == null){
                callingName = "";
            }

            if(state.equals(TelephonyManager.EXTRA_STATE_RINGING)){
                cmd = "incoming";
                nowCallingName = callingName;
                nowCallingNumber = callingNumber;
            }
            if ((state.equals(TelephonyManager.EXTRA_STATE_OFFHOOK))){
                cmd = "accept";
            }
            if (state.equals(TelephonyManager.EXTRA_STATE_IDLE)){
                cmd = "end";
            }

            if (connectionState == 3) {
                writeData("wasp.system.set_phone_state({ \"cmd\": \"" + cmd + "\", \"name\": \"" + callingName + "\", \"number\": \"" + callingNumber + "\"})");
            }
        }

        String getContactDisplayNameByNumber(String number) {
            Uri uri;
            if(Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.ENTERPRISE_CONTENT_FILTER_URI, Uri.encode(number));
            } else {
                uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(number));
            }
            String name = "Unknown Caller";

            if (number == null || number.equals("")) {
                return name;
            }

            try (Cursor contactLookup = getApplicationContext().getContentResolver().query(uri, null, null, null, null)) {
                if (contactLookup != null && contactLookup.getCount() > 0) {
                    contactLookup.moveToNext();
                    name = contactLookup.getString(contactLookup.getColumnIndex(ContactsContract.Data.DISPLAY_NAME));
                }
            } catch (SecurityException e) {
                // ignore, just return name below
            }

            return name;
        }
    }
    
    public class MediaReceiver extends BroadcastReceiver {

        @Override
        public void onReceive(Context context, Intent intent) {

            if (intent == null) {
                return;
            }

            String artistName = intent.getStringExtra("artist");
            String albumName = intent.getStringExtra("album");
            String trackName = intent.getStringExtra("track");

            if (nowPlayingArtist.equals(artistName) && nowPlayingAlbum.equals(albumName) && nowPlayingTrack.equals(trackName)) {
                return;
            }

            nowPlayingArtist = artistName;
            nowPlayingAlbum = albumName;
            nowPlayingTrack = trackName;

            if (connectionState == 3) {
                writeData("wasp.system.musicinfo = {\"artist\": \"" + artistName + "\", \"track\": \"" + trackName + "\"}");
            }
        }
    }

    public class NotificationReceiver extends BroadcastReceiver {

        @Override
        public void onReceive(Context context, Intent intent) {

            if (intent == null) {
                return;
            }

            String command = intent.getStringExtra("command");
            String title = intent.getStringExtra("title");
            String body = intent.getStringExtra("body");
            String app = intent.getStringExtra("app");
            int id = intent.getIntExtra("id", 0);

            if (connectionState == 3) {
                if (command.equals("remove")) {
                    writeData("wasp.system.unnotify(" + id + ")");
                } else {
                    if (id == lastNotificationId) {
                        return;
                    }
                    lastNotificationId = id;
                    writeData("wasp.system.notify(" + id + ", {'body': '" + body + "', 'src': '" + app + "', 'title': '" + title + "'})");
                    writeData("wasp.watch.vibrator.pulse(ms=wasp.system.notify_duration)");
                }
            }
        }
    }
}