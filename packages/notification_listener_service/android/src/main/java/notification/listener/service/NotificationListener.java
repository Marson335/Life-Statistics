package notification.listener.service;

import static notification.listener.service.NotificationUtils.getBitmapFromDrawable;
import static notification.listener.service.models.ActionCache.cachedNotifications;

import android.annotation.SuppressLint;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.graphics.Bitmap;
import android.graphics.drawable.BitmapDrawable;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.Icon;
import android.os.Build;
import android.os.Build.VERSION_CODES;
import android.os.Bundle;
import android.service.notification.NotificationListenerService;
import android.service.notification.StatusBarNotification;
import android.util.Log;
import java.util.List;
import java.util.Map;
import java.util.ArrayList;
import java.util.HashMap;

import android.content.SharedPreferences;
import org.json.JSONArray;
import org.json.JSONObject;
import androidx.annotation.RequiresApi;

import java.io.ByteArrayOutputStream;

import notification.listener.service.models.Action;


@SuppressLint("OverrideAbstract")
@RequiresApi(api = VERSION_CODES.JELLY_BEAN_MR2)
public class NotificationListener extends NotificationListenerService {
    private static NotificationListener instance;

    public static NotificationListener getInstance() {
        return instance;
    }


    private static final String TAG = "NotificationListener";
    private static final String CHANNEL_ID = "finance_monitor_channel";
    private static final int FOREGROUND_NOTIFICATION_ID = 9901;
    private boolean isForegroundRunning = false;

    public static boolean isConnected = false;
    public static long lastConnectedTime = 0;
    public static long lastDisconnectedTime = 0;

