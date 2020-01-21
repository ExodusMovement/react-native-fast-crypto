package co.airbitz.fastcrypto;

import android.os.Build;
import android.util.Log;

//import com.facebook.react.BuildConfig;
import com.facebook.react.bridge.Promise;

import org.json.JSONObject;

import java.io.DataInputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.ByteBuffer;

public class KeygenAsyncTask extends android.os.AsyncTask<Void, Void, Void> {

  static {

    // this loads the library when the class is loaded
    System.loadLibrary("nativecrypto");
    System.loadLibrary("crypto_bridge"); // this loads the library when the class is loaded
  }

  private final String method;
  private final String jsonParams;
  private final String userAgent;
  private final Promise promise;

  public KeygenAsyncTask(String method, String jsonParams, String userAgent, Promise promise) {
    this.method = method;
    this.jsonParams = jsonParams;
    this.userAgent = userAgent;
    this.promise = promise;
  }

  public native String keygenJNI(String method, String jsonParams);

  @Override
  protected Void doInBackground(Void... voids) {
    try {
      String reply = keygenJNI(method, jsonParams); // test response from JNI
      promise.resolve(reply);
    } catch (Exception e) {
      promise.reject("Err", e);
    }
    return null;
  }
};
