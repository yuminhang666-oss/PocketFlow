package cn.pocketflow.testmailsink;
import android.app.Activity;
import android.os.Bundle;
import android.content.Intent;
import android.widget.TextView;
import android.widget.ScrollView;
import org.json.JSONArray;
import org.json.JSONObject;
import java.nio.charset.StandardCharsets;

/** Isolated emulator fixture. No INTERNET permission and no send function. */
public final class MailSinkActivity extends Activity {
  @Override public void onCreate(Bundle state) {
    super.onCreate(state);
    try {
      Intent intent=getIntent();
      JSONObject value=new JSONObject();
      value.put("fixture","SYNTHETIC email handoff; does not send");
      value.put("action",intent.getAction());
      value.put("uri",String.valueOf(intent.getData()));
      String[] recipients=intent.getStringArrayExtra(Intent.EXTRA_EMAIL);
      value.put("to",recipients==null?new JSONArray():new JSONArray(java.util.Arrays.asList(recipients)));
      value.put("subject",intent.getStringExtra(Intent.EXTRA_SUBJECT));
      value.put("body",intent.getStringExtra(Intent.EXTRA_TEXT));
      value.put("hasAttachments",intent.hasExtra(Intent.EXTRA_STREAM)||intent.getClipData()!=null);
      try(java.io.FileOutputStream file=openFileOutput("last-intent.json",MODE_PRIVATE)){
        file.write(value.toString(2).getBytes(StandardCharsets.UTF_8));
      }
      TextView text=new TextView(this);
      text.setText("SYNTHETIC EMAIL TEST SINK\nDOES NOT SEND EMAIL\n\n"+value.toString(2));
      text.setTextSize(18);text.setPadding(24,24,24,24);
      ScrollView scroll=new ScrollView(this);scroll.addView(text);setContentView(scroll);
    } catch(Exception error) {TextView text=new TextView(this);text.setText("SYNTHETIC fixture failed");setContentView(text);}
  }
}
