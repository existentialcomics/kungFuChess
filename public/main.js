var interval;
var intervalPool;

var games = {};
var chatContent = $('#chatlog');

function getGames() {
    if (document.getElementById('gamesContent')) {
        $.ajax({
            type : 'GET',
            url  : '/games',
            dataType : 'html',
            success : function(data){
                $('#gamesContent').html(data);
                //console.log('success');
                interval = setTimeout(getGames, 1000)
            }
        });
    } else {
        interval = setTimeout(getGames, 1000)
    }
}

var ratingToggle = 'standard';
function getPlayers() {
    if (document.getElementById('playersContent')) {
        $.ajax({
            type : 'GET',
            url  : '/activePlayers?ratingType=' + ratingToggle,
            dataType : 'html',
            success : function(data){
                $('#playersContent').html(data);
                //console.log('success');
                interval = setTimeout(getPlayers, 3000)
            }
        });
    } else {
        interval = setTimeout(getPlayers, 3000)
    }
}

//$(document).ready(function () {
$(function () {
    console.log("document.ready");
    $("#enter-pool").click(function() {
        console.log('check pool click');
        checkPool();
    });

    $("#showStandardRating").click(function() {
        console.log('show standard');
        $("#showLightningRating").removeClass('active');
        $("#showStandardRating").addClass('active');
        ratingToggle = 'standard';
        getPlayers();
    });
  
    $("#showLightningRating").click(function() {
        console.log('show light');
        $("#showLightningRating").addClass('active');
        $("#showStandardRating").removeClass('active');
        ratingToggle = 'lightning';
        getPlayers();
    });
  
  
    // global chat in lobby
    $('#global-chat-input').bind("enterKey",function(e){
        var dataPost = { 'message' : $(this).val() };
        $(this).val('');
        console.log('global chat bind');
        $.ajax({
            type : 'POST',
            url  : '/ajax/chat',
            data: dataPost,
            dataType : 'html',
            success : function(data){
            }
        });
    });

    console.log('here');

    $('#global-chat-input').keyup(function(e){
        console.log('global chat keypress');
        if(e.keyCode == 13)
        {
            console.log('global chat enter');
            $(this).trigger("enterKey");
        }
    });

    getPlayers();

});

function checkPool() {
    console.log('check pool');
    $("#enter-pool").html('<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>');
    $.ajax({
        type : 'GET',
        url  : '/ajax/pool',
        dataType : 'json',
        success : function(data){
            var jsonRes = data;
            console.log(jsonRes);
            if (jsonRes.hasOwnProperty('gameId')) {
                window.location.replace('/game/' + jsonRes.gameId);
            }
            intervalPool = setTimeout(checkPool, 1000)
        }
    });

}


console.log("main_connecting...");
var main_conn = new WebSocket("ws://www1.existentialcomics.com:3000/ws");

main_conn.onopen = function(evt) {
	// finished main_connecting.
	// maybe query for ready to join
	console.log("main_connected! main.js");
    pingServer = setInterval(function() {
        heartbeat_msg = {
            "c" : "ping"
        };
        main_conn.send(JSON.stringify(heartbeat_msg));
    }, 2000); 
}

main_conn.onmessage = function(evt) {
    console.log("msg: " + evt.data);

	var msg = JSON.parse(evt.data);
    if (msg.c == 'globalchat'){
        console.log("chat recieved");
        var dt = new Date();
        addChatMessage(
            msg.author,
            msg.message,
            "green",
            dt
        );
    }
    registerConnection();
}

// registers the websocket connection to a user
// so this conneciton can get user based messages back
// from the server (such as DM)
var registerConnection = function(){
    var ret = {
        'c' : 'registerConnection',
        'screenname' : screenname
    };
    sendGlobalMsg(ret);
}

sendGlobalMsg = function(msg) {
    msg.userAuthToken = userAuthToken;
    main_conn.send(JSON.stringify(msg));
}

/**
 * Add message to the chat window
 */
function addChatMessage(author, message, color, dt) {
    console.log(author + ", " + message);
    console.debug(chatContent);
    chatContent = $('#chatlog');
    console.debug(dt);
    chatContent.append('<p><span style="color:' + color + '">' + author + '</span> @ ' +
            + (dt.getHours() < 10 ? '0' + dt.getHours() : dt.getHours()) + ':'
            + (dt.getMinutes() < 10 ? '0' + dt.getMinutes() : dt.getMinutes())
            + ': ' + message + '</p>');
    chatContent.scrollTop = chatContent.scrollHeight;
    console.log('done chat append');
}
