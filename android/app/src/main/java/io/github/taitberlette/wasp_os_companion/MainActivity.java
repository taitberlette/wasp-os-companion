package io.github.taitberlette.wasp_os_companion;

import android.Manifest;
import android.content.BroadcastReceiver;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.provider.Settings;
import android.text.TextUtils;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

import android.util.Log;

import org.json.JSONObject;

import java.util.HashMap;
import java.util.Map;

public class MainActivity extends FlutterActivity {

    private Intent forService;
    Context context;
    BackgroundReceiver receiver;
    MethodChannel channel;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        GeneratedPluginRegistrant.registerWith(flutterEngine);
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        context = getApplicationContext();

        forService = new Intent(MainActivity.this, MyService.class);

        channel = new MethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), "io.github.taitberlette.wasp_os_companion/messages");

        channel.setMethodCallHandler(new MethodChannel.MethodCallHandler() {

            @Override
            public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {

                if (call.method.equals("startBackgroundService")) {
                    startBackgroundService();
                    result.success("startBackgroundService");
                } else if (call.method.equals("stopBackgroundService")) {
                    stopBackgroundService();
                    result.success("stopBackgroundService");
                } else if (call.method.equals("connectToBluetooth")) {
                    Intent intent = new Intent(context, MyService.class);
                    intent.setAction("io.github.taitberlette.wasp_os_companion.connectToBluetooth");
                    startService(intent);

                } else if (call.method.equals("writeToBluetooth")) {
                    String data = call.argument("data").toString();
                    Intent intent = new Intent(context, MyService.class);
                    intent.setAction("io.github.taitberlette.wasp_os_companion.writeToBluetooth");
                    intent.putExtra("io.github.taitberlette.wasp_os_companion.writeToBluetooth.data", data);
                    startService(intent);

                } else if (call.method.equals("disconnectFromBluetooth")) {
                    Intent intent = new Intent(context, MyService.class);
                    intent.setAction("io.github.taitberlette.wasp_os_companion.disconnectFromBluetooth");
                    startService(intent);
                } else if (call.method.equals("connectedToChannel")) {

                    if (!isNotificationServiceEnabled()) {
                        channel.invokeMethod("askNotifications", null);
                    }

                } else if (call.method.equals("acceptNotifications")) {
                    startActivity(new Intent("android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"));
                } else {
                    result.notImplemented();
                }
            }
        });

        IntentFilter iF = new IntentFilter();
        iF.addAction("io.github.taitberlette.wasp_os_companion.watchConnected");
        iF.addAction("io.github.taitberlette.wasp_os_companion.watchConnecting");
        iF.addAction("io.github.taitberlette.wasp_os_companion.watchDisconnected");
        iF.addAction("io.github.taitberlette.wasp_os_companion.watchServicesDiscovered");
        iF.addAction("io.github.taitberlette.wasp_os_companion.watchResponse");
        iF.addAction("io.github.taitberlette.wasp_os_companion.watchCommand");
        iF.addAction("io.github.taitberlette.wasp_os_companion.watchUart");
        iF.addAction("io.github.taitberlette.wasp_os_companion.askNotifications");
        receiver = new BackgroundReceiver();
        registerReceiver(receiver, iF);

        Intent intent = new Intent(context, MyService.class);
        intent.setAction("io.github.taitberlette.wasp_os_companion.checkBluetooth");
        startService(intent);

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.M) {
            if (checkSelfPermission(Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_DENIED || checkSelfPermission(Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_DENIED || checkSelfPermission(Manifest.permission.READ_CALL_LOG) == PackageManager.PERMISSION_DENIED || checkSelfPermission(Manifest.permission.ANSWER_PHONE_CALLS) == PackageManager.PERMISSION_DENIED || checkSelfPermission(Manifest.permission.READ_CONTACTS) == PackageManager.PERMISSION_DENIED || checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_DENIED) {
                String[] permissions = {Manifest.permission.READ_PHONE_STATE, Manifest.permission.CALL_PHONE, Manifest.permission.READ_CALL_LOG, Manifest.permission.ANSWER_PHONE_CALLS, Manifest.permission.READ_CONTACTS, Manifest.permission.ACCESS_FINE_LOCATION};
                requestPermissions(permissions, 5);
            }
        }

    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        unregisterReceiver(receiver);
    }

    private void startBackgroundService() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(forService);
        } else {
            startService(forService);
        }

        Intent intentMyService = new Intent(context, MyService.class);
        startService(intentMyService);

        Intent intentNotificationListener = new Intent(context, NotificationListener.class);
        startService(intentNotificationListener);
    }

    private void stopBackgroundService() {
        stopService(forService);
    }

    private boolean isNotificationServiceEnabled() {
        String pkgName = getPackageName();
        final String flat = Settings.Secure.getString(getContentResolver(), "enabled_notification_listeners");
        if (!TextUtils.isEmpty(flat)) {
            final String[] names = flat.split(":");
            for (int i = 0; i < names.length; i++) {
                final ComponentName cn = ComponentName.unflattenFromString(names[i]);
                if (cn != null) {
                    if (TextUtils.equals(pkgName, cn.getPackageName())) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    class BackgroundReceiver extends BroadcastReceiver {

        @Override
        public void onReceive(Context context, Intent intent) {

            String action = intent.getAction();

            if (channel == null) {
                return;
            }

            String method = null;
            HashMap < String,
                    Object > data = null;

            switch (action) {
                case "io.github.taitberlette.wasp_os_companion.watchConnected":
                    method = "watchConnected";
                    data = new HashMap < String,
                            Object > ();
                    data.put("main", intent.getStringExtra("io.github.taitberlette.wasp_os_companion.main"));
                    data.put("extra", intent.getStringExtra("io.github.taitberlette.wasp_os_companion.extra"));
                    break;
                case "io.github.taitberlette.wasp_os_companion.watchConnecting":
                    method = "watchConnecting";
                    data = new HashMap < String,
                            Object > ();
                    data.put("data", intent.getStringExtra("io.github.taitberlette.wasp_os_companion.data"));
                    break;
                case "io.github.taitberlette.wasp_os_companion.watchDisconnected":
                    method = "watchDisconnected";
                    break;
                case "io.github.taitberlette.wasp_os_companion.watchServicesDiscovered":
                    method = "watchServicesDiscovered";
                    break;
                case "io.github.taitberlette.wasp_os_companion.watchCommand":
                    method = "watchCommand";
                    data = new HashMap < String,
                            Object > ();
                    data.put("data", intent.getStringExtra("io.github.taitberlette.wasp_os_companion.data"));
                    break;
                case "io.github.taitberlette.wasp_os_companion.watchResponse":
                    method = "watchResponse";
                    data = new HashMap < String,
                            Object > ();
                    data.put("main", intent.getStringExtra("io.github.taitberlette.wasp_os_companion.main"));
                    data.put("extra", intent.getStringExtra("io.github.taitberlette.wasp_os_companion.extra"));
                    break;
                case "io.github.taitberlette.wasp_os_companion.watchUart":
                    method = "watchUart";
                    data = new HashMap < String,
                            Object > ();
                    data.put("data", intent.getStringExtra("io.github.taitberlette.wasp_os_companion.data"));
                    break;
                default:
                    break;
            }

            channel.invokeMethod(method, data, new MethodChannel.Result() {@Override
            public void success(@Nullable Object result) {

            }

                @Override
                public void error(String errorCode, @Nullable String errorMessage, @Nullable Object errorDetails) {

                }

                @Override
                public void notImplemented() {

                }
            });
        }

    }
}