    private void startForegroundTracking() {
        if (isForegroundRunning) return;
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "Моніторинг фінансів",
                    NotificationManager.IMPORTANCE_LOW
                );
                channel.setDescription("Фонове автофіксування витрат");
                channel.setShowBadge(false);
                NotificationManager manager = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
                if (manager != null) {
                    manager.createNotificationChannel(channel);
                }
            }

            Intent launchIntent = getPackageManager().getLaunchIntentForPackage(getPackageName());
            PendingIntent pendingIntent = null;
            if (launchIntent != null) {
                int flags = PendingIntent.FLAG_UPDATE_CURRENT;
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    flags |= PendingIntent.FLAG_IMMUTABLE;
                }
                pendingIntent = PendingIntent.getActivity(this, 0, launchIntent, flags);
            }

            Notification.Builder builder;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                builder = new Notification.Builder(this, CHANNEL_ID);
            } else {
                builder = new Notification.Builder(this);
            }

            builder.setContentTitle("Life Statistics")
                   .setContentText("Автоматична фіксація витрат активна (24/7)")
                   .setSmallIcon(getApplicationInfo().icon)
                   .setOngoing(true);

            if (pendingIntent != null) {
                builder.setContentIntent(pendingIntent);
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(FOREGROUND_NOTIFICATION_ID, builder.build(), ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC);
            } else {
                startForeground(FOREGROUND_NOTIFICATION_ID, builder.build());
            }
            isForegroundRunning = true;
            Log.i(TAG, "🚀 Foreground Service started: 24/7 financial tracking active");
        } catch (Exception e) {
            Log.e(TAG, "Error starting foreground service: " + e.getMessage());
        }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        instance = this;
        startForegroundTracking();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        super.onStartCommand(intent, flags, startId);
        startForegroundTracking();
        return START_STICKY;
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        super.onTaskRemoved(rootIntent);
        Log.i(TAG, "App swiped from Recents - ensuring NotificationListener stays alive");
        startForegroundTracking();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                requestRebind(new ComponentName(this, NotificationListener.class));
            } catch (Exception e) {
                Log.e(TAG, "Error in requestRebind onTaskRemoved: " + e.getMessage());
            }
        }
    }

    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        instance = this;
        isConnected = true;
        lastConnectedTime = System.currentTimeMillis();
        startForegroundTracking();
        Log.i(TAG, "✅ Listener CONECTADO correctamente al sistema");

        Intent intent = new Intent(NotificationConstants.INTENT);
        intent.setPackage(getPackageName());
        intent.putExtra("connection_event", true);
        intent.putExtra("is_connected", true);
        intent.putExtra("timestamp", lastConnectedTime);
        sendBroadcast(intent);
    }

    @Override
    public void onListenerDisconnected() {
        super.onListenerDisconnected();
        isConnected = false;
        lastDisconnectedTime = System.currentTimeMillis();
        Log.w(TAG, "⚠️ Listener DESCONECTADO por el sistema - Intentando reconectar...");

        Intent intent = new Intent(NotificationConstants.INTENT);
        intent.setPackage(getPackageName());
        intent.putExtra("connection_event", true);
        intent.putExtra("is_connected", false);
        intent.putExtra("timestamp", lastDisconnectedTime);
        sendBroadcast(intent);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            try {
                requestRebind(new ComponentName(this, NotificationListener.class));
                Log.i(TAG, "🔄Requesting reconnection with requestRebind()...");
            } catch (Exception e) {
                Log.e(TAG, "❌ Error requesting reconnection:" + e.getMessage());
            }
        }
    }

    public static void reconnectService(Context context) {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                ComponentName componentName = new ComponentName(context, NotificationListener.class);
                NotificationListenerService.requestRebind(componentName);
                Log.i(TAG, "🔄 Listener requestRebind executed successfully.");
            }
        } catch (Exception e) {
            Log.e(TAG, "❌ Error in reconnectService: " + e.getMessage());
        }
    }

    private static final java.util.Set<String> seenUnredactedKeys = new java.util.HashSet<>();
    private long lastActiveScanTime = 0;

    public static boolean isRedactedContent(String title, String content) {
        String combined = ((title != null ? title : "") + " " + (content != null ? content : "")).toLowerCase();
        return combined.contains("чутливий вміст") ||
               combined.contains("sensitive notification") ||
               combined.contains("скрыто содержимое") ||
               combined.contains("вміст сповіщення приховано") ||
               combined.contains("content hidden");
    }

    public static boolean isGooglePayOrWallet(String packageName, String title, String content) {
        if (packageName != null) {
            String lowerPkg = packageName.toLowerCase();
            if (lowerPkg.contains("wallet") ||
                lowerPkg.contains("walletnfcrel") ||
                lowerPkg.equals("com.google.android.apps.walletnfcrel") ||
                lowerPkg.equals("com.google.android.apps.wallet")) {
                return true;
            }
        }
        String combined = ((title != null ? title : "") + " " + (content != null ? content : "")).toLowerCase();
        return combined.contains("google гаманець") ||
               combined.contains("гаманець google") ||
               combined.contains("google wallet") ||
               combined.contains("google pay");
    }

    public static String extractNotificationTitle(Bundle extras) {
        if (extras == null) return null;
        CharSequence title = extras.getCharSequence(Notification.EXTRA_TITLE);
        CharSequence titleBig = extras.getCharSequence(Notification.EXTRA_TITLE_BIG);

        String t1 = title != null ? title.toString().trim() : "";
        String t2 = titleBig != null ? titleBig.toString().trim() : "";

        if (!t2.isEmpty() && (t1.isEmpty() || t2.contains(t1))) {
            return t2;
        }
        if (!t1.isEmpty() && (t2.isEmpty() || t1.contains(t2))) {
            return t1;
        }
        if (!t1.isEmpty() && !t2.isEmpty()) {
            return t1 + " " + t2;
        }
        return null;
    }

    public static String extractNotificationContent(Bundle extras) {
        if (extras == null) return null;

        StringBuilder result = new StringBuilder();

        // 1. Standard EXTRA_TEXT
        CharSequence text = extras.getCharSequence(Notification.EXTRA_TEXT);
        if (text != null && text.length() > 0) {
            result.append(text.toString().trim());
        }

        // 2. EXTRA_BIG_TEXT (used by BigTextStyle for full details like Monobank, Privat24, Google Wallet)
        CharSequence bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT);
        if (bigText != null && bigText.length() > 0) {
            String bigStr = bigText.toString().trim();
            String current = result.toString();
            if (current.isEmpty()) {
                result.append(bigStr);
            } else if (bigStr.contains(current)) {
                result.setLength(0);
                result.append(bigStr);
            } else if (!current.contains(bigStr)) {
                result.append("\n").append(bigStr);
            }
        }

        // 3. EXTRA_TEXT_LINES (used by InboxStyle)
        CharSequence[] lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES);
        if (lines != null && lines.length > 0) {
            for (CharSequence line : lines) {
                if (line != null && line.length() > 0) {
                    String lineStr = line.toString().trim();
                    if (!result.toString().contains(lineStr)) {
                        if (result.length() > 0) result.append("\n");
                        result.append(lineStr);
                    }
                }
            }
        }

        // 4. EXTRA_SUB_TEXT
        CharSequence subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT);
        if (subText != null && subText.length() > 0) {
            String subStr = subText.toString().trim();
            if (!result.toString().contains(subStr)) {
                if (result.length() > 0) result.append("\n");
                result.append(subStr);
            }
        }

        // 5. EXTRA_SUMMARY_TEXT
        CharSequence summaryText = extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT);
        if (result.length() == 0 && summaryText != null && summaryText.length() > 0) {
            result.append(summaryText.toString().trim());
        }

        return result.length() > 0 ? result.toString().trim() : null;
    }

    public boolean saveToPendingQueue(String packageName, String title, String content, int id, long postTime) {
        try {
            if (packageName != null && (packageName.equals(getPackageName()) || packageName.contains("life_statistics"))) {
                return false;
            }
            if (isGooglePayOrWallet(packageName, title, content)) {
                return false;
            }
            if (isRedactedContent(title, content)) {
                return false;
            }

            String safePkg = packageName != null ? packageName : "";
            String safeTitle = title != null ? title : "";
            String safeContent = content != null ? content : "";
            if (safeTitle.isEmpty() && safeContent.isEmpty()) {
                return false;
            }

            String memKey = safePkg + "|" + id + "|" + postTime + "|" + safeTitle + "|" + safeContent;
            if (seenUnredactedKeys.contains(memKey)) {
                return false;
            }
            seenUnredactedKeys.add(memKey);
            if (seenUnredactedKeys.size() > 300) {
                seenUnredactedKeys.clear();
                seenUnredactedKeys.add(memKey);
            }

            SharedPreferences sp = getApplicationContext().getSharedPreferences("notification_queue_prefs", Context.MODE_PRIVATE);
            String currentQueue = sp.getString("pending_notifications_json", "[]");
            JSONArray array = new JSONArray(currentQueue);

            // Avoid duplicate entry in JSON queue
            for (int i = 0; i < array.length(); i++) {
                JSONObject existing = array.optJSONObject(i);
                if (existing != null &&
                    safePkg.equals(existing.optString("packageName")) &&
                    id == existing.optInt("id") &&
                    safeTitle.equals(existing.optString("title")) &&
                    safeContent.equals(existing.optString("content"))) {
                    return false;
                }
            }

            JSONObject obj = new JSONObject();
            obj.put("packageName", safePkg);
            obj.put("title", safeTitle);
            obj.put("content", safeContent);
            obj.put("id", id);
            obj.put("postTime", postTime);

            array.put(obj);

            // Keep bounded to last 50 items
            if (array.length() > 50) {
                JSONArray trimmed = new JSONArray();
                for (int i = array.length() - 50; i < array.length(); i++) {
                    trimmed.put(array.get(i));
                }
                array = trimmed;
            }

            sp.edit().putString("pending_notifications_json", array.toString()).apply();
            Log.i(TAG, "📥 Saved notification to native queue: " + safePkg + " | " + safeTitle + " | " + safeContent);
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Error saving to pending queue: " + e.getMessage());
            return false;
        }
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    private void scanAndQueueUnredactedActiveNotifications() {
        try {
            StatusBarNotification[] active = getActiveNotifications();
            if (active == null) return;
            for (StatusBarNotification sbn : active) {
                if (sbn == null) continue;
                String pkg = sbn.getPackageName();
                if (pkg != null && (pkg.equals(getPackageName()) || pkg.contains("life_statistics"))) {
                    continue;
                }
                Notification n = sbn.getNotification();
                if (n == null || n.extras == null) continue;
                String title = extractNotificationTitle(n.extras);
                String content = extractNotificationContent(n.extras);
                if ((title == null || title.isEmpty()) && (content == null || content.isEmpty()) && n.tickerText != null) {
                    content = n.tickerText.toString().trim();
                }
                if (isGooglePayOrWallet(pkg, title, content)) {
                    continue;
                }
                if (!isRedactedContent(title, content) && (title != null || content != null)) {
                    boolean newlyAdded = saveToPendingQueue(pkg, title, content, sbn.getId(), sbn.getPostTime());
                    if (newlyAdded) {
                        handleNotification(sbn, false);
                    }
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "Error in scanAndQueueUnredactedActiveNotifications: " + e.getMessage());
        }
    }

    @RequiresApi(api = VERSION_CODES.LOLLIPOP)
    @Override
    public void onNotificationRankingUpdate(RankingMap rankingMap) {
        super.onNotificationRankingUpdate(rankingMap);
        long now = System.currentTimeMillis();
        if (now - lastActiveScanTime > 1500) {
            lastActiveScanTime = now;
            scanAndQueueUnredactedActiveNotifications();
        }
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    @Override
    public void onNotificationPosted(StatusBarNotification notification) {
        // Update connection status - if we receive notifications, we are connected
        if (!isConnected) {
            isConnected = true;
            Log.i(TAG, "📥 Notificación recibida - Actualizando estado a CONECTADO");
        }
        handleNotification(notification, false);
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    @Override
    public void onNotificationRemoved(StatusBarNotification sbn) {
        handleNotification(sbn, true);
    }

    @RequiresApi(api = VERSION_CODES.KITKAT)
    private void handleNotification(StatusBarNotification notification, boolean isRemoved) {
        try {
            if (notification == null) return;
            String packageName = notification.getPackageName();
            if (packageName != null && (packageName.equals(getPackageName()) || packageName.contains("life_statistics"))) {
                return;
            }
            Notification notif = notification.getNotification();
            if (notif == null) return;
            Bundle extras = notif.extras;
            boolean isOngoing = (notif.flags & Notification.FLAG_ONGOING_EVENT) != 0;
            byte[] appIcon = getAppIcon(packageName);
            byte[] largeIcon = null;
            Action action = NotificationUtils.getQuickReplyAction(notif, packageName);

            if (Build.VERSION.SDK_INT >= VERSION_CODES.M) {
                largeIcon = getNotificationLargeIcon(getApplicationContext(), notif);
            }

            Intent intent = new Intent(NotificationConstants.INTENT);
            intent.setPackage(getPackageName());
            intent.putExtra(NotificationConstants.PACKAGE_NAME, packageName);
            intent.putExtra(NotificationConstants.ID, notification.getId());
            intent.putExtra(NotificationConstants.CAN_REPLY, action != null);
            intent.putExtra(NotificationConstants.IS_ONGOING, isOngoing);

            if (action != null) {
                cachedNotifications.put(notification.getId(), action);
            }

            intent.putExtra(NotificationConstants.NOTIFICATION_TIME, notification.getPostTime());
            intent.putExtra(NotificationConstants.NOTIFICATIONS_ICON, appIcon);
            intent.putExtra(NotificationConstants.NOTIFICATIONS_LARGE_ICON, largeIcon);

            if (extras != null) {
                String safeTitle = extractNotificationTitle(extras);
                String safeText = extractNotificationContent(extras);

                if ((safeTitle == null || safeTitle.isEmpty()) && (safeText == null || safeText.isEmpty()) && notif.tickerText != null) {
                    safeText = notif.tickerText.toString().trim();
                }

                if (isGooglePayOrWallet(packageName, safeTitle, safeText)) {
                    return;
                }

                if (safeTitle != null && safeTitle.length() > 200) {
                    safeTitle = safeTitle.substring(0, 200);
                }
                if (safeText != null && safeText.length() > 2000) {
                    safeText = safeText.substring(0, 2000);
                }

                intent.putExtra(NotificationConstants.NOTIFICATION_TITLE, safeTitle);
                intent.putExtra(NotificationConstants.NOTIFICATION_CONTENT, safeText);
                intent.putExtra(NotificationConstants.IS_REMOVED, isRemoved);

                // Save to pending queue both on post and on remove (if unredacted),
                // so notifications that arrived while locked and were dismissed after unlocking are still captured!
                if ((safeTitle != null || safeText != null) && !isRedactedContent(safeTitle, safeText)) {
                    saveToPendingQueue(packageName, safeTitle, safeText, notification.getId(), notification.getPostTime());
                }

                // Solo incluir imagen si la notificación no es demasiado grande
                boolean containsImage = extras.containsKey(Notification.EXTRA_PICTURE);
                intent.putExtra(NotificationConstants.HAVE_EXTRA_PICTURE, containsImage);

                if (containsImage) {
                    try {
                        Bitmap bmp = (Bitmap) extras.get(Notification.EXTRA_PICTURE);
                        if (bmp != null) {
                            // Reducir tamaño de imagen si es muy grande
                            Bitmap scaledBmp = bmp;
                            if (bmp.getWidth() > 300 || bmp.getHeight() > 300) {
                                int maxSize = 300;
                                float ratio = Math.min(
                                    (float) maxSize / bmp.getWidth(),
                                    (float) maxSize / bmp.getHeight()
                                );
                                int width = Math.round(bmp.getWidth() * ratio);
                                int height = Math.round(bmp.getHeight() * ratio);
                                scaledBmp = Bitmap.createScaledBitmap(bmp, width, height, true);
                            }

                            ByteArrayOutputStream stream = new ByteArrayOutputStream();
                            scaledBmp.compress(Bitmap.CompressFormat.JPEG, 70, stream);
                            byte[] imageData = stream.toByteArray();

                            // Solo incluir si no es demasiado grande
                            if (imageData.length < 200000) { // 200KB límite
                                intent.putExtra(NotificationConstants.EXTRAS_PICTURE, imageData);
                            }
                        }
                    } catch (Exception e) {
                        // Ignorar errores de procesamiento de imagen
                        Log.e("NotificationListener", "Error procesando imagen: " + e.getMessage());
                    }
                }
            }
            sendBroadcast(intent);
        } catch (Exception e) {
            Log.e("NotificationListener", "Error en handleNotification: " + e.getMessage());
        }
    }

    public byte[] getAppIcon(String packageName) {
        try {
            PackageManager manager = getBaseContext().getPackageManager();
            Drawable icon = manager.getApplicationIcon(packageName);
            ByteArrayOutputStream stream = new ByteArrayOutputStream();
            getBitmapFromDrawable(icon).compress(Bitmap.CompressFormat.PNG, 100, stream);
            return stream.toByteArray();
        } catch (PackageManager.NameNotFoundException e) {
            e.printStackTrace();
            return null;
        }
    }

    @RequiresApi(api = VERSION_CODES.M)
    private byte[] getNotificationLargeIcon(Context context, Notification notification) {
        try {
            Icon largeIcon = notification.getLargeIcon();
            if (largeIcon == null) {
                return null;
            }
            Drawable iconDrawable = largeIcon.loadDrawable(context);
            if (iconDrawable == null) {
                return null;
            }
            Bitmap iconBitmap = getBitmapFromDrawable(iconDrawable);
            ByteArrayOutputStream outputStream = new ByteArrayOutputStream();
            iconBitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream);
            return outputStream.toByteArray();
        } catch (Exception e) {
            e.printStackTrace();
            Log.d("ERROR LARGE ICON", "getNotificationLargeIcon: " + e.getMessage());
            return null;
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.KITKAT)
    public List<Map<String, Object>> getActiveNotificationData() {
        List<Map<String, Object>> notificationList = new ArrayList<>();
        StatusBarNotification[] activeNotifications = getActiveNotifications();
        if (activeNotifications == null) return notificationList;

        for (StatusBarNotification sbn : activeNotifications) {
            if (sbn == null) continue;
            String pkg = sbn.getPackageName();
            if (pkg != null && (pkg.equals(getPackageName()) || pkg.contains("life_statistics"))) {
                continue;
            }
            Map<String, Object> notifyData = new HashMap<>();
            Notification notification = sbn.getNotification();
            if (notification == null) continue;
            Bundle extras = notification.extras;

            String title = extractNotificationTitle(extras);
            String content = extractNotificationContent(extras);
            if ((title == null || title.isEmpty()) && (content == null || content.isEmpty()) && notification.tickerText != null) {
                content = notification.tickerText.toString().trim();
            }

            if (isGooglePayOrWallet(pkg, title, content)) {
                continue;
            }

            notifyData.put("id", sbn.getId());
            notifyData.put("packageName", pkg);
            notifyData.put("title", title);
            notifyData.put("content", content);
            boolean isOngoing = (notification.flags & Notification.FLAG_ONGOING_EVENT) != 0;
            notifyData.put("onGoing", isOngoing);
            notifyData.put("postTime", sbn.getPostTime());

            notificationList.add(notifyData);
        }
        return notificationList;
    }

}
