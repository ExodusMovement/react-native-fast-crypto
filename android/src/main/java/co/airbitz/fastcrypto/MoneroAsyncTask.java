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
import java.io.IOException;
import java.util.function.BiFunction;

import java.util.concurrent.atomic.AtomicBoolean;

public class MoneroAsyncTask extends android.os.AsyncTask<Void, Void, Void> {

    static {

        //this loads the library when the class is loaded
        System.loadLibrary("nativecrypto");
        System.loadLibrary("crypto_bridge"); //this loads the library when the class is loaded
    }

    private final String method;
    private final String jsonParams;
    private final String userAgent;
    private final Promise promise;
    private final AtomicBoolean isStopped;

    public MoneroAsyncTask(String method, String jsonParams, String userAgent, AtomicBoolean isStopped, Promise promise) {
        this.method = method;
        this.jsonParams = jsonParams;
        this.userAgent = userAgent;
        this.promise = promise;
        this.isStopped = isStopped;
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
                        if (isStopped.get()) { 
                            promise.reject("Err", new Exception("Operations are stopped"));
                            return null; 
                        }
                        outputStream.write(requestBuffer.get(i));
                    }
                }
                connection.connect();

                String contentLengthStr = connection.getHeaderField("Content-Length");
                int responseLength = validateContentLengthHeader(contentLengthStr);
                try (DataInputStream dataInputStream = new DataInputStream(connection.getInputStream())) {
                    String out = readAndProcessData(dataInputStream, responseLength, this::extractUtxosFromBlocksResponse);
                    promise.resolve(out);
                }
            } catch (Exception e) {
                promise.reject("Err", e);
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

                String contentLengthStr = connection.getHeaderField("Content-Length");
                int responseLength = validateContentLengthHeader(contentLengthStr);
                try (DataInputStream dataInputStream = new DataInputStream(connection.getInputStream())) {
                    String out = readAndProcessData(dataInputStream, responseLength, this::extractUtxosFromClarityBlocksResponse);
                    promise.resolve(out);
                }
            } catch (Exception e) {
                promise.reject("Err", e);
            } finally {
                if (connection != null) {
                    connection.disconnect();
                }
            }
            return null;
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

    private int validateContentLengthHeader(String contentLengthStr) throws Exception {
        if (contentLengthStr == null) {
            throw new Exception("Missing Content-Length header");
        }
    
        try {
            int contentLength = Integer.parseInt(contentLengthStr);
            if (contentLength < 0) {
                throw new Exception("Invalid Content-Length header");
            }
            // Maximum size set to 100 MB
            int maxContentLength = 100 * 1024 * 1024; // 100 MB
            if (contentLength > maxContentLength) {
                throw new Exception("Content-Length exceeds allowed maximum of 100 MB");
            }
            return contentLength;
        } catch (NumberFormatException e) {
            throw new Exception("Cannot parse Content-Length header");
        }
    }
    

    private String readAndProcessData(DataInputStream dataInputStream, int responseLength, BiFunction<ByteBuffer, String, String> extractUtxos) throws Exception {
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
            promise.reject("Err", new Exception("Processing stopped"));
            return null;
        }

        ByteBuffer responseBuffer = ByteBuffer.allocateDirect(responseLength);
        responseBuffer.put(bytes, 0, responseLength);
        String out = extractUtxos.apply(responseBuffer, jsonParams);
        if (out == null) {
            throw new Exception("Internal error: Memory allocation failed");
        }

        if (isStopped.get()) {
            throw new Exception("Operations are stopped");
        }

        return out;
    }
};
