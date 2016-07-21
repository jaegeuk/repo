package esos.ResultListControl;

import java.io.*;
import java.net.*;

import android.app.*;
import android.os.*;
import android.util.Log;


public class UpdateData extends Activity {
	private static final String DEBUG="net_access";
	@Override
	public void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		Log.d(DEBUG, "create updatadata ");

		//HttpPostData("10","10","10","10","10","10","10");
		Log.d(DEBUG, "fin");
	}

	public void HttpPostData(String seq_w, String seq_r, String ran_w, String ran_r, String sq_in
			, String sq_up, String sq_del, String sn, String c_partition, String c_thread, String c_file_size_w
			, String c_file_size_r, String c_io_size, String c_file_mode, String c_tran, String c_sqlite_mode
			, String c_sqlite_journal, String c_filesystem, String def) {
		try {
			URL url = new URL(
					"http://mobibench.dothome.co.kr/insert_data.php"); // URL
			HttpURLConnection http = (HttpURLConnection) url.openConnection(); // ����

			http.setDefaultUseCaches(false);
			http.setDoInput(true);
			http.setDoOutput(true);
			http.setRequestMethod("POST");


			http.setRequestProperty("content-type","application/x-www-form-urlencoded");

			StringBuffer buffer = new StringBuffer();
			String device = Build.MODEL + " - " + "Android " + Build.VERSION.RELEASE;


			buffer.append("device").append("=").append(device).append("&");
			buffer.append("seq_w").append("=").append(seq_w).append("&");
			buffer.append("seq_r").append("=").append(seq_r).append("&");
			buffer.append("ran_w").append("=").append(ran_w).append("&");
			buffer.append("ran_r").append("=").append(ran_r).append("&");
			buffer.append("sq_in").append("=").append(sq_in).append("&");
			buffer.append("sq_up").append("=").append(sq_up).append("&");
			buffer.append("sq_del").append("=").append(sq_del).append("&");
			buffer.append("sn").append("=").append(sn).append("&"); //�ӽ�

			buffer.append("c_partition").append("=").append(c_partition).append("&");
			buffer.append("c_thread").append("=").append(c_thread).append("&");
			buffer.append("c_file_size_w").append("=").append(c_file_size_w).append("&");
			buffer.append("c_file_size_r").append("=").append(c_file_size_r).append("&");
			buffer.append("c_io_size").append("=").append(c_io_size).append("&");
			buffer.append("c_file_mode").append("=").append(c_file_mode).append("&");
			buffer.append("c_tran").append("=").append(c_tran).append("&");
			buffer.append("c_sqlite_mode").append("=").append(c_sqlite_mode).append("&");
			buffer.append("c_sqlite_journal").append("=").append(c_sqlite_journal).append("&");
			buffer.append("c_filesystem").append("=").append(c_filesystem).append("&");
			buffer.append("def").append("=").append(def);


			OutputStreamWriter outStream = new OutputStreamWriter(
					http.getOutputStream(), "EUC-KR");
			PrintWriter writer = new PrintWriter(outStream);
			writer.write(buffer.toString());

			writer.flush();

			// --------------------------
			// �������� ���۹ޱ�
			// --------------------------
			InputStreamReader tmp = new InputStreamReader(
					http.getInputStream(), "EUC-KR");
			BufferedReader reader = new BufferedReader(tmp);
			StringBuilder builder = new StringBuilder();
			String str;
			while ((str = reader.readLine()) != null) { // �������� ���δ����� ������ ���̹Ƿ�
				//Log.d(DEBUG, "[url] str : " + str);	// ���δ����� �д´�
				builder.append(str + "\n"); // View�� ǥ���ϱ� ���� ���� ������ �߰�
			}



		} catch (MalformedURLException e) {
			//
		} catch (IOException e) {
			//
		} // try
	} // HttpPostData
} // Activity