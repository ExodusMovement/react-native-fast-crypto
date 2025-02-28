package co.airbitz.fastcrypto;

import android.os.AsyncTask;
import android.util.Log;

import com.facebook.react.bridge.Promise;

import org.json.JSONObject;

import java.io.BufferedInputStream;
import java.io.ByteArrayOutputStream;
import java.io.DataInputStream;
import java.io.InputStream;
import java.io.IOException;
import java.io.OutputStream;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.ByteBuffer;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.BiFunction;

public class MoneroAsyncTask extends android.os.AsyncTask<Void, Void, Void> {
    final long MAX_BYTES = 100L * 1024L * 1024L; // 100 MB

    static {

        // this loads the library when the class is loaded
        System.loadLibrary("nativecrypto");
        System.loadLibrary("crypto_bridge"); // this loads the library when the class is loaded
    }

    private final String method;
    private final String jsonParams;
    private final String userAgent;
    private final Promise promise;
    private final AtomicBoolean isStopped;

    public MoneroAsyncTask(String method, String jsonParams, String userAgent, AtomicBoolean isStopped,
            Promise promise) {
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
                
                if (requestLength == -1) {
                    throw new Exception("Invalid ByteBuffer passed to native method.");
                } else if (requestLength == -2) {
                    throw new Exception("Failed to get ByteBuffer capacity.");
                } else if (requestLength == -3) {
                    throw new Exception("Failed to create blocks request.");
                } else if (requestLength == -4) {
                    throw new Exception("Buffer capacity is too small for the generated request.");
                }
            
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
                            throw new Exception("Operations are stopped");
                        }
                        outputStream.write(requestBuffer.get(i));
                    }
                }
                connection.connect();

                String contentLengthStr = connection.getHeaderField("Content-Length");
                int responseLength = validateContentLengthHeader(contentLengthStr);
                try (DataInputStream dataInputStream = new DataInputStream(connection.getInputStream())) {
                    String out = readAndProcessBinaryData(dataInputStream, responseLength,
                            this::extractUtxosFromBlocksResponse);
                    promise.resolve(out);
                }
            } catch (Exception e) {
                String detailedError = String.format(
                        "{\"err_msg\":\"Exception occurred: %s\"}",
                        e.getMessage() != null ? e.getMessage() : "Unknown exception");
                promise.resolve(detailedError);
            } finally {
                if (connection != null) {
                    connection.disconnect();
                }
            }
            return null;
        } else if (method.equals("download_from_clarity_and_process")) {
            HttpURLConnection connection = null;
            try {
                // Parse the JSON parameters
                JSONObject params = new JSONObject(jsonParams);
                String addr = params.getString("url");
                URL url = new URL(addr);

                // Set up the HTTP connection
                connection = (HttpURLConnection) url.openConnection();
                connection.setRequestMethod("GET");
                connection.setRequestProperty("User-Agent", userAgent);
                connection.setConnectTimeout(10000);
                connection.setReadTimeout(4 * 60 * 1000);

                connection.connect();

                // Check the response code
                int responseCode = connection.getResponseCode();
                if (responseCode != HttpURLConnection.HTTP_OK) {
                    // Read the error stream if available
                    String errorMessage = readErrorStreamAsString(connection);
                    String detailedError = String.format(
                            "{\"err_msg\":\"[Clarity] HTTP Error %d: %s\"}",
                            responseCode,
                            errorMessage.isEmpty() ? "Unknown error" : errorMessage);
                    promise.resolve(detailedError);
                    return null;
                }

                try (InputStream inputStream = new BufferedInputStream(connection.getInputStream(), 8192)) {
                    String result = readAndProcessJsonData(inputStream, this::extractUtxosFromClarityBlocksResponse);

                    if (result == null) {
                        throw new Exception("Processing failed");
                    } else {
                        promise.resolve(result);
                    }
                }
            } catch (Exception e) {
                String detailedError = String.format(
                        "{\"err_msg\":\"Exception occurred: %s\"}",
                        e.getMessage() != null ? e.getMessage() : "Unknown exception");
                promise.resolve(detailedError);
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
            if (contentLength > MAX_BYTES) {
                throw new Exception("Content-Length exceeds allowed maximum of 100 MB");
            }
            return contentLength;
        } catch (NumberFormatException e) {
            throw new Exception("Cannot parse Content-Length header");
        }
    }

    private String readAndProcessBinaryData(DataInputStream dataInputStream, int responseLength,
            BiFunction<ByteBuffer, String, String> extractUtxos) throws Exception {
        ByteArrayOutputStream buffer = new ByteArrayOutputStream();
        byte[] tmp = new byte[8192];

        int nRead = 0;
        while (buffer.size() < responseLength) {
            if (isStopped.get()) {
                throw new Exception("Downloading stopped by user");
            }
            nRead = dataInputStream.read(tmp, 0, Math.min(tmp.length, responseLength - buffer.size()));
            if (nRead == -1) {
                throw new Exception("Unexpected end of stream");
            }
            buffer.write(tmp, 0, nRead);
        }

        // Check for cancellation after download is complete
        if (isStopped.get()) {
            throw new Exception("Processing stopped by user");
        }

        ByteBuffer responseBuffer = null;
        try {
            responseBuffer = ByteBuffer.allocateDirect(responseLength);
            responseBuffer.put(buffer.toByteArray(), 0, responseLength);

            String out = extractUtxos.apply(responseBuffer, jsonParams);
            if (out == null) {
                throw new Exception("Internal error: Memory allocation failed");
            }

            if (isStopped.get()) {
                throw new Exception("Operations are stopped");
            }

            return out;
        } finally {
            if (responseBuffer != null) {
                responseBuffer.clear();
            }
        }
    }

    private String readAndProcessJsonData(InputStream inputStream, BiFunction<ByteBuffer, String, String> extractUtxos)
            throws Exception {
        try {
            byte[] jsonBytes = readInputStreamAsBytes(inputStream);

            // Convert JSON string to ByteBuffer
            ByteBuffer responseBuffer = ByteBuffer.allocateDirect(jsonBytes.length);
            responseBuffer.put(jsonBytes);
            responseBuffer.flip(); // Prepare the buffer for reading

            // Process the JSON data
            String out = extractUtxos.apply(responseBuffer, jsonParams);
            if (out == null) {
                throw new Exception("Internal error: Memory allocation failed");
            }

            return out;
        } catch (IOException e) {
            throw new Exception("Error reading JSON data: " + e.getMessage(), e);
        }
    }

    /**
     * Reads an InputStream fully and converts it to a byte array.
     */
    private byte[] readInputStreamAsBytes(InputStream inputStream) throws IOException {
        ByteArrayOutputStream byteArrayOutputStream = new ByteArrayOutputStream(8192);
        byte[] buffer = new byte[8192]; // 8 KB read buffer
        int bytesRead;
        long totalBytesRead = 0;

        while ((bytesRead = inputStream.read(buffer)) != -1) {
            if (isStopped.get()) {
                throw new IOException("Downloading stopped by user");
            }
            totalBytesRead += bytesRead;
            if (totalBytesRead > MAX_BYTES) {
                throw new IOException("Input stream exceeded maximum allowed size of 100 MB");
            }
            
            byteArrayOutputStream.write(buffer, 0, bytesRead);
        }
        return byteArrayOutputStream.toByteArray();
    }

    /**
     * Reads the error stream from the HTTP connection and converts it to a String.
     */
    private String readErrorStreamAsString(HttpURLConnection connection) {
        try (InputStream errorStream = connection.getErrorStream()) {
            if (errorStream != null) {
                return new String(readInputStreamAsBytes(errorStream), "UTF-8");
            }
        } catch (IOException e) {
            return "Failed to read error stream";
        }
        return "";
    }
};
