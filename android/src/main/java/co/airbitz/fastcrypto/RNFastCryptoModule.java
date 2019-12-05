
package co.airbitz.fastcrypto;

import android.os.AsyncTask;
import android.util.Log;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.bridge.Callback;

import java.io.InputStream;
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
    public native int moneroCoreCreateRequest(ByteBuffer requestBuffer);
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
                    ByteBuffer requestBuffer = ByteBuffer.allocateDirect(1000);
                    int requestLength = moneroCoreCreateRequest(requestBuffer);

                    try {
                        URL url = new URL("https://xmr.exodus-prod.io/get_blocks.bin");
                        HttpURLConnection connection = (HttpURLConnection) url.openConnection();
                        connection.setRequestMethod("POST");
                        connection.setRequestProperty("Content-Type", "application/octet-stream");
                        connection.setDoInput(true);
                        connection.setDoOutput(true);

                        OutputStream outputStream = connection.getOutputStream();
                        for (int i = 0; i < requestLength; i++) {
                            outputStream.write(requestBuffer.get(i));
                        }

                        outputStream.close();
                        connection.connect();

                        String contentLength = connection.getHeaderField("Content-Length");
                        int responseLength = Integer.parseInt(contentLength);

                        InputStream inputStream = connection.getInputStream();

                        byte[] bytes = new byte[responseLength];
                        inputStream.read(bytes, 0, responseLength);

                        ByteBuffer responseBuffer = ByteBuffer.allocateDirect(responseLength);
                        responseBuffer.put(bytes, 0, responseLength);

                        String out = extractUtxosFromBlocksResponse(responseBuffer, jsonParams);

                        promise.resolve(out);
                        return;
                    } catch(Exception ex) {
                        promise.resolve(ex.toString());
                        return;
                    }
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
