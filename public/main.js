var intervalOpenGames;
var intervalPool;
var intervalGames;
var intervalPlayers;

var games = {};
var chatContent = $('#chatlog');

var openGamesRunning = false;
var currentGameUid = "";

function getOpenGames(originalThread = false) {
    var setInterval = originalThread;
    console.log("orig: " + originalThread);
    if (openGamesRunning == false) {
        openGamesRunning = true;
        setInterval = true;
    }
    if (document.getElementById('openGamesContent')) {
        var urlOpenGames = '/ajax/openGames';
        if (currentGameUid) {
            urlOpenGames += '?uid=' + currentGameUid;
        }
        $.ajax({
            type : 'GET',
            url  : urlOpenGames,
            dataType : 'json',
            success : function(data){
                var jsonRes = data;
                if (jsonRes.hasOwnProperty('matchedGame')) {
                    console.log("redirecting to game...");
                    if (jsonRes.hasOwnProperty('anonKey')) {
                        window.location.replace('/game/' + jsonRes.matchedGame + "?anonKey=" + jsonRes.anonKey);
                    } else {
                        window.location.replace('/game/' + jsonRes.matchedGame);
                    }
                } else {
                    $('#openGamesContent').html(jsonRes.body);
                    console.log("no gameId in jsonRes");
                }
                if (setInterval == true) {
                    intervalOpenGames = setTimeout(
                        function() {
                            getOpenGames(true);
                        },
                        1000
                    );
                }
            }
        });
    }
}

function getGames() {
    if (document.getElementById('gamesContent')) {
        $.ajax({
            type : 'GET',
            url  : '/games',
            dataType : 'html',
            success : function(data){
                $('#gamesContent').html(data);
                intervalGames = setTimeout(getGames, 1000)
            }
        });
    } else {
        intervalGames = setTimeout(getGames, 1000)
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
                intervalePlayer = setTimeout(getPlayers, 3000)
            }
        });
    } else {
        intervalePlayer = setTimeout(getPlayers, 3000)
    }
}

//$(document).ready(function () {
$(function () {
    console.log("document.ready");
    $("#enter-pool-standard").click(function() {
        console.log('check pool click');
        checkPool('standard', 'enter-pool-standard');
    });
    $("#enter-pool-lightning").click(function() {
        console.log('check pool click');
        checkPool('lightning', 'enter-pool-lightning');
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
  
    $("#showPool").click(function() {
        console.log('show pool');
        $("#showOpenGames").removeClass('active');
        $("#showPool").addClass('active');
        $("#openGamesContent").hide();
        $("#createGameFormDiv").hide();
        $("#pool-matching").show();
    });
  
    $("#showOpenGames").click(function() {
        console.log('show games');
        $("#showOpenGames").addClass('active');
        $("#showPool").removeClass('active');
        $("#pool-matching").hide();
        getOpenGames();
        $("#createGameFormDiv").hide();
        $("#openGamesContent").show();
    });
  
    $("#homeContent").delegate('#createGameBtn', 'click', function() {
        console.log("show create form");
        $("#pool-matching").hide();
        $("#openGamesContent").hide();
        $("#createGameFormDiv").show();
    });
  
    $("#homeContent").delegate('.join-game-row', 'click', function() {
        console.log("join game row");
        console.log(this);
        var url = $(this).data('href');
        console.log(url);
        $.ajax({
            type : 'GET',
            url  : url,
            dataType : 'json',
            success : function(data){
                var jsonRes = data;
                console.log(jsonRes);
                console.log(data);
                if (jsonRes.hasOwnProperty('gameId')) {
                    console.log("redirecting to game...");
                    if (jsonRes.hasOwnProperty('anonKey')) {
                        window.location.replace('/game/' + jsonRes.gameId + "?anonKey=" + jsonRes.anonKey);
                    } else {
                        window.location.replace('/game/' + jsonRes.gameId);
                    }
                } else {
                    console.log("no gameId in jsonRes");
                }
                $("#showOpenGames").addClass('active');
                $("#showPool").removeClass('active');
                $("#pool-matching").hide();
                getOpenGames();
                $("#createGameFormDiv").hide();
                $("#openGamesContent").show();
            }
        });
    });
  
    $("#homeContent").delegate('.cancel-game-row', 'click', function() {
        console.log("cancel game row");
        console.log(this);
        var url = $(this).data('href');
        console.log(url);
        $.ajax({
            type : 'GET',
            url  : url,
            dataType : 'json',
            success : function(data){
                var jsonRes = data;
                console.log(jsonRes);
                console.log(data);
                $("#showOpenGames").addClass('active');
                $("#showPool").removeClass('active');
                $("#pool-matching").hide();
                getOpenGames();
                $("#createGameFormDiv").hide();
                $("#openGamesContent").show();
            }
        });
    });

    $("#homeContent").delegate('#createGameSubmit', 'click', function(e) {
        console.log("submit create game");
        e.preventDefault();
        $("#pool-matching").hide();
        $("#openGamesContent").hide();
        $("#createGameFormDev").show();
        console.log($("#createGameForm").serialize());
        $.ajax({
            type : 'POST',
            url  : '/ajax/createChallenge',
            data: $("#createGameForm").serialize(),
            dataType : 'json',
            success : function(data){
                var jsonRes = data;
                console.log("createChallenge success");
                console.log(jsonRes);
                if (jsonRes.hasOwnProperty('uid')) {
                    console.log("setting uid");
                    currentGameUid = jsonRes.uid;
                }
                $("#showOpenGames").addClass('active');
                $("#showPool").removeClass('active');
                $("#pool-matching").hide();
                getOpenGames();
                $("#createGameFormDiv").hide();
                $("#openGamesContent").show();
            }
        });
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

function checkPool(gameSpeed, elementId) {
    console.log('check pool');
    $("#" + elementId).html('<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>');
    $.ajax({
        type : 'GET',
        url  : '/ajax/pool/' + gameSpeed,
        dataType : 'json',
        success : function(data){
            var jsonRes = data;
            if (jsonRes.hasOwnProperty('gameId')) {
                window.location.replace('/game/' + jsonRes.gameId);
            }
            intervalPool = setTimeout(function() {
                checkPool(gameSpeed, elementId);
            }, 1000)
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
