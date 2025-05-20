import org.apache.log4j.Logger;

import javax.websocket.CloseReason;
import javax.websocket.OnClose;
import javax.websocket.OnError;
import javax.websocket.OnMessage;
import javax.websocket.OnOpen;
import javax.websocket.Session;
import javax.websocket.server.ServerEndpoint;
import java.io.IOException;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;

            //String classpath = System.getProperty("java.class.path");
            //System.out.println(classpath);
            //System.out.println("----------------\n");
            //String url = "jdbc:mysql://localhost:3306/kungfuchess";
            //String username = "corey";
            //String password = "kazhonno";

            //System.out.println("Connecting database ...");

            //try (Connection connection = DriverManager.getConnection(url, username, password)) {
                //System.out.println("Database connected!");
            //} catch (SQLException e) {
                //throw new IllegalStateException("Cannot connect the database!", e);
            //}


@ServerEndpoint("/toUpper")
public class ToUpperWebsocket {

  private static final Logger LOGGER = Logger.getLogger(ToUpperWebsocket.class);

  @OnOpen
  public void onOpen(Session session) {
    LOGGER.debug(String.format("WebSocket opened: %s", session.getId()));
  }

  @OnMessage
  public void onMessage(String txt, Session session) throws IOException {
    LOGGER.debug(String.format("Message received: %s", txt));
    session.getBasicRemote().sendText(txt.toUpperCase());
  }

  @OnClose
  public void onClose(CloseReason reason, Session session) {
    LOGGER.debug(String.format("Closing a WebSocket (%s) due to %s", session.getId(), reason.getReasonPhrase()));
  }

  @OnError
  public void onError(Session session, Throwable t) {
    LOGGER.error(String.format("Error in WebSocket session %s%n", session == null ? "null" : session.getId()), t);
  }
}
