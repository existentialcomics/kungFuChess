package com.kungfuchess_chat.websockets;
import java.sql.ResultSet;
import java.sql.SQLException;

public class Player {
	private String screenname;
	private int id;
	private int rating_standard;
	private int rating_lightning;
	private int rating_standard_4way;
	private int rating_lightning_4way;
	
	public Player(int id) {
		
	}
	
	public Player(String auth_token) {
		
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
