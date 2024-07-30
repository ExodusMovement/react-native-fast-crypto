package co.airbitz.fastcrypto;

import android.os.Build;
import android.util.Log;

//import com.facebook.react.BuildConfig;
import com.facebook.react.bridge.Promise;

import org.json.JSONObject;

import java.io.DataInputStream;
import java.io.OutputStream;
import java.io.ByteArrayOutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.ByteBuffer;

public class MoneroAsyncTask extends android.os.AsyncTask<Void, Void, Void> {

    static {

        //this loads the library when the class is loaded
        System.loadLibrary("nativecrypto");
        System.loadLibrary("crypto_bridge"); //this loads the library when the class is loaded
    }

    private static final AtomicBoolean isStopped = new AtomicBoolean(false); // Default is allow to process any incoming tasks from JS

    private final String method;
    private final String jsonParams;
    private final String userAgent;
    private final Promise promise;

    public MoneroAsyncTask(String method, String jsonParams, String userAgent, Promise promise) {
        this.method = method;
        this.jsonParams = jsonParams;
        this.userAgent = userAgent;
        this.promise = promise;
    }

    public native String moneroCoreJNI(String method, String jsonParams);
    public native int moneroCoreCreateRequest(ByteBuffer requestBuffer, int height);
    public native String extractUtxosFromBlocksResponse(ByteBuffer buffer, String jsonParams);
    public native String extractUtxosFromClarityBlocksResponse(ByteBuffer buffer, String jsonParams);
    public native String getTransactionPoolHashes(ByteBuffer buffer);

