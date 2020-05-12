
package co.airbitz.fastcrypto;

import android.os.AsyncTask;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.WritableMap;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class RNFastCryptoModule extends ReactContextBaseJavaModule {

    private final ReactApplicationContext reactContext;
    private final String userAgent;

    public RNFastCryptoModule(ReactApplicationContext reactContext, String userAgent) {
        super(reactContext);
        this.reactContext = reactContext;
        this.userAgent = userAgent;
    }

    @Override
    public String getName() {
        return "RNFastCrypto";
    }

    @ReactMethod
    public void moneroCore(
            final String method,
            final String jsonParams,
            final Promise promise) {
        AsyncTask task = new MoneroAsyncTask(method, jsonParams, userAgent, promise);
        task.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR, null);
    }

    @ReactMethod
    public void readSettings(String directory, String filePrefix, Promise promise) {
        try {
            File file = new File(directory);

            if (!file.exists()) throw new Exception("Folder does not exist");

            File[] files = file.listFiles();

            List<Integer> values = new ArrayList<>();

            for (File childFile : files) {
                String fileName = childFile.getName();
                if (!fileName.startsWith(filePrefix) || !fileName.endsWith(".json") || fileName.contains("enabled")) continue;

                String name = fileName.replace(filePrefix, "").replace(".json", "");

                values.add(Integer.parseInt(name));
            }

            WritableMap responseMap = Arguments.createMap();

            if (values.size() == 0) {
                promise.resolve(responseMap);
                return;
            }

            responseMap.putInt("size", values.size());
            responseMap.putInt("oldest", Collections.min(values));
            responseMap.putInt("latest", Collections.max(values));

            promise.resolve(responseMap);
        } catch (Exception ex) {
            ex.printStackTrace();
            promise.reject("Err", ex);
        }
    }

}
