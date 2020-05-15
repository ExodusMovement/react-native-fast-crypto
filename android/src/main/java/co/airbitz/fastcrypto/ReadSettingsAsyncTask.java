package co.airbitz.fastcrypto;

import android.os.AsyncTask;

import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.WritableMap;

import java.io.File;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

public class ReadSettingsAsyncTask extends AsyncTask<Void, Void, Void> {
    private final String directory;
    private final String filePrefix;
    private final Promise promise;

    public ReadSettingsAsyncTask(String directory, String filePrefix, Promise promise) {
        this.directory = directory;
        this.filePrefix = filePrefix;
        this.promise = promise;
    }

    @Override
    protected Void doInBackground(Void... voids) {
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
                return null;
            }

            responseMap.putInt("size", values.size());
            responseMap.putInt("oldest", Collections.min(values));
            responseMap.putInt("latest", Collections.max(values));

            promise.resolve(responseMap);
        } catch (Exception ex) {
            ex.printStackTrace();
            promise.reject("Err", ex);
        }

        return null;
    }
}
