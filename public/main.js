var intervalOpenGames;
var intervalPool;
var intervalGames;
var intervalPlayers;

var games = {};
var chatContent = $('#chatlog');

var currentGameUid = "";
var isConnected = false;
var chatLog = [];

var openGamesRunning = false;
var cancelOpenGames = false;

var checkPoolRunning = false;
var checkPoolGameSpeed = 'standard';
var checkPoolGameType = '2way';
var cancelCheckPool = false;

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
                } else if (jsonRes.hasOwnProperty('uid')) {
                    console.log('has uid in match games we matched but didnt create');
                    currentGameUid = jsonRes.uid;
                } else {
                    $('#openGamesContent').html(jsonRes.body);
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
        console.log("setting standard interval");
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

function checkPool(originalThread = false) {
    if (cancelCheckPool) {
        checkPoolRunning = false;
        cancelCheckPool = false;
        console.log('cancelCheckPool set');
        return ;
    }
    var setInterval = originalThread;
    if (checkPoolRunning == false) {
        checkPoolRunning = true;
        setInterval = true;
    }
    console.log('making ajax');
    $.ajax({
        type : 'GET',
        url  : '/ajax/pool/' + checkPoolGameSpeed + "/" + checkPoolGameType,
        dataType : 'json',
        success : function(data){
            var jsonRes = data;
            if (jsonRes.hasOwnProperty('gameId')) {
                window.location.replace('/game/' + jsonRes.gameId);
            }
        }
    }).always(function() {
        if (setInterval) {
            intervalPlayer = setTimeout(
                function() {
                    checkPool(true);
                },
                2000
            );
        } else {

        }
    });
}

//$(document).ready(function () {
$(function () {
    $("#enter-pool-standard").click(function() {
        if (checkPoolRunning
            && checkPoolGameSpeed == 'standard'
            && checkPoolGameType  == '2way'
        ) {
            cancelCheckPool = true;
            $(this).html('Standard Pool');
            console.log('stopping standard');
        } else {
            cancelCheckPool = false;
            console.log('starting standard');
            $(this).html('Standard Pool<br /><span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>');
            $("#enter-pool-lightning").html('Lighting Pool');
            $("#enter-pool-4way-standard").html('Standard 4way Pool');
            $("#enter-pool-4way-lightning").html('Lighting 4way Pool');
            checkPoolGameSpeed = 'standard';
            checkPoolGameType  = '2way';
            checkPool();
        }
    });
    $("#enter-pool-lightning").click(function() {
        if (checkPoolRunning
            && checkPoolGameSpeed == 'lightning'
            && checkPoolGameType  == '2way'
        ) {
            cancelCheckPool = true;
            $(this).html('Lightning Pool');
        } else {
            cancelCheckPool = false;
            $(this).html('Lightning Pool<br /><span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>');
            $("#enter-pool-standard").html('Standard Pool');
            $("#enter-pool-4way-standard").html('Standard 4way Pool');
            $("#enter-pool-4way-lightning").html('Lighting 4way Pool');
            checkPoolGameSpeed = 'lightning';
            checkPoolGameType  = '2way';
            checkPool();
        }
    });
    $("#enter-pool-4way-standard").click(function() {
        if (checkPoolRunning
            && checkPoolGameSpeed == 'standard'
            && checkPoolGameType  == '4way'
        ) {
            cancelCheckPool = true;
            $(this).html('Standard 4way Pool');
        } else {
            cancelCheckPool = false;
            $(this).html('Standard 4way Pool<br /><span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>');
            $("#enter-pool-standard").html('Standard Pool');
            $("#enter-pool-lightning").html('Lighting Pool');
            $("#enter-pool-4way-lightning").html('Lighting 4way Pool');
            checkPoolGameSpeed = 'standard';
            checkPoolGameType  = '4way';
            checkPool();
        }
    });
    $("#enter-pool-4way-lightning").click(function() {
        if (checkPoolRunning
            && checkPoolGameSpeed == 'lightning'
            && checkPoolGameType  == '4way'
        ) {
            cancelCheckPool = true;
            $(this).html('Lightning 4way Pool');
        } else {
            cancelCheckPool = false;
            $(this).html('Lightning 4way Pool<br /><span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>');
            $("#enter-pool-standard").html('Standard Pool');
            $("#enter-pool-lightning").html('Lighting Pool');
            $("#enter-pool-4way-standard").html('Standard 4way Pool');
            checkPoolGameSpeed = 'lightning';
            checkPoolGameType  = '4way';
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
                } else if (jsonRes.hasOwnProperty('uid')) {
                    currentGameUid = jsonRes.uid;
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
        var dataPost = {
            'message' : $(this).val(),
            'uid' : currentGameUid,
        };
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
        } else if (msg.c == 'invite'){
            showInvite(msg.uid, msg.screenname, msg.gameSpeed, msg.gameType, msg.rated);
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

var main_conn = new WebSocket(wsProtocol + "://" + wsDomainMain + "/ws");
bindEvents(main_conn);

var reconnectInterval;
var reconnectMain = function() {
    if (isConnected == false) {
        $("#connectionStatus").html("Reconnecting...");
        main_conn = null;
        main_conn = new WebSocket(wsProtocol + "://" + wsDomainMain + "/ws");
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

function showInvite(uid, screenname, gameSpeed, gameType, rated) {
    chatContent = $('#global-chat-log');
    chatContent.append('<a href="/matchGame/' + uid + '">' + screenname + ' invited you to a game (' + gameType + ' ' + gameSpeed + ' ' + (rated ? 'rated' : 'unrated') + ') click to accept</a><br />');
    $("#global-chat-log").scrollTop($("#global-chat-log")[0].scrollHeight);
}

/**
 * Add message to the chat window
 */
function addChatMessage(author, message, usercolor, textcolor, dt) {
    var dtString = ' ';
    if (! isNaN(dt.getTime())) {
        dtString =
            (dt.getHours() < 10 ? '0' + dt.getHours() : dt.getHours()) + ':' +
            (dt.getMinutes() < 10 ? '0' + dt.getMinutes() : dt.getMinutes());
    }
    chatContent = $('#global-chat-log');
    chatContent.append('<span class="' + usercolor + 'beltColor">' + author + '</span><span style="font-size: 12px;color:grey"> ' + dtString 
            + '</span>&nbsp;&nbsp;<span style="color:' + textcolor + '">' + escapeHtml(message) + '</span>' + '<br />');
    $("#global-chat-log").scrollTop($("#global-chat-log")[0].scrollHeight);
}

//$(document).ready(function () {
$(function () {
    chatLog.slice().reverse().forEach(function (msg) {
        var dt   = new Date(Date.now() - msg.unix_seconds_back)
        var screenname = msg.screenname;
        if (screenname === 'thebalrog') {
            screenname = 'thebalrog (ADMIN)';
        }
        addChatMessage(
            screenname,
            msg.comment_text, 
            (msg.color ? msg.color : 'green'),
            (msg.text_color ? msg.text_color : 'black'),
            dt
        );
    });
});
