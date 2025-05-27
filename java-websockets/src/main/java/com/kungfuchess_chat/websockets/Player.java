package com.kungfuchess_chat.websockets;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;

public class Player {
	private String screenname;
	private int id;
	private int rating_standard;
	private int rating_lightning;
	private int rating_standard_4way;
	private int rating_lightning_4way;
	
	public Player(int id, Connection sqlConn) throws SQLException {
		PreparedStatement stmtGetPlayer = sqlConn
				.prepareStatement("SELECT * from players WHERE id = ?");
		stmtGetPlayer.setInt(1, id);
		ResultSet playerRs = stmtGetPlayer.executeQuery();
	}
	
	public Player(String auth_token, Connection sqlConn) throws SQLException {
		PreparedStatement stmtGetPlayer = sqlConn
				.prepareStatement("SELECT * from players WHERE auth_token = ?");
		stmtGetPlayer.setString(1, auth_token);
		ResultSet playerRs = stmtGetPlayer.executeQuery();

	}
	
	public int getId() {
		return id;
	}
	
	public Player(ResultSet rs) throws SQLException {
		id = rs.getInt(1);
		screenname = rs.getString(2);
		rating_standard = rs.getInt(3);
		rating_lightning = rs.getInt(4);
		rating_standard_4way = rs.getInt(5);
		rating_lightning_4way = rs.getInt(6);
	}
}
