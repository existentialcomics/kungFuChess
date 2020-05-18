var intervalOpenGames;
var intervalPool;
var intervalGames;
var intervalPlayers;

var games = {};
var chatContent = $('#chatlog');

var currentGameUid = "";
var isConnected = false;

var openGamesRunning = false;
var cancelOpenGames = false;
function getOpenGames(originalThread = false) {
    if (cancelOpenGames) {
        openGamesRunning = false;
        cancelOpenGames = false;
        return ;
    }
    var setInterval = originalThread;
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
                    if (jsonRes.hasOwnProperty('anonKey')) {
                        window.location.replace('/game/' + jsonRes.matchedGame + "?anonKey=" + jsonRes.anonKey);
                    } else {
                        window.location.replace('/game/' + jsonRes.matchedGame);
                    }
                } else {
                    $('#openGamesContent').html(jsonRes.body);
                    //console.log("no gameId in jsonRes");
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

var activeGamesRunning = false;
var cancelActiveGames= false;
function getActiveGames(originalThread = false) {
    if (cancelActiveGames) {
        activeGamesRunning = false;
        cancelActiveGames = false;
        return ;
    }
    var setInterval = originalThread;
    if (activeGamesRunning == false) {
        activeGamesRunning = true;
        setInterval = true;
    }
    if (document.getElementById('activeGamesContent')) {
        var urlActiveGames = '/ajax/activeGames';
        if (currentGameUid) {
            urlActiveGames += '?uid=' + currentGameUid;
        }
        $.ajax({
            type : 'GET',
            url  : urlActiveGames,
            dataType : 'json',
            success : function(data){
                var jsonRes = data;
                $('#activeGamesContent').html(jsonRes.body);
                if (setInterval == true) {
                    intervalActiveGames = setTimeout(
                        function() {
                            getActiveGames(true);
                        },
                        2500
                    );
                }
            }
        });
    }
}

var ratingToggle = 'standard';
var getPlayersRunning = false;
function getPlayers(originalThread = false) {
    var setInterval = originalThread;
    if (getPlayersRunning == false) {
        getPlayersRunning = true;
        setInterval = true;
    }
    if (document.getElementById('playersContent')) {
        $.ajax({
            type : 'GET',
            url  : '/activePlayers?ratingType=' + ratingToggle,
            dataType : 'html',
            success : function(data){
                $('#playersContent').html(data);
                if (setInterval) {
                    intervalPlayer = setTimeout(
                        function() {
                            getPlayers(true);
                        },
                        4000
                    );
                }
            }
        });
    }
}

var checkPoolRunning = false;
var checkPoolGameSpeed = 'standard';
var cancelCheckPool = false;
function checkPool(originalThread = false) {
    if (cancelCheckPool) {
        checkPoolRunning = false;
        cancelCheckPool = false;
        return ;
    }
    var setInterval = originalThread;
    if (checkPoolRunning == false) {
        checkPoolRunning = true;
        setInterval = true;
    }
    $.ajax({
        type : 'GET',
        url  : '/ajax/pool/' + checkPoolGameSpeed,
        dataType : 'json',
        success : function(data){
            var jsonRes = data;
            if (jsonRes.hasOwnProperty('gameId')) {
                window.location.replace('/game/' + jsonRes.gameId);
            }
            if (setInterval) {
                intervalPlayer = setTimeout(
                    function() {
                        checkPool(true);
                    },
                    2000
                );
            }
        }
    });
}

//$(document).ready(function () {
$(function () {
    $("#enter-pool-standard").click(function() {
        if (checkPoolRunning && checkPoolGameSpeed == 'standard') {
            cancelCheckPool = true;
            $(this).html('Standard Pool');
        } else {
            $(this).html('Standard Pool<br /><span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>');
            $("#enter-pool-lightning").html('Lighting Pool');
            checkPoolGameSpeed = 'standard'
            checkPool();
        }
    });
    $("#enter-pool-lightning").click(function() {
        if (checkPoolRunning && checkPoolGameSpeed == 'lightning') {
            cancelCheckPool = true;
            $(this).html('Lightning Pool');
        } else {
            $(this).html('Lightning Pool<br /><span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>');
            $("#enter-pool-standard").html('Standard Pool');
            checkPoolGameSpeed = 'lightning'
            checkPool();
        }
    });

    $("#showStandardRating").click(function() {
        $("#showLightningRating").removeClass('active');
        $("#showStandardRating").addClass('active');
        ratingToggle = 'standard';
        getPlayers();
    });
  
    $("#showLightningRating").click(function() {
        $("#showLightningRating").addClass('active');
        $("#showStandardRating").removeClass('active');
        ratingToggle = 'lightning';
        getPlayers();
    });
  
    $("#showPool").click(function() {
        $("#showOpenGames").removeClass('active');
        $("#showActiveGames").removeClass('active');
        $("#showPool").addClass('active');
        $("#openGamesContent").hide();
        $("#activeGamesContent").hide();
        $("#createGameFormDiv").hide();
        $("#pool-matching").show();
        cancelActiveGames = true;
        cancelOpenGames = true;
    });
  
    $("#showOpenGames").click(function() {
        $("#showOpenGames").addClass('active');
        $("#showActiveGames").removeClass('active');
        $("#showPool").removeClass('active');
        $("#activeGamesContent").hide();
        $("#pool-matching").hide();
        cancelActiveGames = true;
        cancelCheckPool = true;
        $("#enter-pool-lighting").html('Lighting Pool');
        $("#enter-pool-standard").html('Standard Pool');

        cancelOpenGames = false;
        getOpenGames();
        $("#createGameFormDiv").hide();
        $("#openGamesContent").show();
    });
  
    $("#showActiveGames").click(function() {
        $("#showActiveGames").addClass('active');
        $("#showOpenGames").removeClass('active');
        $("#showPool").removeClass('active');
        $("#pool-matching").hide();
        cancelOpenGames = true;
        cancelCheckPool = true;
        $("#enter-pool-lighting").html('Lighting Pool');
        $("#enter-pool-standard").html('Standard Pool');

        cancelActiveGames = false;
        getActiveGames();
        $("#createGameFormDiv").hide();
        $("#openGamesContent").hide();
        $("#activeGamesContent").show();
    });
  
    $("#homeContent").delegate('#createGameBtn', 'click', function() {
        $("#pool-matching").hide();
        $("#openGamesContent").hide();
        $("#createGameFormDiv").show();
    });
  
    $("#homeContent").delegate('.watch-game-row', 'click', function() {
        var url = $(this).data('href');
        window.location.replace(url);
    });
  
    $("#homeContent").delegate('.join-game-row', 'click', function() {
        var url = $(this).data('href');
        $.ajax({
            type : 'GET',
            url  : url,
            dataType : 'json',
            success : function(data){
                var jsonRes = data;
                if (jsonRes.hasOwnProperty('gameId')) {
                    if (jsonRes.hasOwnProperty('anonKey')) {
                        window.location.replace('/game/' + jsonRes.gameId + "?anonKey=" + jsonRes.anonKey);
                    } else {
                        window.location.replace('/game/' + jsonRes.gameId);
                    }
                } else {
                    //console.log("no gameId in jsonRes");
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
        var url = $(this).data('href');
        $.ajax({
            type : 'GET',
            url  : url,
            dataType : 'json',
            success : function(data){
                var jsonRes = data;
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
        e.preventDefault();
        $("#pool-matching").hide();
        $("#openGamesContent").hide();
        $("#createGameFormDev").show();
        $.ajax({
            type : 'POST',
            url  : '/ajax/createChallenge',
            data: $("#createGameForm").serialize(),
            dataType : 'json',
            success : function(data){
                var jsonRes = data;
                if (jsonRes.hasOwnProperty('uid')) {
                    currentGameUid = jsonRes.uid;
                }
                if (jsonRes.hasOwnProperty('gameId')) {
                    if (jsonRes.hasOwnProperty('anonKey')) {
                        window.location.replace('/game/' + jsonRes.gameId + "?anonKey=" + jsonRes.anonKey);
                    } else {
                        window.location.replace('/game/' + jsonRes.gameId);
                    }
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
        $.ajax({
            type : 'POST',
            url  : '/ajax/chat',
            data: dataPost,
            dataType : 'json',
            success : function(data){
                if (data.hasOwnProperty('message')) {
                    var dt = new Date();
                    addChatMessage(
                        'SYSTEM',
                        data.message,
                        'red',
                        'red',
                        dt
                    );
                }
            }
        });
    });

    $('#global-chat-input').keyup(function(e){
        if(e.keyCode == 13)
        {
            $(this).trigger("enterKey");
        }
    });

    getPlayers();

});


var bindEvents = function(ws_conn) {
    main_conn.onopen = function(evt) {
        // finished main_connecting.
        // maybe query for ready to join
        isConnected = true;
        $("#connectionStatus").html("Connected");
        pingServer = setInterval(function() {
            if (isConnected) {
                heartbeat_msg = {
                    "c" : "main_ping"
                };
                sendGlobalMsg(heartbeat_msg);
            } 
        }, 3000); 
    }

    main_conn.onmessage = function(evt) {
        var msg = JSON.parse(evt.data);
        if (msg.c == 'globalchat'){
            //console.log(msg);
            var dt = new Date();
            addChatMessage(
                msg.author,
                msg.message,
                (msg.color ? msg.color : 'green'),
                'black',
                dt
            );
        } else if (msg.c == 'privatechat'){
            var dt = new Date();
            addChatMessage(
                msg.author,
                msg.message,
                (msg.color ? msg.color : 'green'),
                'purple',
                dt
            );
            // if the game is open we add to the game chat
            if (typeof addGameMessage == "function") { 
                addGameMessage(
                    msg.author,
                    msg.message,
                    (msg.color ? msg.color : 'green'),
                    'purple',
                    dt
                );
            }
        } 
    }

    main_conn.onclose = function() {
        isConnected = false;
        reconnectInterval = setTimeout(
            reconnectMain,
            1000
        );
    }
}

var main_conn = new WebSocket("ws://" + wsDomain + ":3000/ws");
bindEvents(main_conn);

var reconnectInterval;
var reconnectMain = function() {
    if (isConnected == false) {
        $("#connectionStatus").html("Reconnecting...");
        main_conn = null;
        main_conn = new WebSocket("ws://" + wsDomain + ":3000/ws");
        bindEvents(main_conn);
    } else {
        reconnectInterval = null;
    }
}

sendGlobalMsg = function(msg) {
    msg.userAuthToken = userAuthToken;
    main_conn.send(JSON.stringify(msg));
}

function escapeHtml(html){
    var text = document.createTextNode(html);
    var p = document.createElement('p');
    p.appendChild(text);
    return p.innerHTML;
}

/**
 * Add message to the chat window
 */
function addChatMessage(author, message, usercolor, textcolor, dt) {
    chatContent = $('#global-chat-log');
    chatContent.append('<p><span class="' + usercolor + 'beltColor">' + author + '</span><span style="font-size: 12px;color:grey"> ' +
            + (dt.getHours() < 10 ? '0' + dt.getHours() : dt.getHours()) + ':'
            + (dt.getMinutes() < 10 ? '0' + dt.getMinutes() : dt.getMinutes())
            + '</span>&nbsp;&nbsp;<span class="color:' + textcolor + '">' + escapeHtml(message) + '</span>' + '</p>');
    chatContent.scrollTop = chatContent.scrollHeight;
}
