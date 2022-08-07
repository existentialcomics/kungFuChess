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
                    var audio = new Audio('/sound/public_sound_standard_GenericNotify.ogg');
                    audio.play();
                    if (jsonRes.hasOwnProperty('anonKey')) {
                        window.location.replace('/game/' + jsonRes.matchedGame + "?anonKey=" + jsonRes.anonKey);
                    } else {
                        window.location.replace('/game/' + jsonRes.matchedGame);
                    }
                } else if (jsonRes.hasOwnProperty('uid')) {
                    console.log('has uid in match games we matched but didnt create');
                    currentGameUid = jsonRes.uid;
                } else {
                    if (jsonRes.hasOwnProperty('openGames')) {
                        $('#publicGamesContent').html(jsonRes.openGames);
                    }
                    if (jsonRes.hasOwnProperty('challenges')) {
                        $('#challengeContent').html(jsonRes.challenges);
                    }
                    if (jsonRes.hasOwnProperty('myGame')) {
                        checkPoolRunning = false;
                        cancelCheckPool = false;
                        $("#enter-pool-standard").html('Standard Pool');
                        $("#enter-pool-lightning").html('Lightning Pool');
                        $("#enter-pool-4way-standard").html('Standard 4way Pool');
                        $("#enter-pool-4way-lightning").html('Lightning 4way Pool');

                        $('#myGameContent').html(jsonRes.myGame);
                        $('#createGameButtons').hide();
                    } else {
                        $('#myGameContent').html('');
                        $('#createGameButtons').show();
                    }
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
                        3500
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
                //var $s = $(data).not('#challenge_' . screenname);
                var $s = $(data).not('#challenge_thebalrog');
                $(data).find('#challenge_thebalrog').remove();
                $('#playersContent').html(data);
                $('#challenge_' + screenname).remove();
                if (setInterval) {
                    intervalPlayer = setTimeout(
                        function() {
                            getPlayers(true);
                        },
                        5000
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
        return ;
    }
    var setInterval = originalThread;
    if (checkPoolRunning == false) {
        currentGameUid = '';
        checkPoolRunning = true;
        setInterval = true;
    } else {

    }
    $.ajax({
        type : 'GET',
        url  : '/ajax/pool/' + checkPoolGameSpeed + "/" + checkPoolGameType,
        data : {
            uuid : currentGameUid
        },
        dataType : 'json',
        success : function(data){
            var jsonRes = data;
            if (jsonRes.hasOwnProperty('gameId')) {
                var audio = new Audio('/sound/public_sound_standard_GenericNotify.ogg');
                audio.play();
                audio.addEventListener('ended', function() {
                    if (jsonRes.hasOwnProperty('anonKey')) {
                        window.location.replace('/game/' + jsonRes.gameId + "?anonKey=" + jsonRes.anonKey);
                    } else {
                        window.location.replace('/game/' + jsonRes.gameId);
                    }
                }, false);
                // just in case the above fails
                setTimeout( function() {
                    if (jsonRes.hasOwnProperty('anonKey')) {
                        window.location.replace('/game/' + jsonRes.gameId + "?anonKey=" + jsonRes.anonKey);
                    } else {
                        window.location.replace('/game/' + jsonRes.gameId);
                    }
                }, 300);
            } else if (jsonRes.hasOwnProperty('uid')) {
                currentGameUid = jsonRes.uid;
            }
        }
    }).always(function() {
        //if (setInterval) {
            //intervalPlayer = setTimeout(
                //function() {
                    //checkPool(true);
                //},
                //2000
            //);
        //} else {

        //}
    });
}

//$(document).ready(function () {
$(function () {
    $("#lightningRadio").click(function() {
        document.querySelector("#pieceSpeedRange").value = 1;
        $("#pieceSpeedLabel").text('Lightning 1/0.1');
        $("#pieceSpeedRange").prop("disabled", true);
    });
    $("#standardRadio").click(function() {
        document.querySelector("#pieceSpeedRange").value = 10;
        $("#pieceSpeedLabel").text('Standard 10/1');
        $("#pieceSpeedRange").prop("disabled", true);
        //$("#pieceSpeedRange").hide()
    });
    $("#customRadio").click(function() {
        $("#pieceSpeedRange").prop("disabled", false);
        $("#pieceSpeedRange").show()
    });
    $("#pieceSpeedRange").on('input', function() {
        if (this.value < 4) {
            $("#pieceSpeedLabel").text('Lightning ' + this.value + "/" + this.value/10);
        } else {
            $("#pieceSpeedLabel").text('Standard ' + this.value + "/" + this.value/10);
        }
    });


    function change(e){
        $('.card-deck').html($(this).val() + "<br/>");
    }

    $("#enter-pool-standard").click(function() {
        if (checkPoolRunning
            && checkPoolGameSpeed == 'standard'
            && checkPoolGameType  == '2way'
        ) {
            cancelCheckPool = true;
            $(this).html('Standard Pool');
        } else {
            cancelCheckPool = false;
            $(this).html('Standard Pool<br /><span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>');
            $("#enter-pool-lightning").html('Lightning Pool');
            $("#enter-pool-4way-standard").html('Standard 4way Pool');
            $("#enter-pool-4way-lightning").html('Lightning 4way Pool');
            checkPoolGameSpeed = 'standard';
            checkPoolGameType  = '2way';
            currentGameUid = '';
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
            $("#enter-pool-4way-lightning").html('Lightning 4way Pool');
            checkPoolGameSpeed = 'lightning';
            checkPoolGameType  = '2way';
            currentGameUid = '';
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
            $("#enter-pool-lightning").html('Lightning Pool');
            $("#enter-pool-4way-lightning").html('Lightning 4way Pool');
            checkPoolGameSpeed = 'standard';
            checkPoolGameType  = '4way';
            currentGameUid = '';
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
            $("#enter-pool-lightning").html('Lightning Pool');
            $("#enter-pool-4way-standard").html('Standard 4way Pool');
            checkPoolGameSpeed = 'lightning';
            checkPoolGameType  = '4way';
            currentGameUid = '';
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
        $("#showChallenges").removeClass('active');
        $("#showPool").addClass('active');
        $("#openGamesContent").hide();
        $("#activeGamesContent").hide();
        $("#createGameFormDiv").hide();
        $("#createAiGameFormDiv").hide();
        $("#pool-matching").show();
        cancelActiveGames = true;
        cancelOpenGames = true;
    });
  
    $("#showOpenGames").click(function() {
        $("#enter-pool-standard").html('Standard Pool');
        $("#enter-pool-lightning").html('Lightning Pool');
        $("#enter-pool-4way-standard").html('Standard 4way Pool');
        $("#enter-pool-4way-lightning").html('Lightning 4way Pool');

        $("#showOpenGames").addClass('active');
        $("#showActiveGames").removeClass('active');
        $("#showChallenges").removeClass('active');
        $("#showPool").removeClass('active');
        $("#activeGamesContent").hide();
        $("#pool-matching").hide();
        cancelActiveGames = true;
        cancelCheckPool = true;
        $("#enter-pool-lighting").html('Lightning Pool');
        $("#enter-pool-standard").html('Standard Pool');

        cancelOpenGames = false;
        getOpenGames();
        $("#createGameFormDiv").hide();
        $("#createAiGameFormDiv").hide();
        $("#openGamesContent").show();
        $("#challengesContent").hide();
    });

    $("#showChallenges").click(function() {
        $("#enter-pool-standard").html('Standard Pool');
        $("#enter-pool-lightning").html('Lightning Pool');
        $("#enter-pool-4way-standard").html('Standard 4way Pool');
        $("#enter-pool-4way-lightning").html('Lightning 4way Pool');

        $("#showOpenGames").removeClass('active');
        $("#showChallenges").addClass('active');
        $("#showActiveGames").removeClass('active');
        $("#showPool").removeClass('active');
        $("#activeGamesContent").hide();
        $("#pool-matching").hide();
        cancelActiveGames = true;
        cancelCheckPool = true;
        cancelOpenGames = true;
        $("#enter-pool-lighting").html('Lightning Pool');
        $("#enter-pool-standard").html('Standard Pool');

        $("#createGameFormDiv").hide();
        $("#createAiGameFormDiv").hide();
        $("#openGamesContent").hide();
        $("#challengesContent").show();
    });
  
    $("#showActiveGames").click(function() {
        $("#enter-pool-standard").html('Standard Pool');
        $("#enter-pool-lightning").html('Lightning Pool');
        $("#enter-pool-4way-standard").html('Standard 4way Pool');
        $("#enter-pool-4way-lightning").html('Lightning 4way Pool');

        $("#showActiveGames").addClass('active');
        $("#showChallenges").removeClass('active');
        $("#showOpenGames").removeClass('active');
        $("#showPool").removeClass('active');
        $("#pool-matching").hide();
        cancelOpenGames = true;
        cancelCheckPool = true;
        $("#enter-pool-lighting").html('Lightning Pool');
        $("#enter-pool-standard").html('Standard Pool');

        cancelActiveGames = false;
        getActiveGames();
        $("#createGameFormDiv").hide();
        $("#createAiGameFormDiv").hide();
        $("#openGamesContent").hide();
        $("#activeGamesContent").show();
        $("#challengesContent").hide();
    });
  
    $("#homeContent").delegate('#createGameBtn', 'click', function() {
        $("#pool-matching").hide();
        $("#openGamesContent").hide();
        $("#createGameFormDiv").show();
        $("#createAiGameFormDiv").hide();

        $("#openToPublicChk").prop('checked', true);
        $("#isChallengeChk").prop('checked', false);
        $("#challengeUserTxt").prop('disabled', true);
        $("#challengeUserTxt").val('');
    });
  
    $("#homeContent").delegate('#createAiGameBtn', 'click', function() {
        $("#pool-matching").hide();
        $("#openGamesContent").hide();
        $("#createGameFormDiv").hide();
        $("#createAiGameFormDiv").show();
    });

    $("#homeContent").delegate('.challengePlayer', 'click', function() {
        $("#pool-matching").hide();
        $("#openGamesContent").hide();
        $("#createGameFormDiv").show();
        $("#createAiGameFormDiv").hide();

        $("#openToPublicChk").prop('checked', false);
        $("#isChallengeChk").prop('checked', true);
        $("#challengeUserTxt").prop('disabled', false);
        $("#challengeUserTxt").val($(this).data('screenname'));
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
                $("#createAiGameFormDiv").hide();
                $("#openGamesContent").show();
            }
        });
    });

    $("#homeContent").delegate('#isChallengeChk', 'click', function() {
        if($(this).prop("checked") == true){
            $("#openToPublicChk").prop('checked', false);
            $("#challengeUserTxt").prop('disabled', false);
        } else {
            $("#openToPublicChk").prop('checked', true);
            $("#challengeUserTxt").prop('disabled', true);
        }
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
                $("#createAiGameFormDiv").hide();
                $("#openGamesContent").show();
            }
        });
    });

    $("#homeContent").delegate('#createGameSubmit', 'click', function(e) {
        e.preventDefault();
        $("#pool-matching").hide();
        $("#openGamesContent").hide();
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
                    var audio = new Audio('/sound/public_sound_standard_GenericNotify.ogg');
                    audio.play();
                    if (jsonRes.hasOwnProperty('anonKey')) {
                        window.location.replace('/game/' + jsonRes.gameId + "?anonKey=" + jsonRes.anonKey);
                    } else {
                        window.location.replace('/game/' + jsonRes.gameId);
                    }
                }
                if (jsonRes.hasOwnProperty('error')) {
                    $("#error-alert").html('<div class="alert alert-danger alert-dismissible" id="error-alert" role="alert">' + jsonRes.error + "</div>");
    
                }
                $("#showOpenGames").addClass('active');
                $("#showPool").removeClass('active');
                $("#pool-matching").hide();
                getOpenGames();
                $("#createGameFormDiv").hide();
                $("#createAiGameFormDiv").hide();
                $("#openGamesContent").show();
            }
        });
    });

    $("#homeContent").delegate('#createAiGameSubmit', 'click', function(e) {
        e.preventDefault();
        $("#pool-matching").hide();
        $("#openGamesContent").hide();
        $.ajax({
            type : 'POST',
            url  : '/ajax/createChallenge',
            data: $("#createAiGameForm").serialize(),
            dataType : 'json',
            success : function(data){
                var jsonRes = data;
                if (jsonRes.hasOwnProperty('uid')) {
                    currentGameUid = jsonRes.uid;
                }
                if (jsonRes.hasOwnProperty('gameId')) {
                    var audio = new Audio('/sound/public_sound_standard_GenericNotify.ogg');
                    audio.play();
                    if (jsonRes.hasOwnProperty('anonKey')) {
                        window.location.replace('/game/' + jsonRes.gameId + "?anonKey=" + jsonRes.anonKey);
                    } else {
                        window.location.replace('/game/' + jsonRes.gameId);
                    }
                }
                if (jsonRes.hasOwnProperty('error')) {
                    $("#error-alert").html('<div class="alert alert-danger alert-dismissible" id="error-alert" role="alert">' + jsonRes.error + "</div>");
    
                }
                $("#showOpenGames").addClass('active');
                $("#showPool").removeClass('active');
                $("#pool-matching").hide();
                getOpenGames();
                $("#createGameFormDiv").hide();
                $("#createAiGameFormDiv").hide();
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
        dataPost['c'] = 'chat';
        sendGlobalMsg(dataPost);
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
                if (userAuthToken) {
                    sendGlobalMsg(heartbeat_msg);
                }
            } 
        }, 3000); 
    }

    main_conn.onmessage = function(evt) {
        var msg = JSON.parse(evt.data);
        if (msg.c == 'globalchat'){
            var dt = new Date();
            addChatMessage(
                msg.author,
                msg.message,
                (msg.color ? msg.color : 'green'),
                'black',
                dt
            );
        } else if (msg.c == 'activeGame'){
            if(document.getElementById("gameStatus") == null)
            {
                var gameUrl = '/game/' + msg.gameId;
                var buttonHtml = '<a href="' + gameUrl + '"><button type="button" class="btn btn-danger">You have an active game! Click here to go to your game.</button></a>'
                $('#active-game').html(buttonHtml);
                console.log(buttonHtml);
                //window.location.replace('/game/' + msg.gameId);
            }
        } else if (msg.c == 'challenge'){
            $('#challengesContent').html(msg.challenges);
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
    var audio = new Audio('/sound/public_sound_standard_SocialNotify.ogg');
    audio.play();
    chatContent = $('#global-chat-log');
    chatContent.append('<a href="/matchGame/' + uid + '">' + screenname + ' invited you to a game (' + gameType + ' ' + gameSpeed + ' ' + (rated ? 'rated' : 'unrated') + ') click to accept</a><br />');
    $("#global-chat-log").scrollTop($("#global-chat-log")[0].scrollHeight);
}

/**
 * Add message to the chat window
 */
function addChatMessage(author, message, usercolor, textcolor, dt, playSound = true) {
    if (chatSounds > 0 && playSound == true) {
        var audio = new Audio('/sound/public_sound_standard_SocialNotify.ogg');
        audio.play();
    }
    var dtString = ' ';
    if (! isNaN(dt.getTime())) {
        dtString =
            (dt.getHours() < 10 ? '0' + dt.getHours() : dt.getHours()) + ':' +
            (dt.getMinutes() < 10 ? '0' + dt.getMinutes() : dt.getMinutes()) + ':' + 
            (dt.getSeconds() < 10 ? '0' + dt.getSeconds() : dt.getSeconds());
    }
    message = decodeURIComponent(escape(message));
    chatContent = $('#global-chat-log');
    chatContent.append('<span class="' + usercolor + 'beltColor" style="font-size: 0.7em;">' + author + '</span><span style="font-size: 0.4em;color:grey"> ' + dtString 
            + '</span>&nbsp; <span style="font-size: 0.7em; color:' + textcolor + '">' + message + '</span>' + '<br />');
    $("#global-chat-log").scrollTop($("#global-chat-log")[0].scrollHeight);
}

//$(document).ready(function () {
$(function () {
    chatLog.slice().reverse().forEach(function (msg) {
        var dt   = new Date(Date.now() - (msg.unix_seconds_back * 1000))
        var screenname = msg.screenname;
        if (screenname == null) {
            screenname = 'anonymous';
        }
        if (screenname === 'thebalrog') {
            screenname = 'thebalrog (ADMIN)';
        }
        addChatMessage(
            screenname,
            msg.comment_text, 
            (msg.color ? msg.color : 'green'),
            (msg.text_color ? msg.text_color : 'black'),
            dt,
            false // don't play the sound
        );
    });
});
