package dev.uynx.siteblock;

import android.app.admin.DeviceAdminReceiver;
import android.app.admin.DevicePolicyManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.os.Bundle;
import android.os.UserHandle;
import android.util.Log;
import java.io.InputStream;
import java.util.Collections;
import java.util.Iterator;
import org.json.JSONArray;
import org.json.JSONObject;

// Applies assets/policy.json on becoming device owner and on every reinstall; the system keeps each policy across reboots.
// Ceiling: entries dropped from policy.json stay applied on the phone until cleared by hand.
public class Admin extends DeviceAdminReceiver {
  @Override
  public void onReceive(Context c, Intent i) {
    super.onReceive(c, i);
    PendingResult done = goAsync();
    new Thread(() -> {
      apply(c);
      done.finish();
    }).start();
  }

  static synchronized void apply(Context c) {
    DevicePolicyManager dpm = c.getSystemService(DevicePolicyManager.class);
    boolean owner = dpm.isDeviceOwnerApp(c.getPackageName());
    if (!owner && !dpm.isProfileOwnerApp(c.getPackageName())) return;
    try (InputStream in = c.getAssets().open("policy.json")) {
      JSONObject p = new JSONObject(new String(in.readAllBytes(), "UTF-8"));
      ComponentName a = new ComponentName(c, Admin.class);
      dpm.setAffiliationIds(a, Collections.singleton(c.getPackageName()));
      JSONObject apps = p.getJSONObject("appRestrictions");
      for (Iterator<String> k = apps.keys(); k.hasNext(); ) {
        String pkg = k.next();
        dpm.setApplicationRestrictions(a, pkg, bundle(apps.getJSONObject(pkg)));
      }
      JSONArray h = p.optJSONArray("hidden");
      if (h != null) {
        for (int n = 0; n < h.length(); n++) dpm.setApplicationHidden(a, h.getString(n), true);
      }
      JSONArray u = p.optJSONArray("unhide");
      if (u != null) {
        for (int n = 0; n < u.length(); n++) dpm.setApplicationHidden(a, u.getString(n), false);
      }
      if (!owner) return;
      if (p.has("updateProfile") && dpm.getSecondaryUsers(a).isEmpty()) {
        UserHandle updater = dpm.createAndManageUser(a, p.getString("updateProfile"), a, null,
            DevicePolicyManager.SKIP_SETUP_WIZARD | DevicePolicyManager.LEAVE_ALL_SYSTEM_APPS_ENABLED);
        dpm.startUserInBackground(a, updater);
      }
      JSONArray r = p.getJSONArray("userRestrictions");
      for (int n = 0; n < r.length(); n++) dpm.addUserRestriction(a, r.getString(n));
      int dns = dpm.setGlobalPrivateDnsModeSpecifiedHost(a, p.getString("privateDns"));
      Log.i("siteblock", "applied, private DNS result " + dns);
    } catch (Exception e) {
      Log.e("siteblock", "apply failed", e);
    }
  }

  static Bundle bundle(JSONObject o) throws Exception {
    Bundle b = new Bundle();
    for (Iterator<String> k = o.keys(); k.hasNext(); ) {
      String key = k.next();
      Object v = o.get(key);
      if (v instanceof Boolean) b.putBoolean(key, (Boolean) v);
      else if (v instanceof Integer) b.putInt(key, (Integer) v);
      else if (v instanceof JSONObject) b.putBundle(key, bundle((JSONObject) v));
      else if (v instanceof JSONArray) {
        JSONArray arr = (JSONArray) v;
        String[] s = new String[arr.length()];
        for (int n = 0; n < s.length; n++) s[n] = arr.getString(n);
        b.putStringArray(key, s);
      } else b.putString(key, v.toString());
    }
    return b;
  }
}
