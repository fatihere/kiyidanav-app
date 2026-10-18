package com.kiyidanav.ekran_koruma;

import android.app.Activity;
import android.view.WindowManager;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Ekran görüntüsü / kayıt koruması: pencereye FLAG_SECURE ekler ya da kaldırır. */
public class EkranKorumaPlugin implements FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private MethodChannel kanal;
    private Activity aktivite;
    private boolean koru = false;

    @Override
    public void onAttachedToEngine(FlutterPluginBinding binding) {
        kanal = new MethodChannel(binding.getBinaryMessenger(), "kiyidanav/ekran_koruma");
        kanal.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPluginBinding binding) {
        if (kanal != null) kanal.setMethodCallHandler(null);
        kanal = null;
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        aktivite = binding.getActivity();
        uygula();
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        aktivite = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        aktivite = binding.getActivity();
        uygula();
    }

    @Override
    public void onDetachedFromActivity() {
        aktivite = null;
    }

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if ("koru".equals(call.method)) {
            Object a = call.arguments;
            koru = a instanceof Boolean && (Boolean) a;
            uygula();
            result.success(true);
        } else if ("kayitVar".equals(call.method)) {
            result.success(false);
        } else {
            result.notImplemented();
        }
    }

    private void uygula() {
        final Activity a = aktivite;
        if (a == null) return;
        final boolean acik = koru;
        a.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (acik) {
                    a.getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
                } else {
                    a.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_SECURE);
                }
            }
        });
    }
}
