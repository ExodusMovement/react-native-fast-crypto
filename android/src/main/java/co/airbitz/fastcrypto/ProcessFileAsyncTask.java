package co.airbitz.fastcrypto;

import com.facebook.react.bridge.Promise;

public class ProcessFileAsyncTask extends android.os.AsyncTask<Void, Void, String> {
    private ByteBuffer buffer;
    private String jsonParams;
    private Promise promise;

    public ProcessFileAsyncTask(ByteBuffer data, String jsonParams, Promise promise) {
        this.data = data;
        this.jsonParams = jsonParams;
        this.promise = promise;
    }

    @Override
    protected String doInBackground(Void... voids) {
        String out = extractUtxosFromClarityBlocksResponse(responseBuffer, jsonParams);
        if (out == null) {
            promise.reject("Err", new Exception("Internal error: Memory allocation failed"));
        } else {
            promise.resolve(out);
        }
    }
}