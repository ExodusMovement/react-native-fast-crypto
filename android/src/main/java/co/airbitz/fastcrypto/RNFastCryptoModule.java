
package co.airbitz.fastcrypto;

import android.os.AsyncTask;
import android.util.Log;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;

import org.json.JSONObject;

import java.io.DataInputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.ByteBuffer;


public class RNFastCryptoModule extends ReactContextBaseJavaModule {

    //this loads the library when the class is loaded
    static {
        System.loadLibrary("nativecrypto");
        System.loadLibrary("crypto_bridge"); //this loads the library when the class is loaded
    }
    public native String moneroCoreJNI(String method, String jsonParams);
    public native int moneroCoreCreateRequest(ByteBuffer requestBuffer, int height);
    public native String extractUtxosFromBlocksResponse(ByteBuffer buffer, String jsonParams);

    private final ReactApplicationContext reactContext;

    public RNFastCryptoModule(ReactApplicationContext reactContext) {
        super(reactContext);
        this.reactContext = reactContext;
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
        AsyncTask.execute(new Runnable() {
            @Override
            public void run() {
                if (method.equals("download_and_process")) {
                    try {
                        JSONObject params = new JSONObject(jsonParams);
                        String addr = params.getString("url");
                        int startHeight = params.getInt("start_height");

                        ByteBuffer requestBuffer = ByteBuffer.allocateDirect(1000);
                        int requestLength = moneroCoreCreateRequest(requestBuffer, startHeight);

                        URL url = new URL(addr);
                        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
                        connection.setRequestMethod("POST");
                        connection.setRequestProperty("Content-Type", "application/octet-stream");
                        connection.setDoOutput(true);

                        try (OutputStream outputStream = connection.getOutputStream()) {
                            for (int i = 0; i < requestLength; i++) {
                                outputStream.write(requestBuffer.get(i));
                            }
                        }

                        connection.connect();

                        String contentLength = connection.getHeaderField("Content-Length");
                        int responseLength = Integer.parseInt(contentLength);

                        try (DataInputStream dataInputStream = new DataInputStream(connection.getInputStream())) {
                            byte[] bytes = new byte[responseLength];
                            dataInputStream.readFully(bytes);

                            ByteBuffer responseBuffer = ByteBuffer.allocateDirect(responseLength);
                            responseBuffer.put(bytes, 0, responseLength);

                            String out = extractUtxosFromBlocksResponse(responseBuffer, jsonParams);
                            promise.resolve(out);
                        }
                    } catch (Exception e) {
                        promise.reject("Err", e);
                    }

                    return;
                }

                try {
                    String reply = moneroCoreJNI(method, jsonParams); // test response from JNI
                    promise.resolve(reply);
                } catch (Exception e) {
                    promise.reject("Err", e);
                }
            }
        });
    }
}
