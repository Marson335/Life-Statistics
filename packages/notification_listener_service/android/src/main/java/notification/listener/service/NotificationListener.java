package notification.listener.service;

import static notification.listener.service.NotificationUtils.getBitmapFromDrawable;
import static notification.listener.service.models.ActionCache.cachedNotifications;

import android.annotation.SuppressLint;
import android.app.Notification;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
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
    public static boolean isConnected = false;
    public static long lastConnectedTime = 0;
    public static long lastDisconnectedTime = 0;

    @Override
    public void onListenerConnected() {
        super.onListenerConnected();
        instance = this;
        isConnected = true;
        lastConnectedTime = System.currentTimeMillis();
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

    public static String extractNotificationTitle(Bundle extras) {
        if (extras == null) return null;
        CharSequence title = extras.getCharSequence(Notification.EXTRA_TITLE_BIG);
        if (title == null || title.length() == 0) {
            title = extras.getCharSequence(Notification.EXTRA_TITLE);
        }
        return title != null ? title.toString().trim() : null;
    }

    public static String extractNotificationContent(Bundle extras) {
        if (extras == null) return null;

        // 1. Check EXTRA_BIG_TEXT (used by BigTextStyle for full details like Monobank, Privat24, Google Wallet)
        CharSequence bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT);
        if (bigText != null && bigText.length() > 0) {
            return bigText.toString().trim();
        }

        // 2. Check EXTRA_TEXT_LINES (used by InboxStyle)
        CharSequence[] lines = extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES);
        if (lines != null && lines.length > 0) {
            StringBuilder sb = new StringBuilder();
            for (CharSequence line : lines) {
                if (line != null && line.length() > 0) {
                    if (sb.length() > 0) sb.append("\n");
                    sb.append(line);
                }
            }
            if (sb.length() > 0) return sb.toString().trim();
        }

        // 3. Check EXTRA_TEXT (standard single line body)
        CharSequence text = extras.getCharSequence(Notification.EXTRA_TEXT);
        if (text != null && text.length() > 0) {
            return text.toString().trim();
        }

        // 4. Check EXTRA_SUB_TEXT
        CharSequence subText = extras.getCharSequence(Notification.EXTRA_SUB_TEXT);
        if (subText != null && subText.length() > 0) {
            return subText.toString().trim();
        }

        // 5. Check EXTRA_SUMMARY_TEXT
        CharSequence summaryText = extras.getCharSequence(Notification.EXTRA_SUMMARY_TEXT);
        if (summaryText != null && summaryText.length() > 0) {
            return summaryText.toString().trim();
        }

        return null;
    }

    public void saveToPendingQueue(String packageName, String title, String content, int id, long postTime) {
        try {
            SharedPreferences sp = getApplicationContext().getSharedPreferences("notification_queue_prefs", Context.MODE_PRIVATE);
            String currentQueue = sp.getString("pending_notifications_json", "[]");
            JSONArray array = new JSONArray(currentQueue);

            JSONObject obj = new JSONObject();
            obj.put("packageName", packageName != null ? packageName : "");
            obj.put("title", title != null ? title : "");
            obj.put("content", content != null ? content : "");
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
            Log.i(TAG, "📥 Saved notification to native queue: " + packageName + " | " + title + " | " + content);
        } catch (Exception e) {
            Log.e(TAG, "Error saving to pending queue: " + e.getMessage());
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
        String packageName = notification.getPackageName();
        Bundle extras = notification.getNotification().extras;
        boolean isOngoing = (notification.getNotification().flags & Notification.FLAG_ONGOING_EVENT) != 0;
        byte[] appIcon = getAppIcon(packageName);
        byte[] largeIcon = null;
        Action action = NotificationUtils.getQuickReplyAction(notification.getNotification(), packageName);

        if (Build.VERSION.SDK_INT >= VERSION_CODES.M) {
            largeIcon = getNotificationLargeIcon(getApplicationContext(), notification.getNotification());
        }

        Intent intent = new Intent(NotificationConstants.INTENT);
        intent.setPackage(getPackageName());
        intent.putExtra(NotificationConstants.PACKAGE_NAME, packageName);
        intent.putExtra(NotificationConstants.ID, notification.getId());
        intent.putExtra(NotificationConstants.CAN_REPLY, action != null);
        intent.putExtra(NotificationConstants.IS_ONGOING, isOngoing);

        if (NotificationUtils.getQuickReplyAction(notification.getNotification(), packageName) != null) {
            cachedNotifications.put(notification.getId(), action);
        }

        intent.putExtra(NotificationConstants.NOTIFICATION_TIME, notification.getPostTime());
        intent.putExtra(NotificationConstants.NOTIFICATIONS_ICON, appIcon);
        intent.putExtra(NotificationConstants.NOTIFICATIONS_LARGE_ICON, largeIcon);

        if (extras != null) {
            String safeTitle = extractNotificationTitle(extras);
            String safeText = extractNotificationContent(extras);

            if (safeTitle != null && safeTitle.length() > 200) {
                safeTitle = safeTitle.substring(0, 200);
            }
            if (safeText != null && safeText.length() > 2000) {
                safeText = safeText.substring(0, 2000);
            }

            intent.putExtra(NotificationConstants.NOTIFICATION_TITLE, safeTitle);
            intent.putExtra(NotificationConstants.NOTIFICATION_CONTENT, safeText);
            intent.putExtra(NotificationConstants.IS_REMOVED, isRemoved);

            if (!isRemoved && (safeTitle != null || safeText != null)) {
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

        for (StatusBarNotification sbn : activeNotifications) {
            Map<String, Object> notifyData = new HashMap<>();
            Notification notification = sbn.getNotification();
            Bundle extras = notification.extras;

            notifyData.put("id", sbn.getId());
            notifyData.put("packageName", sbn.getPackageName());
            notifyData.put("title", extractNotificationTitle(extras));
            notifyData.put("content", extractNotificationContent(extras));
            boolean isOngoing = (notification.flags & Notification.FLAG_ONGOING_EVENT) != 0;
            notifyData.put("onGoing", isOngoing);
            notifyData.put("postTime", sbn.getPostTime());

            notificationList.add(notifyData);
        }
        return notificationList;
    }

}