    @Override
    protected Void doInBackground(Void... voids) {
        if (method.equals("download_and_process")) {
            HttpURLConnection connection = null;
            try {
                JSONObject params = new JSONObject(jsonParams);
                String addr = params.getString("url");
                int startHeight = params.getInt("start_height");
                ByteBuffer requestBuffer = ByteBuffer.allocateDirect(1000);
                int requestLength = moneroCoreCreateRequest(requestBuffer, startHeight);
                URL url = new URL(addr);
                connection = (HttpURLConnection) url.openConnection();
                connection.setRequestMethod("POST");
                connection.setRequestProperty("Content-Type", "application/octet-stream");
                connection.setRequestProperty("User-Agent", userAgent);
                connection.setConnectTimeout(10000);
                connection.setReadTimeout(4 * 60 * 1000);
                connection.setDoOutput(true);
                try (OutputStream outputStream = connection.getOutputStream()) {
                    for (int i = 0; i < requestLength; i++) {
                        outputStream.write(requestBuffer.get(i));
                    }
                }
                connection.connect();

                if (isStopped.get()) { 
                    promise.reject("Err", new Exception("Download cancelled by user."));
                    return null; 
                }

                String contentLength = connection.getHeaderField("Content-Length");
                int responseLength = Integer.parseInt(contentLength);
                try (DataInputStream dataInputStream = new DataInputStream(connection.getInputStream())) {
                    byte[] bytes = new byte[responseLength];
                    int bytesRead = 0;
                    int offset = 0;

                    // Check for cancellation periodically during download
                    while (bytesRead != -1 && offset < responseLength) { 
                        if (isStopped.get()) {
                            promise.reject("Err", new Exception("Download stopped by user."));
                            return null;
                        }
                        bytesRead = dataInputStream.read(bytes, offset, responseLength - offset);
                        offset += bytesRead;
                    }
                    
                    // Check for cancellation after download is complete
                    if (isStopped.get()) { 
                        promise.reject("Err", new Exception("Processing are stopped"));
                        return null; 
                    }

                    ByteBuffer responseBuffer = ByteBuffer.allocateDirect(responseLength);
                    responseBuffer.put(bytes, 0, responseLength);
                    String out = extractUtxosFromBlocksResponse(responseBuffer, jsonParams);
                    if (out == null) {
                        promise.reject("Err", new Exception("Internal error: Memory allocation failed"));
                    } else {
                        promise.resolve(out);
                    }
                }
            } catch (Exception e) {
                if (e instanceof IOException && isStopped.get()) {
                    promise.reject("Err", new Exception("Download cancelled by user."));
                } else {
                    promise.reject("Err", e);
                }
            }  finally {
                if (connection != null) {
                    connection.disconnect();
                }
            }
            return null;
        } else if (method.equals("download_from_clarity_and_process")) {
            HttpURLConnection connection = null;
            try {
                JSONObject params = new JSONObject(jsonParams);
                String addr = params.getString("url");
                URL url = new URL(addr);
                connection = (HttpURLConnection) url.openConnection();
                connection.setRequestMethod("GET");
                connection.setRequestProperty("User-Agent", userAgent);
                connection.setConnectTimeout(10000);
                connection.setReadTimeout(4 * 60 * 1000);

                connection.connect();

                if (isStopped.get()) { 
                    promise.reject("Err", new Exception("Download cancelled by user."));
                    return null; 
                }

                String contentLength = connection.getHeaderField("Content-Length");
                int responseLength = contentLength != null ? Integer.parseInt(contentLength) : 0;
                if (responseLength > 0) {
                    try (DataInputStream dataInputStream = new DataInputStream(connection.getInputStream())) {
                        byte[] bytes = new byte[responseLength];
                        int bytesRead = 0;
                        int offset = 0;

                        // Check for cancellation periodically during download
                        while (bytesRead != -1 && offset < responseLength) { 
                            if (isStopped.get()) {
                                promise.reject("Err", new Exception("Download stopped by user."));
                                return null;
                            }
                            bytesRead = dataInputStream.read(bytes, offset, responseLength - offset);
                            offset += bytesRead;
                        }

                        // Check for cancellation after download is complete
                        if (isStopped.get()) { 
                            promise.reject("Err", new Exception("Processing are stopped"));
                            return null; 
                        }

                        ByteBuffer responseBuffer = ByteBuffer.allocateDirect(responseLength);
                        responseBuffer.put(bytes, 0, responseLength);
                        String out = extractUtxosFromClarityBlocksResponse(responseBuffer, jsonParams);
                        if (out == null) {
                            promise.reject("Err", new Exception("Internal error: Memory allocation failed"));
                        } else {
                            promise.resolve(out);
                        }
                    }
                } else {
                    promise.reject("Err", new Exception("Invalid or no content length"));
                }
            } catch (Exception e) {
                if (e instanceof IOException && isStopped.get()) {
                    promise.reject("Err", new Exception("Download cancelled by user."));
                } else {
                    promise.reject("Err", e);
                }
            } finally {
                if (connection != null) {
                    connection.disconnect();
                }
            }
            return null;
        } else if (method.equals("allow_processing_task")) {
            isStopped.set(false);
            promise.resolve("{\"success\":true}");
        } else if (method.equals("stop_processing_task")) {
            isStopped.set(true);
            promise.resolve("{\"success\":true}");
        } else if (method.equals("get_transaction_pool_hashes")) {
            try {
                JSONObject params = new JSONObject(jsonParams);
                String addr = params.getString("url");
                URL url = new URL(addr);
                HttpURLConnection connection = (HttpURLConnection) url.openConnection();
                connection.setRequestMethod("POST");
                connection.setRequestProperty("User-Agent", userAgent);
                connection.setConnectTimeout(5000);
                connection.setReadTimeout(5000);
                connection.connect();
                try (DataInputStream dataInputStream = new DataInputStream(connection.getInputStream())) {
                    ByteArrayOutputStream buffer = new ByteArrayOutputStream();

                    int totalBytes = 0;
                    byte[] tmp = new byte[8192];

                    int nRead = 0;
                    while ((nRead = dataInputStream.read(tmp, 0, tmp.length)) != -1) {
                        buffer.write(tmp, 0, nRead);
                        totalBytes += nRead;
                    }

                    ByteBuffer responseBuffer = ByteBuffer.allocateDirect(totalBytes);
                    responseBuffer.put(buffer.toByteArray(), 0, totalBytes);
                    String out = getTransactionPoolHashes(responseBuffer);
                    promise.resolve(out);
                }
            } catch (Exception e) {
                promise.reject("Err", e);
            }
            return null;
        }
        try {
            String reply = moneroCoreJNI(method, jsonParams); // test response from JNI
            promise.resolve(reply);
        } catch (Exception e) {
            promise.reject("Err", e);
        }
        return null;
    }
};
