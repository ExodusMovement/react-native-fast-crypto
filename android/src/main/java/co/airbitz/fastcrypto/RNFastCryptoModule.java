
package co.airbitz.fastcrypto;

import android.os.AsyncTask;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;

public class RNFastCryptoModule extends ReactContextBaseJavaModule {

    private final ReactApplicationContext reactContext;
    private final String userAgent;

    static {
        System.loadLibrary("secp256k1");
        System.loadLibrary("crypto_bridge"); // this loads the library when the class is loaded
      }
    public native String secp256k1EcPubkeyCreateJNI(String privateKeyHex, int compressed);

    public native String secp256k1EcPrivkeyTweakAddJNI(String privateKeyHex, String tweakHex);
  
    public native String secp256k1EcPubkeyTweakAddJNI(
        String publicKeyHex, String tweakHex, int compressed);
    
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
    public void readSettings(final String directory, final String filePrefix, final Promise promise) {
        AsyncTask task = new ReadSettingsAsyncTask(directory, filePrefix, promise);
        task.executeOnExecutor(AsyncTask.THREAD_POOL_EXECUTOR, null);
    }

    @ReactMethod
    public void secp256k1EcPubkeyCreate(String privateKeyHex, Boolean compressed, Promise promise) {
      int iCompressed = compressed ? 1 : 0;
      try {
        String reply =
            secp256k1EcPubkeyCreateJNI(privateKeyHex, iCompressed); // test response from JNI
        promise.resolve(reply);
      } catch (Exception e) {
        promise.reject("Err", e);
      }
    }
  
    @ReactMethod
    public void secp256k1EcPrivkeyTweakAdd(String privateKeyHex, String tweakHex, Promise promise) {
      try {
        String reply =
            secp256k1EcPrivkeyTweakAddJNI(privateKeyHex, tweakHex); // test response from JNI
        promise.resolve(reply);
      } catch (Exception e) {
        promise.reject("Err", e);
      }
    }
  
    @ReactMethod
    public void secp256k1EcPubkeyTweakAdd(
        String publicKeyHex, String tweakHex, Boolean compressed, Promise promise) {
      int iCompressed = compressed ? 1 : 0;
      try {
        String reply =
            secp256k1EcPubkeyTweakAddJNI(
                publicKeyHex, tweakHex, iCompressed); // test response from JNI
        promise.resolve(reply);
      } catch (Exception e) {
        promise.reject("Err", e);
      }
    }
}
