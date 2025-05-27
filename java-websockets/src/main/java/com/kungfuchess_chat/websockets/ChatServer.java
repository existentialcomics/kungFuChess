package com.kungfuchess_chat.websockets;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.net.InetSocketAddress;
import java.net.UnknownHostException;
import java.nio.ByteBuffer;
import java.util.Collections;
import org.java_websocket.WebSocket;
import org.java_websocket.drafts.Draft;
import org.java_websocket.drafts.Draft_6455;
import org.java_websocket.handshake.ClientHandshake;
import org.java_websocket.server.WebSocketServer;
import org.json.JSONObject;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.PreparedStatement;
import java.sql.ResultSet;

import java.io.FileInputStream;
import java.io.IOException;
import java.util.Properties;

/**
 * A simple WebSocketServer implementation. Keeps track of a "chatroom".
 */
public class ChatServer extends WebSocketServer {
	private Connection sqlConn = null;
	private String mysqlUrl;
	private String mysqlUser;
	private String mysqlPass;

	public static void main(String[] args) throws InterruptedException, IOException {
		int port = 8887; // 843 flash policy port
		try {
			port = Integer.parseInt(args[0]);
		} catch (Exception ex) {
		}
		ChatServer s = new ChatServer(port);
		s.init();
		s.start();
		System.out.println("ChatServer started on port: " + s.getPort());

		BufferedReader sysin = new BufferedReader(new InputStreamReader(System.in));
		while (true) {
			String in = sysin.readLine();
			s.broadcast(in);
			if (in.equals("exit")) {
				s.stop(1000);
				break;
			}
		}
	}

	public void init() {
		System.out.println("Initializing all data ...");
		initDatabaseConnection();
	}

	public ChatServer(int port) throws UnknownHostException {
		super(new InetSocketAddress(port));
	}

	public ChatServer(InetSocketAddress address) {
		super(address);
	}

	public ChatServer(int port, Draft_6455 draft) {
		super(new InetSocketAddress(port), Collections.<Draft>singletonList(draft));
	}

	public Connection getConnection() {
		if (sqlConn == null) {
			initDatabaseConnection();
		}
		return sqlConn;
	}

	private void loadMysqlConfig() {
		String filePath = "websockets.properties";

		Properties properties = new Properties();

		try (FileInputStream input = new FileInputStream(filePath)) {
			properties.load(input);

			mysqlUrl = properties.getProperty("db.url");
			mysqlUser = properties.getProperty("db.username");
			mysqlPass = properties.getProperty("db.password");

		} catch (IOException ex) {
			ex.printStackTrace();
		}
	}

	public void initDatabaseConnection() {
		loadMysqlConfig();

		System.out.println("Connecting database ...");

		try {
			sqlConn = DriverManager.getConnection(mysqlUrl, mysqlUser, mysqlPass);
			System.out.println("Database connected!");
		} catch (SQLException e) {
			throw new IllegalStateException("Cannot connect the database!", e);
		}
	}

	@Override
	public void onOpen(WebSocket conn, ClientHandshake handshake) {
		conn.send("Welcome to the server!"); // This method sends a message to the new client

		// This method sends a message to all clients connected
		// broadcast("new connection: " + handshake.getResourceDescriptor());
		System.out.println(conn.getRemoteSocketAddress().getAddress().getHostAddress() + " entered the room!");
	}

	@Override
	public void onClose(WebSocket conn, int code, String reason, boolean remote) {
		// broadcast(conn + " has left the room!");
		System.out.println(conn + " has left the room!");
	}

	Statement stmt = null;
	ResultSet rs = null;

	@Override
	public void onMessage(WebSocket conn, String message) {
		// broadcast(message);
		JSONObject jsonObject = new JSONObject(message);
		String category = jsonObject.getString("c");
		System.out.println(conn + ": category: " + category);
		if (category.equals("main_ping")) {
			handlePing(conn, jsonObject);
		} else if (category.equals("chat")) {
			handleChat(conn, jsonObject);
		}
		System.out.println(conn + ": (string)" + message);
	}

	public void handlePing(WebSocket conn, JSONObject jsonObject) {
		String auth = jsonObject.getString("userAuthToken");
		if (auth != null) {
			if (auth.startsWith("anon_")) {
				
			} else {
				try {
					stmt = sqlConn.createStatement();
					PreparedStatement stmtGetPlayer = sqlConn
							.prepareStatement("SELECT * from players WHERE auth_token = ?");
					stmtGetPlayer.setString(1, auth);
					ResultSet playerRs = stmtGetPlayer.executeQuery();
					Player player = new Player(playerRs);

					String getPlayerGameSql = "SELECT game_id FROM games"
							+ "WHERE (white_player = ? OR black_player = ? OR red_player = ? OR green_player = ?)"
							+ "AND (status ='active' OR status = 'waiting to begin')";
					
					PreparedStatement stmtGetGame = sqlConn.prepareStatement(getPlayerGameSql);
					stmtGetGame.setInt(1, player.getId());
					stmtGetGame.setInt(2, player.getId());
					stmtGetGame.setInt(3, player.getId());
					stmtGetGame.setInt(4, player.getId());
					
					ResultSet activeGameRs = stmtGetGame.executeQuery();

					// stmt.execute("UPDATE players SET last_seen = NOW(), ip_address = ? WHERE
					// player_id = ?");
				} catch (SQLException ex) {
					// handle any errors
					System.out.println("SQLException: " + ex.getMessage());
					System.out.println("SQLState: " + ex.getSQLState());
					System.out.println("VendorError: " + ex.getErrorCode());
				}
			}
		}
	}

	public void handleChat(WebSocket conn, JSONObject jsonObject) {
		String auth = jsonObject.getString("userAuthToken");
		String inMessage = jsonObject.getString("message");
		if (auth == null) {
			return;
		}

		String userId = "1";
		String screenname = "testuser";
		String message = inMessage; // clean swear words here
		JSONObject jsonChat = new JSONObject();

		jsonChat.put("c", "globalchat");
		jsonChat.put("user_id", userId);
		jsonChat.put("screenname", screenname);
		jsonChat.put("message", message);
		broadcast(jsonChat.toString());
	}

	// commands like /help
	public static void handleChatCommand() {
	}

	@Override
	public void onMessage(WebSocket conn, ByteBuffer message) {
		broadcast(message.array());
		System.out.println(conn + ": (byte buffer)" + message);
	}

	@Override
	public void onError(WebSocket conn, Exception ex) {
		ex.printStackTrace();
		if (conn != null) {
			// some errors like port binding failed may not be assignable to a specific
			// websocket
		}
	}

	@Override
	public void onStart() {
		System.out.println("Server started!");
		setConnectionLostTimeout(0);
		setConnectionLostTimeout(100);
	}
}