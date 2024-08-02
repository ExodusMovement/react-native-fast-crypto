
package co.airbitz.fastcrypto;

import android.os.AsyncTask;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import java.util.concurrent.atomic.AtomicBoolean;

public class RNFastCryptoModule extends ReactContextBaseJavaModule {

    private final ReactApplicationContext reactContext;
    private final String userAgent;
    private AtomicBoolean isStopped = new AtomicBoolean(false); 

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
        if ("stop_processing_task".equals(method)) {
            isStopped.set(true);
            promise.resolve("{\"success\":true}");
        } else {
            AsyncTask task = new MoneroAsyncTask(method, jsonParams, userAgent, promise);
            task.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR, null);
        }
    }

    @ReactMethod
    public void readSettings(final String directory, final String filePrefix, final Promise promise) {
        AsyncTask task = new ReadSettingsAsyncTask(directory, filePrefix, promise);
        task.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR, null);
    }

}
