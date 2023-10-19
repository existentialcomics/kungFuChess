var checkPoolRunning = false;
var checkPoolGameSpeed = gameSpeed;
var checkPoolGameType  = gameType;
var cancelCheckPool = false;

var isConnectedGame = false;

// have we got a board spawn message yet? if no keep joining
var hasRecievedSpawn = false;

var rematchPoolRunning = false;
var cancelRematchPool = false;
var boardSize = 8;
var ranks = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
var files = [1, 2, 3, 4, 5, 6, 7, 8];
if (gameType == '4way') {
    boardSize = 12;
    ranks = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l'];
    files = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
}

var rematches = [];

var sweepAudio = null;
//const importObject = {
  //imports: { imported_func: (arg) => console.log(arg) },
//};

$(function () {
  //fetch("/xs.js")
  //.then((response) => response.arrayBuffer())
  //.then((bytes) => WebAssembly.instantiate(bytes, importObject))
  //.then((results) => {
    //results.instance.exports.exported_func();
  //}
  //);

    $("#enter-pool").click(function() {
        if (checkPoolRunning) {
            cancelCheckPool = true;
            $(this).html('Enter Pool');
        } else {
            $(this).html('Enter Pool<br /><span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>');
            checkPoolGameSpeed = gameSpeed;
            checkPoolGameType  = gameType;
            checkPool();
        }
    });
    $("#rematch").click(function() {
        if (rematchPoolRunning) {
            var dataPost = {
                'uid' : anonKey,
                'gameId' : gameId,
                'c' : 'cancelRematch',
            };
            $(this).val('');
            sendMsg(dataPost);
            $(this).html('Rematch');
        } else {
            var dataPost = {
                'uid' : anonKey,
                'gameId' : gameId,
                'c' : 'rematch',
            };
            $(this).val('');
            sendMsg(dataPost);

            $(this).html('Requesting Rematch...<br /><span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>');
        }
    });
});

var width  = 320;
var height = 320;

var boardContent = $("#boardContainer");
var game_chatContent = $('#game-chat-log');

var maxPieceId = 1;

width = boardContent.width();
height = $("#boardContainer").width();

$(window).resize(function(){
    piecesByImageId = {};
    stage.destroyChildren();
    stage.clear();
    stage.draw();
    pieceLayer.destroyChildren();
    boardLayer.destroyChildren();
    delayLayer.destroyChildren();
    premoveLayer.destroyChildren();
    width = boardContent.width();
    height = $("#boardContainer").width();
    stage = setupBoard();
    stage = setupEvents(stage);
    for(id in pieces){
        pieces[id].refreshImage();
    }
    boardLayer.draw();
    delayLayer.draw();
    pieceLayer.draw();
    premoveLayer.draw();
});

var blackLastSeen = null;
var whiteLastSeen = null;
var redLastSeen = null;
var greenLastSeen = null;

var myPing = null;
var blackPing = null;
var whitePing = null;
var redPing = null;
var greenPing = null;

var boardLayer = new Konva.Layer();
var pieceLayer = new Konva.Layer();
var delayLayer = new Konva.Layer();
var premoveLayer = new Konva.Layer();

// fix for brave to not use getImageData()
pieceLayer._getIntersection = function(pos) {
    var boardPos = getBoardPos(pos);
    var piece = getPieceAtBoardPos(boardPos);
    if (piece) {
        return {
            shape: piece.image
        }
    } else {
        return {};
    }
};

var pieces = {};
var piecesByImageId = {};
var piecesByBoardPos = {};
var suspendedPieces = {};
ranks.forEach(function (rank, index) {
    files.forEach(function (file, index) {
        piecesByBoardPos["" + rank + file] = null;
        suspendedPieces["" + rank + file] = [];
    });
});

// hardcoded translation of BB squares to board squares 4way
var bitboardToSquare4way = {
    '128' : 'c12',
    '64' : 'd12',
    '32' : 'e12',
    '16' : 'f12',
    '8' : 'g12',
    '4' : 'h12',
    '2' : 'i12',
    '1' : 'j12',
    '32768' : 'c11',
    '16384' : 'd11',
    '8192' : 'e11',
    '4096' : 'f11',
    '2048' : 'g11',
    '1024' : 'h11',
    '512' : 'i11',
    '256' : 'j11',
    '134217728' : 'a10',
    '67108864' : 'b10',
    '33554432' : 'c10',
    '16777216' : 'd10',
    '8388608' : 'e10',
    '4194304' : 'f10',
    '2097152' : 'g10',
    '1048576' : 'h10',
    '524288' : 'i10',
    '262144' : 'j10',
    '131072' : 'k10',
    '65536' : 'l10',
    '549755813888' : 'a9',
    '274877906944' : 'b9',
    '137438953472' : 'c9',
    '68719476736' : 'd9',
    '34359738368' : 'e9',
    '17179869184' : 'f9',
    '8589934592' : 'g9',
    '4294967296' : 'h9',
    '2147483648' : 'i9',
    '1073741824' : 'j9',
    '536870912' : 'k9',
    '268435456' : 'l9',
    '2251799813685248' : 'a8',
    '1125899906842624' : 'b8',
    '562949953421312' : 'c8',
    '281474976710656' : 'd8',
    '140737488355328' : 'e8',
    '70368744177664' : 'f8',
    '35184372088832' : 'g8',
    '17592186044416' : 'h8',
    '8796093022208' : 'i8',
    '4398046511104' : 'j8',
    '2199023255552' : 'k8',
    '1099511627776' : 'l8',
    '9223372036854775808' : 'a7',
    '4611686018427387904' : 'b7',
    '2305843009213693952' : 'c7',
    '1152921504606846976' : 'd7',
    '576460752303423488' : 'e7',
    '288230376151711744' : 'f7',
    '144115188075855872' : 'g7',
    '72057594037927936' : 'h7',
    '36028797018963968' : 'i7',
    '18014398509481984' : 'j7',
    '9007199254740992' : 'k7',
    '4503599627370496' : 'l7',
    '37778931862957161709568' : 'a6',
    '18889465931478580854784' : 'b6',
    '9444732965739290427392' : 'c6',
    '4722366482869645213696' : 'd6',
    '2361183241434822606848' : 'e6',
    '1180591620717411303424' : 'f6',
    '590295810358705651712' : 'g6',
    '295147905179352825856' : 'h6',
    '147573952589676412928' : 'i6',
    '73786976294838206464' : 'j6',
    '36893488147419103232' : 'k6',
    '18446744073709551616' : 'l6',
    '154742504910672534362390528' : 'a5',
    '77371252455336267181195264' : 'b5',
    '38685626227668133590597632' : 'c5',
    '19342813113834066795298816' : 'd5',
    '9671406556917033397649408' : 'e5',
    '4835703278458516698824704' : 'f5',
    '2417851639229258349412352' : 'g5',
    '1208925819614629174706176' : 'h5',
    '604462909807314587353088' : 'i5',
    '302231454903657293676544' : 'j5',
    '151115727451828646838272' : 'k5',
    '75557863725914323419136' : 'l5',
    '633825300114114700748351602688' : 'a4',
    '316912650057057350374175801344' : 'b4',
    '158456325028528675187087900672' : 'c4',
    '79228162514264337593543950336' : 'd4',
    '39614081257132168796771975168' : 'e4',
    '19807040628566084398385987584' : 'f4',
    '9903520314283042199192993792' : 'g4',
    '4951760157141521099596496896' : 'h4',
    '2475880078570760549798248448' : 'i4',
    '1237940039285380274899124224' : 'j4',
    '618970019642690137449562112' : 'k4',
    '309485009821345068724781056' : 'l4',
    '2596148429267413814265248164610048' : 'a3',
    '1298074214633706907132624082305024' : 'b3',
    '649037107316853453566312041152512' : 'c3',
    '324518553658426726783156020576256' : 'd3',
    '162259276829213363391578010288128' : 'e3',
    '81129638414606681695789005144064' : 'f3',
    '40564819207303340847894502572032' : 'g3',
    '20282409603651670423947251286016' : 'h3',
    '10141204801825835211973625643008' : 'i3',
    '5070602400912917605986812821504' : 'j3',
    '2535301200456458802993406410752' : 'k3',
    '1267650600228229401496703205376' : 'l3',
    '664613997892457936451903530140172288' : 'c2',
    '332306998946228968225951765070086144' : 'd2',
    '166153499473114484112975882535043072' : 'e2',
    '83076749736557242056487941267521536' : 'f2',
    '41538374868278621028243970633760768' : 'g2',
    '20769187434139310514121985316880384' : 'h2',
    '10384593717069655257060992658440192' : 'i2',
    '5192296858534827628530496329220096' : 'j2',
    '170141183460469231731687303715884105728' : 'c1',
    '85070591730234615865843651857942052864' : 'd1',
    '42535295865117307932921825928971026432' : 'e1',
    '21267647932558653966460912964485513216' : 'f1',
    '10633823966279326983230456482242756608' : 'g1',
    '5316911983139663491615228241121378304' : 'h1',
    '2658455991569831745807614120560689152' : 'i1',
    '1329227995784915872903807060280344576' : 'j1',
}

// hardcoded translation of BB squares to board squares
var bitboardToSquare = {
    '72057594037927936' : 'a8',
    '144115188075855872' : 'b8',
    '288230376151711744' : 'c8',
    '576460752303423488' : 'd8',
    '1152921504606846976' : 'e8',
    '2305843009213693952' : 'f8',
    '4611686018427387904' : 'g8',
    '9223372036854775808' : 'h8',
    '281474976710656' : 'a7',
    '562949953421312' : 'b7',
    '1125899906842624' : 'c7',
    '2251799813685248' : 'd7',
    '4503599627370496' : 'e7',
    '9007199254740992' : 'f7',
    '18014398509481984' : 'g7',
    '36028797018963968' : 'h7',
    '1099511627776' : 'a6',
    '2199023255552' : 'b6',
    '4398046511104' : 'c6',
    '8796093022208' : 'd6',
    '17592186044416' : 'e6',
    '35184372088832' : 'f6',
    '70368744177664' : 'g6',
    '140737488355328' : 'h6',
    '4294967296' : 'a5',
    '8589934592' : 'b5',
    '17179869184' : 'c5',
    '34359738368' : 'd5',
    '68719476736' : 'e5',
    '137438953472' : 'f5',
    '274877906944' : 'g5',
    '549755813888' : 'h5',
    '16777216' : 'a4',
    '33554432' : 'b4',
    '67108864' : 'c4',
    '134217728' : 'd4',
    '268435456' : 'e4',
    '536870912' : 'f4',
    '1073741824' : 'g4',
    '2147483648' : 'h4',
    '65536' : 'a3',
    '131072' : 'b3',
    '262144' : 'c3',
    '524288' : 'd3',
    '1048576' : 'e3',
    '2097152' : 'f3',
    '4194304' : 'g3',
    '8388608' : 'h3',
    '256' : 'a2',
    '512' : 'b2',
    '1024' : 'c2',
    '2048' : 'd2',
    '4096' : 'e2',
    '8192' : 'f2',
    '16384' : 'g2',
    '32768' : 'h2',
    '1' : 'a1',
    '2' : 'b1',
    '4' : 'c1',
    '8' : 'd1',
    '16' : 'e1',
    '32' : 'f1',
    '64' : 'g1',
    '128' : 'h1',
};

var getSquareFromBB = function(bb) {
    if (gameType == '4way') {
        return bitboardToSquare4way[bb];
    }
    return bitboardToSquare[bb];
}

// TODO build dynamically based on boardSize (number of squares)
// this are flipped lol whatever
var xToFile = ranks.slice();
var yToRank = files.slice();
yToRank.reverse();

var rankToX = {};
var fileToY = {};

var rankLength = ranks.length;
var fileLength = files.length;

for (var i = 0; i < rankLength; i++) {
    rankToX[yToRank[i]] = i;
}
for (var i = 0; i < fileLength; i++) {
    fileToY[xToFile[i]] = i;
}

var globalIdCount = 1;
var replayMode = false;

console.log("connecting...");

var hidePremoves = function(piece) {
    if (piece.hasOwnProperty('premoveFrom')){
        piece.premoveFrom.opacity(0.0);
        delete piece.premoveFrom;
    }
    if (piece.hasOwnProperty('premoveTo')){
        piece.premoveTo.opacity(0.0);
        delete piece.premoveTo;
    }
};

var updateTimeStamps = function(){
    var d = new Date();
    var timestamp = d.getTime();
    if (blackLastSeen == null || timestamp - blackLastSeen > 3000 ) {
        $("#blackOnline").addClass('offline');
        $("#blackOnline").removeClass('online');
    } else {
        $("#blackOnline").addClass('online');
        if (blackPing) {
            $("#blackOnline").attr("title", blackPing + " ms");
        }
        $("#blackOnline").removeClass('offline');
    }

    if (whiteLastSeen == null || timestamp - whiteLastSeen > 3000) {
        $("#whiteOnline").addClass('offline');
        $("#whiteOnline").removeClass('online');
    } else {
        $("#whiteOnline").addClass('online');
        if (whitePing) {
            $("#whiteOnline").attr("title", whitePing + " ms");
        }
        $("#whiteOnline").removeClass('offline');
    }

    if (redLastSeen == null || timestamp - redLastSeen > 3000) {
        $("#redOnline").addClass('offline');
        $("#redOnline").removeClass('online');
    } else {
        $("#redOnline").addClass('online');
        if (redPing) {
            $("#redOnline").attr("title", redPing + " ms");
        }
        $("#redOnline").removeClass('offline');
    }

    if (greenLastSeen == null || timestamp - greenLastSeen > 3000) {
        $("#greenOnline").addClass('offline');
        $("#greenOnline").removeClass('online');
    } else {
        $("#greenOnline").addClass('online');
        if (greenPing) {
            $("#greenOnline").attr("title", greenPing + " ms");
        }
        $("#greenOnline").removeClass('offline');
    }
};

var joinGame = function(){
    if (hasRecievedSpawn) {
        return true;
    }
    var ret = {
        'c' : 'join',
        'uid' : anonKey,
        'gameId' : gameId
    };
    sendMsg(ret);
};

var sitGame = function(){
    var ret = {
        'c' : 'sit',
        'uid' : userAuthToken,
        'gameId' : gameId
    };
    sendMsg(ret);
};

var resetGamePieces = function(){
    for(id in pieces){
		pieces[id].image.x(getX(pieces[id].image.x(), pieces[id].image.y()));
		pieces[id].image.y(getY(pieces[id].image.x(), pieces[id].image.y()));
    }
	pieceLayer.draw();
};

var bindGameEvents = function(ws_conn) {
    conn.onopen = function(evt) {
        // finished connecting.
        // maybe query for ready to join
        console.log("connected!");
        isConnectedGame = true;
        if (myColor != 'watch') {
            pingServer = setInterval(function() {
                var d = new Date();
                var timestamp = d.getTime();
                heartbeat_msg = {
                    "c" : "ping",
                    'timestamp' : timestamp,
                    'ping' : myPing
                };
                sendMsg(heartbeat_msg);
            }, 3000); 
        }
        joinGame();
        initialMessages.forEach(function (item, index) {
            handleMessage(item);
        });
    };

    conn.onerror = function(e) {
        console.log('Error!');
    };

    conn.onclose = function(e) {
        isConnectedGame = false;
        var dt = new Date();
        console.log('Disconnected!');
        var authColor = 'white';
        addGameMessage(
            "SYSTEM",
            "Disconnected, attempting to reconnect...",
            "red",
            'black',
            dt,
            'system'
        );
        game_reconnectInterval = setTimeout(
            game_reconnectMain,
            1000
        );
    };
};
var conn = new WebSocket(wsProtocol + "://" + wsGameDomain + "/ws");
if (isActiveGame) {
    bindGameEvents(conn);
}

var game_reconnectInterval;
var game_reconnectMain = function() {
    if (isConnectedGame == false && isActiveGame) {
        $("#connectionStatus").html("Reconnecting...");
        conn = null;
        conn = new WebSocket(wsProtocol + "://" + wsDomain + "/ws");
        bindGameEvents(main_conn);
    } else {
        reconnectInterval = null;
    }
}


sendMsg = function(msg) {
    if (msg.c != 'ping') {
        //console.log("sending msg:");
        //console.log(msg);
    }
    msg.gameId = gameId;
    msg.auth = authId;
    conn.send(JSON.stringify(msg));
    
    // if it errors out it wont
    return true;
};

readyToStart = function() {
    
    var msg = {
        "c" : "readyToBegin"
    };
    var result = sendMsg(msg);
    if (result == true) {
        $("#readyToStart").attr("disabled","disabled");
    }
}

resign = function(){
    var msg = {
        "c" : "resign"
    };
    sendMsg(msg);
}

remindAiTakeover = function() {
    if (gameType == '4way') {
        if ($('#gameStatus').html() == 'waiting to begin') {
            var dt = new Date();
            addGameMessage(
                "SYSTEM",
                "If a player isn't starting, you can have the AI take them over with this command: /ai color",
                "red",
                'black',
                dt,
                'system'
            );
        }
    }
}

// TODO have the logic flip on confirmation not send
var drawRequested = false;
requestDraw = function() {
    if (drawRequested) {
        drawRequested = false;
        var msg = {
            "c" : "revokeDraw"
        };
        $('#requestDraw').html('Request Draw');
        sendMsg(msg);
    } else {
        drawRequested = true;
        var msg = {
            "c" : "requestDraw"
        };
        $('#requestDraw').html('Revoke Draw');
        sendMsg(msg);
    }
}

requestRematch = function() {
    var msg = {
        "c" : "requestRematch"
    };
    sendMsg(msg);
}

var getPieceSquare = function(piece) {
    var rank = yToRank[piece.y];
    var file = xToFile[piece.x];
    return file + rank;
}

var premoves = [];
var delays   = [];

var debug = false;
var handleMessage = function(msg) {
    if (msg.c != 'ping' && debug == true) {
        if (msg.hasOwnProperty('fr_bb')) {
            msg.fr_square = getSquareFromBB(msg.fr_bb);
        }
        if (msg.hasOwnProperty('to_bb')) {
            msg.to_square = getSquareFromBB(msg.to_bb);
        }
        if (! msg.hasOwnProperty('bb')) {
            msg.bb_square = getSquareFromBB(msg.bb);
        }
    }
    if (msg.c == 'move'){  // called when a piece changes positions (many times in one "move")
        var from = getSquareFromBB(msg.fr_bb);
        var to   = getSquareFromBB(msg.to_bb);

        pieceFrom = piecesByBoardPos[from];
        setPieceBoardPos(pieceFrom, to);
        piecesByBoardPos[from] = null;
    } else if (msg.c == 'continue' || msg.c == 'pause'){ // when pieces collides and one is forced to stop
        let re = /([a-z])([0-9]{1,2})/;
        var from = getSquareFromBB(msg.fr_bb);

        var m_from = from.match(re);

        var y = rankToX[m_from[2]];
        var x = parseInt(fileToY[m_from[1]]);
        var pieceFrom = piecesByBoardPos[from];

        if (msg.c == 'pause') {
            pieceFrom.anim.stop();
        } else {
            pieceFrom.anim.start();
        }
    } else if (msg.c == 'stop'){ // when pieces collides and one is forced to stop
        if (! msg.hasOwnProperty('expected')) {
            let re = /([a-z])([0-9]{1,2})/;
            var from = getSquareFromBB(msg.fr_bb);

            var m_from = from.match(re);

            var y = rankToX[m_from[2]];
            var x = parseInt(fileToY[m_from[1]]);
            var pieceFrom = piecesByBoardPos[from];

            var stopFunction = function() {
                if (pieceFrom) {
                    if (msg.hasOwnProperty('time_remaining')) {
                        pieceFrom.stop(x, y, msg.time_remaining);
                    } else {
                        pieceFrom.stop(x, y);
                    }
                }
            }
            if (msg.hasOwnProperty('delay')) {
                setTimeout(stopFunction, msg.delay * 1000);
            } else {
                stopFunction();
            }
        }
    } else if (msg.c == 'cancelPremove'){ 
        var from = getSquareFromBB(msg.fr_bb);
        var to   = getSquareFromBB(msg.to_bb);
        var pieceFrom = piecesByBoardPos[from];
        hidePremoves(pieceFrom);
    } else if (msg.c == 'premove'){ 
        if (msg.color == myColor) {
            var from = getSquareFromBB(msg.fr_bb);
            var to   = getSquareFromBB(msg.to_bb);

            let re = /([a-z])([0-9]{1,2})/;

            var m_from = from.match(re);
            var m_to   = to.match(re);

            var x_from = parseInt(fileToY[m_from[1]]);
            var y_from = rankToX[m_from[2]];
            var x_to   = parseInt(fileToY[m_to[1]]);
            var y_to   = rankToX[m_to[2]];

            var pieceFrom = piecesByBoardPos[from];
            hidePremoves(pieceFrom);

            var abs_x_from = getXCoordinate(x_from, y_from);
            var abs_y_from = getYCoordinate(x_from, y_from);
            var abs_x_to = getXCoordinate(x_to, y_to);
            var abs_y_to = getYCoordinate(x_to, y_to);

            var sqr_from = premoves["" + abs_x_from + "" + abs_y_from];
            var sqr_to   = premoves["" + abs_x_to + "" + abs_y_to];
            sqr_from.opacity(0.4);
            sqr_to.opacity(0.4);

            pieceFrom.premoveFrom = sqr_from;
            pieceFrom.premoveTo   = sqr_to;
        }
    } else if (msg.c == 'moveAnimate'){ // called when a player moves a piece
        // clear draw request
        if (drawRequested) {
            drawRequested = false;
            $('#requestDraw').html('Request Draw');
        }

        let re = /([a-z])([0-9]{1,2})/;

        var from = getSquareFromBB(msg.fr_bb);
        var to   = getSquareFromBB(msg.to_bb);
        var m_from = from.match(re);
        var m_to   = to.match(re);

        if (msg.moveType == 3) {        // OO
            var pieceFrom = piecesByBoardPos[from];
            var pieceTo   = piecesByBoardPos[to];
            if (pieceFrom.color == 'red' || pieceFrom.color == 'green') {
                var y_king = rankToX[m_to[2]] - 1;
                var x_king = parseInt(fileToY[m_to[1]]);
                pieceFrom.move(x_king, y_king);

                var y_rook = rankToX[m_from[2]] + 1;
                var x_rook = parseInt(fileToY[m_from[1]]);
                pieceTo.move(x_rook, y_rook);
            } else {
                var y_king = rankToX[m_to[2]];
                var x_king = parseInt(fileToY[m_to[1]]) - 1;
                pieceFrom.move(x_king, y_king);

                var y_rook = rankToX[m_from[2]];
                var x_rook = parseInt(fileToY[m_from[1]]) + 1;
                pieceTo.move(x_rook, y_rook);
            }
        } else if (msg.moveType == 4) { // OOO
            var pieceFrom = piecesByBoardPos[from];
            var pieceTo   = piecesByBoardPos[to];

            if (pieceFrom.color == 'red' || pieceFrom.color == 'green') {
                var y_king = rankToX[m_to[2]] + 2;
                var x_king = parseInt(fileToY[m_to[1]]);
                pieceFrom.move(x_king, y_king);

                var y_rook = rankToX[m_from[2]] - 1;
                var x_rook = parseInt(fileToY[m_from[1]]);
                pieceTo.move(x_rook, y_rook, 0.6667);
            } else {
                var y_king = rankToX[m_to[2]];
                var x_king = parseInt(fileToY[m_to[1]]) + 2;
                pieceFrom.move(x_king, y_king);

                var y_rook = rankToX[m_from[2]];
                var x_rook = parseInt(fileToY[m_from[1]]) - 1;
                pieceTo.move(x_rook, y_rook, 0.6667);
            }
        } else { // all others
            var pieceFrom = piecesByBoardPos[from];
            var y = rankToX[m_to[2]];
            var x = fileToY[m_to[1]];
            pieceFrom.move(x, y);
        }
    } else if (msg.c == 'promote'){
        var square = getSquareFromBB(msg.bb);
        var piece = piecesByBoardPos[square];

        // must wait until end of animation to replace with queen
        piece.promote = true;
    } else if (msg.c == 'notready'){
        // happens when we join too quickly 
        var retry = setTimeout(function() {
            joinGame();
        }, 500); 
    } else if (msg.c == 'joined'){
        console.debug(msg);
		// TODO mark all color pieces as draggabble
		for(id in pieces){
			if (pieces[id].color == myColor || myColor == 'both'){
				pieces[id].image.draggable(true);
			}
		}
        //console.debug(msg);
		resetGamePieces();
		pieceLayer.draw();
        setTimeout(remindAiTakeover, 20000)
        if (myColor == 'watch') {
            //sitGame();
        }
    } else if (msg.c == 'suspend'){
        // knights and castles are removed from the board entirely 
        // when they move, until they land.
        var from = getSquareFromBB(msg.fr_bb);
        var to   = getSquareFromBB(msg.to_bb);
        var piece = piecesByBoardPos[from];
        suspendedPieces[to].push(piece);

        piecesByBoardPos[from] = null;
    } else if (msg.c == 'unsuspend'){
        // this is for knights and castles where the piece
        // is removed from the board then put down at the destination
        var square = getSquareFromBB(msg.to_bb);
        var piece = suspendedPieces[square].shift();

        piecesByBoardPos[square] = piece;
    } else if (msg.c == 'spawn'){
        spawn(msg.chr, msg.square);
    } else if (msg.c == 'pong'){
        var d = new Date();
        var timestamp = d.getTime();
        if (msg.color == 'black') {
            blackPing = msg.ping;
            blackLastSeen = timestamp;
            updateTimeStamps();
            // i sent this message so the ping timestamp is mine
            if (myColor == 'black') {
                myPing = timestamp - msg.timestamp;
            }
        } else if (msg.color == 'white') {
            whitePing = msg.ping;
            whiteLastSeen = timestamp;
            updateTimeStamps();
            // i sent this message so the ping timestamp is mine
            if (myColor == 'white') {
                myPing = timestamp - msg.timestamp;
            }
        } else if (msg.color == 'red') {
            redPing = msg.ping;
            redLastSeen = timestamp;
            updateTimeStamps();
            // i sent this message so the ping timestamp is mine
            if (myColor == 'red') {
                myPing = timestamp - msg.timestamp;
            }
        } else if (msg.color == 'green') {
            greenPing = msg.ping;
            greenLastSeen = timestamp;
            updateTimeStamps();
            // i sent this message so the ping timestamp is mine
            if (myColor == 'green') {
                myPing = timestamp - msg.timestamp;
            }
        }
    } else if (msg.c == 'resign'){
        var dt = new Date();
        addGameMessage(
            "SYSTEM",
            msg.color + " resigns.",
            "red",
            'black',
            dt,
            'system'
        );
        killPlayer(msg.color);
    } else if (msg.c == 'kill' || msg.c == 'killsuspend'){
        var square = getSquareFromBB(msg.bb);
        var piece  = piecesByBoardPos[square];
        if (msg.c == 'killsuspend') {
            square = getSquareFromBB(msg.to_bb);
            piece = suspendedPieces[square].shift();
        }
        if (playSounds == true) {
            if (msg.hasOwnProperty('is_sweep')) {
                if (sweepAudio) {
                    sweepAudio.play();
                }
            } else {
                if (piece.killSound) {
                    piece.killSound.play();
                }
            }
        }
        if (piece.type == 'king') {
            killPlayer(piece.color);
        }

        if (piece != null) {
            hidePremoves(piece);
            piece.image.destroy();
            if (piece.anim) {
                piece.anim.stop();
                piece.anim = null;
            }
            if (piece.delayRect){
                piece.delayRect.destroy();
                piece.tween.destroy();
            }
            delete pieces[piece.id];
            if (msg.c != 'killsuspend') {
                piecesByBoardPos[square] = null;
            }
            piece = null;

            pieceLayer.draw();
        }
    } else if (msg.c == 'gameBegins'){
        $('#gameStatus').html('active');
        for(id in pieces){
            pieces[id].setDelayTimer(3, true);
        }
        if (playNotify == true) {
            var audio = new Audio('/sound/Tick-DeepFrozenApps-397275646.mp3');
            audio.play();
            setTimeout( function() {
                var audio = new Audio('/sound/Tick-DeepFrozenApps-397275646.mp3');
                audio.play();
            }, 1000);
            setTimeout( function() {
                var audio = new Audio('/sound/Tick-DeepFrozenApps-397275646.mp3');
                audio.play();
            }, 2000);
        }
        setTimeout(startGame, 3000)
    } else if (msg.c == 'tactic') {
        var dt = new Date();
        addGameMessage(
            'tactic',
            msg.message,
            'grey',
            'black',
            dt,
            msg.authColor
        );
    } else if (msg.c == 'gamechat') {
        var dt = new Date();
        addGameMessage(
            msg.author,
            msg.message,
            msg.color,
            'black',
            dt,
            msg.authColor
        );
    } else if (msg.c == 'serverDisconnect') {
        var dt = new Date();
        endGame();
        addGameMessage(
            "SYSTEM",
            "game ended due to server error",
            "red",
            'black',
            dt,
            'system'
        );
    } else if (msg.c == 'gameOver') {
        var dt = new Date();
        //endGame();
        var msgText = "game over (" + msg.result + ")";
        if (msg.hasOwnProperty('ratingsAdj')) {
            if (msg.ratingsAdj.hasOwnProperty('white')) {
                var adj = Math.round(msg.ratingsAdj.white);
                msgText += "<br />White: " + (adj >= 0 ? "+" + adj : adj);
            }
            if (msg.ratingsAdj.hasOwnProperty('black')) {
                var adj = Math.round(msg.ratingsAdj.black);
                msgText += "<br />Black: " + (adj >= 0 ? "+" + adj : adj);
            }
            if (msg.ratingsAdj.hasOwnProperty('red')) {
                var adj = Math.round(msg.ratingsAdj.red);
                msgText += "<br />Red: " + (adj >= 0 ? "+" + adj : adj);
            }
            if (msg.ratingsAdj.hasOwnProperty('green')) {
                var adj = Math.round(msg.ratingsAdj.green);
                msgText += "<br />Green: " + (adj >= 0 ? "+" + adj : adj);
            }
        }
        addGameMessage(
            "SYSTEM",
            msgText,
            "red",
            'black',
            dt,
            'system'
        );
        endGame();
    } else if (msg.c == 'playerlost') {
        var dt = new Date();
        addGameMessage(
            "SYSTEM",
            msg.color + " has lost.",
            "red",
            'black',
            dt,
            'system'
        );
    } else if (msg.c == 'refresh') {
        location.reload();
    } else if (msg.c == 'teamsChange') {
        $('#teams').html(msg.teams);

        if (msg.teams == 'white red vs black green') {
          $('#4wayTeamsWhiteRed').attr('checked', true);
        } else {
          $('#4wayTeamsWhiteRed').attr('checked', false);
        }

        if (msg.teams == 'white green vs black red') {
          $('#4wayTeamsWhiteGreen').attr('checked', true);
        } else {
          $('#4wayTeamsWhiteGreen').attr('checked', false);
        }

        if (msg.teams == 'free for all') {
          $('#4wayTeamsFFA').attr('checked', true);
        } else {
          $('#4wayTeamsFFA').attr('checked', false);
        }

        if (msg.teams == 'white black vs red green') {
          $('#4wayTeamsWhiteBlack').attr('checked', true);
        } else {
          $('#4wayTeamsWhiteBlack').attr('checked', false);
        }

        var dt = new Date();
        addGameMessage(
            "SYSTEM",
            msg.msg,
            "red",
            'black',
            dt,
            'system'
        );
    } else if (msg.c == 'systemMsg') {
        var dt = new Date();
        addGameMessage(
            "SYSTEM",
            msg.msg,
            "red",
            'black',
            dt,
            'system'
        );
    } else if (msg.c == 'playerReady') {
        var dt = new Date();
        var audio = new Audio('/sound/public_sound_standard_GenericNotify.ogg');
        if (playNotify) {
          audio.play();
        }
        $('#' + msg.color + 'Ready').html("<br /><small>ready</small");
        addGameMessage(
            "SYSTEM",
            msg.color + " is ready.",
            "red",
            'black',
            dt,
            'system'
        );
    } else if (msg.c == 'requestDraw') {
        var dt = new Date();
        addGameMessage(
            "SYSTEM",
            msg.color + " has requested a draw.",
            "red",
            'black',
            dt,
            'system'
        );
    } else if (msg.c == 'revokeDraw') {
        var dt = new Date();
        addGameMessage(
            "SYSTEM",
            msg.color + " has revoked draw request.",
            "red",
            'black',
            dt,
            'system'
        );
    } else if (msg.c == 'rematch') {
        if (rematches[msg.color] !== 'seen') {
            var dt = new Date();
            addGameMessage(
                "SYSTEM",
                msg.color + " has requested a rematch.",
                "red",
                'black',
                dt,
                'system'
            );
        }
        rematches[msg.color] = 'seen';
        if (msg.hasOwnProperty('gameId')) {
            window.location.replace('/game/' + msg.gameId + (anonKey ? "?anonKey=" + anonKey : ""));
        }
    } else if (msg.c == 'playerAdded') {
        setPlayer(msg.color, JSON.parse(msg.player));
    } else if (msg.c == 'watcherAdded') {
            var dt = new Date();
            var line = '<small>' + msg.screenname + '</small><br />';
            if ($('#game-watchers').html().indexOf(">" + msg.screenname + "<") == -1) {
                if ($('#game-watchers').html() == '(none)') {
                    $('#game-watchers').html(line);
                } else {
                    $('#game-watchers').append(line);
                }
            }
    } else {
        console.log("unknown msg recieved:");
        console.debug(msg);
        console.log("----------------------------------");
    }
}

var setPlayers = function() {
    $('#sit').hide();
    if (whitePlayer) {
        $('#whitePlayerName').text(whitePlayer.screenname);
        if (gameSpeed == 'standard') {
            $('#whiteRating').text(whitePlayer.standard_rating);
        } else if (gameSpeed = 'lightning') {
            $('#whiteRating').text(whitePlayer.lightning_rating);
        }
    } else {
        $('#whitePlayerName').text("(empty seat)");
        $('#whitePlayerRating').text("");
        $('#sit').show();
    }
    if (blackPlayer) {
        $('#blackPlayerName').text(blackPlayer.screenname);
        if (gameSpeed == 'standard') {
            $('#blackRating').text(blackPlayer.standard_rating);
        } else if (gameSpeed = 'lightning') {
            $('#blackRating').text(blackPlayer.lightning_rating);
        }
    } else {
        $('#blackPlayerName').text("(empty seat)");
        $('#blackPlayerRating').text("");
        $('#sit').show();
    }

    if (gameType == '4way') {
        if (redPlayer) {
            $('#redPlayerName').text(redPlayer.screenname);
            if (gameSpeed == 'standard') {
                $('#redRating').text(redPlayer.standard_rating);
            } else if (gameSpeed = 'lightning') {
                $('#redRating').text(redPlayer.lightning_rating);
            }
        } else {
            $('#redPlayerName').text("(empty seat)");
            $('#redPlayerRating').text("");
            $('#sit').show();
        }
        if (greenPlayer) {
            $('#greenPlayerName').text(greenPlayer.screenname);
            if (gameSpeed == 'standard') {
                $('#greenRating').text(greenPlayer.standard_rating);
            } else if (gameSpeed = 'lightning') {
                $('#greenRating').text(greenPlayer.lightning_rating);
            }
        } else {
            $('#greenPlayerName').text("(empty seat)");
            $('#greenPlayerRating').text("");
            $('#sit').show();
        }
    }
}

var setPlayer = function(color, player) {
    if (color == 'white') {
        whitePlayer = player;
    } else if (color == 'black') {
        blackPlayer = player;
    } else if (color == 'red') {
        redPlayer = player;
    } else if (color == 'green') {
        greenPlayer = player;
    }
    setPlayers();
}
var setPieceBoardPos = function(piece, square) {
    piece.square = square;
    piecesByBoardPos[square] = piece;
};

var spawn = function(chr, square) {
        var piece;
        let re = /([a-z])([0-9]{1,2})/;
        var m = square.match(re);
        var f = m[1];
        var r = m[2];

        var piece  = piecesByBoardPos[square];

        if (piece == null) {
            var type = chr;

            var color = 'white';
            if (type > 200) {
                color = 'black';
            }
            if (type > 300) {
                color = 'red';
            }
            if (type > 400) {
                color = 'green';
            }

            var y = rankToX[r];
            var x = fileToY[f];

            if (type % 100 == 6){
                piece = getQueen(x, y, color);
            } else if (type % 100 == 5){
                piece = getKing(x, y, color);
            } else if (type % 100 == 4){
                piece = getRook(x, y, color);
            } else if (type % 100 == 3){
                piece = getBishop(x, y, color);
            } else if (type % 100 == 2){
                piece = getKnight(x, y, color);
            } else if (type % 100 == 1){
                piece = getPawn(x, y, color);
            } else if (type % 100 == 7){
                piece = getDragon(x, y, color);
            } 
            piece.id = maxPieceId++;
            piece.image.on('click', (e) => {
                if (e.evt.button === 2) {
                    var msg = {
                        'c'  : 'cancelPremove',
                        'sq' : xToFile[piece.x] + yToRank[piece.y]                    }
                    sendMsg(msg);
                }
            });
            pieceLayer.add(piece.image);
            pieces[piece.id] = piece;
            if (piece.color == myColor || myColor == 'both'){
                pieces[piece.id].image.draggable(true);
            }
            var square = getPieceSquare(piece);
            setPieceBoardPos(piece, square);

            pieceLayer.draw();
        }
}

var clearBoard = function(clearPremoves = false, clearDelays = false) {
    for(id in pieces){
		pieces[id].image.destroy();
    }
    pieces = [];
    piecesByBoardPos = {};
    pieceLayer.draw();

    Object.keys(premoves).forEach(function (key) {
        premoves[key].opacity(0.0);
    })
    Object.keys(delays).forEach(function (key) {
        delays[key].opacity(0.0);
    })
}

conn.onmessage = function(evt) {

	var msg = JSON.parse(evt.data);
    if (msg.c != 'pong') {
        //console.log("msg recieved: " + evt.data);
    }
    handleMessage(msg);
};

var music = new Audio('/sound/judo_chess_kfc_remake_final_soft.mp3');
var startGame = function(){
    if (! replayMode) {
        if (playNotify == true) {
            var audio = new Audio('/sound/Boxing_Mma_Or_Wrestling_Bell-SoundBible.com-252285194.mp3');
            audio.play();
        }
        if (playMusic == true) {
            music.loop=true;
            music.play();
        }
        $('#whiteReady').hide();
        $('#blackReady').hide();
        $('#redReady').hide();
        $('#greenReady').hide();
        $('#gameStatusWaitingToStart').hide();
        $('#gameStatusActive').show();
        $('#gameStatusWaitingToEnded').hide();
    }
}

var killPlayer = function(color){
    for(id in pieces){
        piece = pieces[id];
        if (piece != null && piece.color == color) {
            piece.image.destroy();
            if (piece.delayRect){
                piece.delayRect.destroy();
                piece.tween.destroy();
            }
            delete pieces[id];
            // was causing bugs if a piece moved there someone before it got deleted.
            // not sure how that's possible but it happened. Probably not even needed.
            //piecesByBoardPos[piece.square] = null;
        }
    }
    pieceLayer.draw();
}

var endGame = function(){
    music.pause();
    if (! replayMode) {
        $('#gameStatus').html('finished');
        $('#gameStatusWaitingToStart').hide();
        $('#gameStatusActive').hide();
        $('#gameStatusEnded').show();

        for(id in pieces){
            if (pieces[id].color == myColor || myColor == 'both'){
                pieces[id].image.draggable(false);
            }
        }
    }
}

var getBoardPos = function(pos){
    var bPos = {};
    bPos.x = Math.floor(getX(pos.x, pos.y) / width * boardSize);
    bPos.y = Math.floor(getY(pos.x, pos.y) / width * boardSize);

    // don't really understand why this is needed but whatever
    // something about the board being flipped
	if (myColor == 'black'){
		bPos.y++;
		bPos.x++;
	}
	if (myColor == 'red'){
		bPos.y++;
		bPos.x++;
	}
    return bPos;
};

var getPieceAtBoardPos = function(boardPos) {
    var file = xToFile[boardPos.x];
    var rank = yToRank[boardPos.y];

    var square = "" + file + rank;
    return piecesByBoardPos[square];
};

var getPixelPos = function(pos){
    var bPos = {};
    bPos.x = Math.floor(getX(pos.x, pos.y) * width / boardSize);
    bPos.y = Math.floor(getY(pos.x, pos.y) * width / boardSize);
    return bPos;
};

// translates coorinates into board ajusted (i.e. flipped for black)
var getXCoordinate = function(x,y) {
    if (myColor == 'red'){
        return boardSize - y - 1;
    }
    if (myColor == 'green'){
        return y;
    }
    if (myColor == 'black'){
        return boardSize - x - 1;
    }
	return x;

}

var getYCoordinate = function(x,y) {
	if (myColor == 'black'){
		return boardSize - y - 1;
	}
    if (myColor == 'red'){
        return boardSize - x - 1;
    }
    if (myColor == 'green'){
        return x;
    }
	return y;
}

// translates absolute x,y into board ajusted, (i.e. flipped for black)
var getX = function(x, y){
    if (myColor == 'red'){
        return height - y - (height / boardSize);
    }
    if (myColor == 'green'){
        return y;
    }
    if (myColor == 'black'){
        return height - x - (height / boardSize);
    }
	return x;
};

var getY = function(x, y){
	if (myColor == 'black'){
		return height - y - (height / boardSize);
	}
    if (myColor == 'red'){
        return height - x - (height / boardSize);
    }
    if (myColor == 'green'){
        return x;
    }
	return y;
};

var getPieceImage = function(x, y, image){
    var pieceImage = new Konva.Image({
        image: image,
        x: getX(x * width / boardSize, y * height / boardSize),
        y: getY(x * width / boardSize, y * height / boardSize),
        width: width / boardSize,
        height: height / boardSize,
        draggable: false,
        shadowColor: 'black',
        shadowBlur: 1,
        shadowOffset: { x: 0, y: 0 },
        shadowOpacity: 0.0,
    });
    return pieceImage;
};

var getPawn = function(x, y, color){
    var pawnImage;
    if (color == "white"){
        pawnImage = whitePawn;
    } else if (color == 'red') {
        pawnImage = redPawn;
    } else if (color == 'green') {
        pawnImage = greenPawn;
    } else {
        pawnImage = blackPawn;
    }
    var piece = getPiece(x, y, color, pawnImage);
    piece.type = 'pawn';
    piece.killSound = new Audio('/sound/kung_fu_punch-Mike_Koenig-2097967259.mp3');

    piece.legalMove = function(x, y){
        var yDir = 1;
        if (this.color == 'black'){
            yDir = -1;
        }
        // let the server decide of moving diagnoally is okay
        if (this.firstMove){
            return ((y == yDir || y == yDir * 2) && x <= Math.abs(1));
        }
        return (y == yDir && x <= Math.abs(1));
    }
    return piece;
}

var getDragon = function(x, y, color){
    var dragonImage;
    if (color == "white"){
        dragonImage = whiteDragon;
    } else if (color == 'red') {
        dragonImage = redDragon;
    } else if (color == 'green') {
        dragonImage = greenDragon;
    } else {
        dragonImage = blackDragon;
    }
    var piece = getPiece(x, y, color, dragonImage);
    piece.type = 'dragon';
    piece.killSound = new Audio('/sound/Roundhouse Kick-SoundBible.com-1663225804.mp3');

    piece.legalMove = function(x, y){
        if (x == 0){ return true; }
        else if (y == 0){ return true; }
        else if (Math.abs(x) == Math.abs(y)){ return true; }
        return false;
    }
    return piece;
}

var getQueen = function(x, y, color){
    var queenImage;
    if (color == "white"){
        queenImage = whiteQueen;
    } else if (color == 'red') {
        queenImage = redQueen;
    } else if (color == 'green') {
        queenImage = greenQueen;
    } else {
        queenImage = blackQueen;
    }
    var piece = getPiece(x, y, color, queenImage);
    piece.type = 'queen';
    piece.killSound = new Audio('/sound/Roundhouse Kick-SoundBible.com-1663225804.mp3');

    piece.legalMove = function(x, y){
        if (x == 0){ return true; }
        else if (y == 0){ return true; }
        else if (Math.abs(x) == Math.abs(y)){ return true; }
        return false;
    }
    return piece;
}

var getKing = function(x, y, color){
    var kingImage;
    if (color == "white"){
        kingImage = whiteKing;
    } else if (color == 'red') {
        kingImage = redKing;
    } else if (color == 'green') {
        kingImage = greenKing;
    } else {
        kingImage = blackKing;
    }
    var piece = getPiece(x, y, color, kingImage);
    piece.type = 'king';
    piece.killSound = new Audio('/sound/Spin Kick-SoundBible.com-1263586030.mp3');

    piece.legalMove = function(x, y){
        if (x == 0){ return true; }
        else if (y == 0){ return true; }
        else if (Math.abs(x) == Math.abs(y)){ return true; }
        return false;
    }
    return piece;
}

var getRook = function(x, y, color){
    var rookImage;
    if (color == "white"){
        rookImage = whiteRook;
    } else if (color == 'red') {
        rookImage = redRook;
    } else if (color == 'green') {
        rookImage = greenRook;
    } else {
        rookImage = blackRook;
    }
    var piece = getPiece(x, y, color, rookImage);
    piece.type = 'rook';
    piece.killSound = new Audio('/sound/Strong_Punch-Mike_Koenig-574430706.mp3');

    piece.legalMove = function(x, y){
        if (x == 0){ return true; }
        else if (y == 0){ return true; }
        return false;
    }
    return piece;
}

var getBishop = function(x, y, color){
    var bishopImage;
    if (color == "white"){
        bishopImage = whiteBishop;
    } else if (color == 'red') {
        bishopImage = redBishop;
    } else if (color == 'green') {
        bishopImage = greenBishop;
    } else {
        bishopImage = blackBishop;
    }
    var piece = getPiece(x, y, color, bishopImage);
    piece.type = 'bishop';
    piece.killSound = new Audio('/sound/Right Cross-SoundBible.com-1721311663.mp3');

    piece.legalMove = function(x, y){
        if (Math.abs(x) == Math.abs(y)){ return true; }
        return false;
    }
    return piece;
}

var getKnight = function(x, y, color){
    var knightImage;
    if (color == "white"){
        knightImage = whiteKnight;
    } else if (color == 'red') {
        knightImage = redKnight;
    } else if (color == 'green') {
        knightImage = greenKnight;
    } else {
        knightImage = blackKnight;
    }
    var piece = getPiece(x, y, color, knightImage);
    piece.type = 'knight';
    piece.killSound = new Audio('/sound/Kick-SoundBible.com-1331196005.mp3');

    piece.legalMove = function(x, y){
        if (Math.abs(x) == 2 && Math.abs(y) == 1){ return true; }
        else if (Math.abs(y) == 2 && Math.abs(x) == 1){ return true; }
        return false;
    }
    return piece;
}

// piece that is inheritted from
var getPiece = function(x, y, color, image){
    var piece = {};
    piece.x = x;
    piece.y = y;
    piece.color = color;
    piece.image = getPieceImage(x, y, image);
    piece.rawImage = image;
    piece.isMoving  = false;
    piece.firstMove = true;

    // TODO need to redraw premoves and piece delays here
    piece.refreshImage = function() {
        piece.image = getPieceImage(piece.x, piece.y, piece.rawImage);
        if (piece.color == myColor || myColor == 'both'){
            piece.image.draggable(true);
        }
        piece.image_id = piece.image._id;
        piecesByImageId[piece.image_id] = piece;
        pieceLayer.add(piece.image);
    }
    
    piece.setPieceSpeed = function() {
        if (color == 'white') {
            piece.timerSpeed = timerSpeedWhite;
        } else if (color == 'black') {
            piece.timerSpeed = timerSpeedBlack;
        } else if (color == 'red') {
            piece.timerSpeed = timerSpeedRed;
        } else if (color == 'green') {
            piece.timerSpeed = timerSpeedGreen;
        }
        
        if (color == 'white') {
            piece.timerRecharge = timerRechargeWhite;
        } else if (color == 'black') {
            piece.timerRecharge = timerRechargeBlack;
        } else if (color == 'red') {
            piece.timerRecharge = timerRechargeRed;
        } else if (color == 'green') {
            piece.timerRecharge = timerRechargeGreen;
        }
    }
    piece.setPieceSpeed();

    piece.image_id = piece.image._id;
    piecesByImageId[piece.image_id] = piece;

    piece.promoteToQueen = function() {
        pieces[piece.id].image.destroy();
        var newQueen = getQueen(piece.x, piece.y, piece.color);
        newQueen.id = piece.id;
        pieceLayer.add(newQueen.image);
        pieces[newQueen.id] = newQueen;
        newQueen.setImagePos(newQueen.x, newQueen.y);
        if (piece.color == myColor || myColor == 'both'){
            newQueen.image.draggable(true);
        }
        setPieceBoardPos(newQueen, piece.square);
        pieceLayer.draw();
    }

    piece.move = function(x, y, speedAdj = 1){
        var dx = x - piece.x;
        var dy = y - piece.y;
        var vectorLen = Math.sqrt((dx * dx) + (dy * dy));
        piece.image.shadowOpacity(0.3);
        if (myColor == 'black') {
            piece.image.shadowOffset({
                x: (-dx * boardSize / 2) / vectorLen,
                y: ( dy * boardSize / 2) / vectorLen
            });
        } else if (myColor == 'red') {
            piece.image.shadowOffset({
                x: (-dy * boardSize / 2) / vectorLen,
                y: ( dx * boardSize / 2) / vectorLen
            });
        } else if (myColor == 'green') {
            piece.image.shadowOffset({
                x: (-dy * boardSize / 2) / vectorLen,
                y: (-dx * boardSize / 2) / vectorLen
            });
        } else {
            piece.image.shadowOffset({
                x: (-dx * boardSize / 2) / vectorLen,
                y: (-dy * boardSize / 2) / vectorLen
            });
        }
        isLegal = true;
        this.start_x = this.x;
        this.start_y = this.y;
        if (isLegal){
            this.x = x;
            this.y = y;
        }
        //piece.setImagePos();
        if (this.x != this.start_x || this.y != this.start_y){
            this.image.draggable(false);
            this.isMoving = true;
            piece.firstMove = false;
            // diagonal pieces move just as fast forward as straight pieces
            var x_dist = Math.abs(this.start_x - this.x);
            var y_dist = Math.abs(this.start_y - this.y);
            var longer_dist = (x_dist > y_dist ? x_dist : y_dist);
            piece.anim_length =  (longer_dist * piece.timerSpeed * speedAdj) * 1000;
            piece.anim = new Konva.Animation(function(frame) {
                var new_x = (piece.start_x * width / boardSize) + ((piece.x - piece.start_x) * (frame.time / piece.anim_length) * width / boardSize);
                var new_y = (piece.start_y * width / boardSize) + ((piece.y - piece.start_y) * (frame.time / piece.anim_length) * width / boardSize);
                piece.image.setX(getX(new_x, new_y));
                piece.image.setY(getY(new_x, new_y));

                if ((frame.time > piece.anim_length)){
                    this.stop();
                    if (piece.color == myColor || myColor == 'both'){
                        piece.image.draggable(true);
                    }
                    piece.isMoving = false;

                    if (pieces[piece.id] != null) {
                        piece.setDelayTimer(piece.timerRecharge)
                    }

                    if (piece.promote) {
                        piece.promote = null;
                        piece.promoteToQueen();
                    }
                    piece.setImagePos(piece.x, piece.y);
                }
            }, pieceLayer);
            piece.anim.start();
        }
    }

    piece.stop = function(new_x, new_y, timeToCharge = piece.timerRecharge) {
        piece.x = new_x;
        piece.y = new_y;
        if (piece.hasOwnProperty('anim') && piece.anim != null) {
            piece.anim.stop();
        }
        if (piece.promote) {
            piece.promote = null;
            piece.promoteToQueen();
        }

        if (piece.color == myColor || myColor == 'both'){
            piece.image.draggable(true);
        }
        if (timeToCharge > 0) {
            piece.isMoving = false;
            piece.setDelayTimer(timeToCharge)
            piece.setImagePos(piece.x, piece.y);
        }
    }

    piece.setDelayTimer = function(timeToDelay, forceFullSquare = false) {
        piece.image.shadowOpacity(0);
        if (piece.delayRect) {
            piece.delayRect.destroy();
            piece.tween.destroy();
        }
        var startRatio = (timeToDelay / piece.timerRecharge);
        var heightBuffer = (height / boardSize) - ((height / boardSize) * (startRatio));
        if (forceFullSquare) {
            startRatio = 1;
            heightBuffer = 0;
        }

        var abs_x = getXCoordinate(piece.x, piece.y);
        var abs_y = getYCoordinate(piece.x, piece.y);
        
        var delayKey = "" + piece.x + "" + piece.y;
        delays[delayKey].opacity(0.5);
        delays[delayKey].height((height / boardSize) * (startRatio));
        delays[delayKey].x(getX(piece.x * width / boardSize, piece.y * width / boardSize));
        delays[delayKey].y(getY(piece.x * width / boardSize, piece.y * width / boardSize) + heightBuffer);
        piece.tween = new Konva.Tween({
            node: delays[delayKey],
            // TIMER
            duration: timeToDelay,
            height: 0,
            y: (getY(piece.x * width / boardSize, piece.y * width / boardSize) + (width / boardSize)),
            onFinish: () => hidePremoves(piece),
        });
        piece.tween.play();
        delayLayer.draw();
    }

    piece.legalMove = function(x, y){
        return true;
    }

    piece.setImagePos = function(x, y){
        piece.image.setX(getX(this.x * width / boardSize, this.y * width / boardSize));
        piece.image.setY(getY(this.x * width / boardSize, this.y * width / boardSize));
        pieceLayer.draw();
    }
    return piece;
}

var isOccupied = function(x, y){
    for(id in pieces){
        if (pieces[id].x == x && pieces[id].y == y && pieces[id.isMoving == false]){
            return id;
        }
    }
    return false;
}

// *********************** setup the board
var setupBoard = function(){
    var stage = new Konva.Stage({
        container: 'container',
        width: width + 20,
        height: height + 20
    });

    stage.on('contextmenu', (e) => {
        e.evt.preventDefault();
    });

    for(var i = 0; i < boardSize; i++){
        for(var j = 0; j < boardSize; j++){
            if (gameType == '4way' && j <= 1 && i <= 1) {
                continue;
            }
            if (gameType == '4way' && j <= 1 && i >= 10) {
                continue;
            }
            if (gameType == '4way' && j >= 10 && i >= 10) {
                continue;
            }
            if (gameType == '4way' && j >= 10 && i <= 1) {
                continue;
            }
            var light = '#b2aca3';
            var dark  = '#6a655e';
            var color;
            //if (myColor == 'black' || myColor == 'green') {
                //color = (( (j + (i % 2) ) % 2) != 0 ? light : dark);
            //} else {
                color = (( (j + (i % 2) ) % 2) != 0 ? dark : light);
            //}
            var rect = new Konva.Rect({
              x: i * (width / boardSize),
              y: j * (width / boardSize),
              width: width / boardSize,
              height: height / boardSize,
              fill: color,
            });
            boardLayer.add(rect);

            var delayRect = new Konva.Rect({
              x: i * (width / boardSize),
              y: j * (width / boardSize),
              width: width / boardSize,
              height: height / boardSize,
              fill: '#d7c31d',
              opacity: 0.0
            });
            delays["" + i + "" + j] = delayRect;
            delayLayer.add(delayRect);

            var premoveRect = new Konva.Rect({
              x: i * (width / boardSize),
              y: j * (width / boardSize),
              width: width / boardSize,
              height: height / boardSize,
              fill: '#00a2ff',
              opacity: 0.0
            });
            premoves["" + i + "" + j] = premoveRect;
            premoveLayer.add(premoveRect);
        }
    }  

    for(var i = 0; i < boardSize; i++){
        var rank = new Konva.Text({
            x: i * (width / boardSize) + (width / (boardSize * 2)),
            y: height + 6,
            text: (myColor == 'black' ? String.fromCharCode(97 + boardSize - 1 - i) : String.fromCharCode(97 + i)) ,
            fontSize: 14,
            fontFamily: 'Calibri',
            fill: 'black'
        });
        var file = new Konva.Text({
            x: height + 6,
            y: i * (width / boardSize) + (boardSize * 2),
            text: (myColor == 'black' ? i + 1 : boardSize - i),
            fontSize: 14,
            fontFamily: 'Calibri',
            fill: 'black'
        });
        boardLayer.add(rank);
        boardLayer.add(file);
    }

    stage.add(boardLayer);

    pieceLayer.draw();
    stage.add(delayLayer);
    stage.add(premoveLayer);
    stage.add(pieceLayer);

    return stage;
} 

var setupEvents = function(stage) {
    stage.on("dragstart", function(e){
        var pos = stage.getPointerPosition();
        e.target.offsetX(e.target.x() - pos.x + (width  / boardSize / 2));
        e.target.offsetY(e.target.y() - pos.y + (height / boardSize / 2));
        pieceLayer.draw();
        e.target.opacity(0.5);
    });

    var previousShape;
    //stage.on("dragmove", function(evt){
    //    var pos = stage.getPointerPosition();
    //});
    stage.on("dragend", function(e){
        var pos = stage.getPointerPosition();

        e.target.offsetX(0);
        e.target.offsetY(0);

        piece = piecesByImageId[e.target._id];

        piece.setImagePos(piece.x, piece.y);
        boardPos = getBoardPos(pos);

        var msg = {
            'c'  : 'move',
            'move' : xToFile[piece.x] + yToRank[piece.y] + xToFile[boardPos.x] + yToRank[boardPos.y]
        }
        sendMsg(msg);

        e.target.opacity(1);
        pieceLayer.draw();
    });
    stage.on("dragenter", function(e){
        //pieceLayer.draw();
    });

    stage.on("dragleave", function(e){
        //pieceLayer.draw();
    });

    stage.on("dragover", function(e){
        //pieceLayer.draw();
    });

    stage.on("drop", function(e){
        //var pos = stage.getPointerPosition();
        //pieceLayer.draw();
    });
    return stage;
};

var stage = setupBoard();
stage = setupEvents(stage);

// ------------- CHAT


/**
 * Add message to the chat window
 */
function addGameMessage(author, message, usercolor, textcolor, dt, authColor) {
    var dtString = ' ';
    if (! isNaN(dt.getTime())) {
        dtString =
            (dt.getHours() < 10 ? '0' + dt.getHours() : dt.getHours()) + ':' +
            (dt.getMinutes() < 10 ? '0' + dt.getMinutes() : dt.getMinutes()) + ':' + 
            (dt.getSeconds() < 10 ? '0' + dt.getSeconds() : dt.getSeconds());
    }

    var chatOptionVal = $("input[name='chatOption']:checked").val();
    var doLog = (chatOptionVal == 'public' || (chatOptionVal == 'players' && authColor != "none"));
    if (doLog) {
        message = decodeURIComponent(escape(message));
        $('#game-chat-input').removeAttr('disabled'); // let the user write another message
        game_chatContent.append('<span class="' + usercolor + 'beltColor" style="font-size: 0.8em;">' + author + '</span><span style="font-size: 0.5em;color:grey"> ' + dtString 
            + '</span>&nbsp;&nbsp;<span style="font-size: 0.8em; color:' + textcolor + '">' + message + '</span>' + '<br />');
        $("#game-chat-log").scrollTop($("#game-chat-log")[0].scrollHeight);
    }
}

//$(document).ready(function () {
$(function () {
    $("#progressBar").click(function(e) {
        var width = $(this).width();
        var rect = e.target.getBoundingClientRect();
        var x = e.clientX - rect.left; //x position within the element.

        replayGame(1, 0, x / width);
    });
    var dt = new Date();

    sweepAudio = new Audio('/sound/Sweep Kick-SoundBible.com-808409893.mp3');

    gameChatLog.slice().reverse().forEach(function (msg) {
        var dt   = new Date(Date.now() - (msg.unix_seconds_back * 1000))
        var screenname = msg.screenname;
        if (screenname == null) {
            screenname = 'anonymous';
        }
        if (screenname === 'thebalrog') {
            screenname = 'thebalrog (ADMIN)';
        }
        addGameMessage(
            screenname,
            msg.comment_text, 
            (msg.color ? msg.color : 'green'),
            (msg.text_color ? msg.text_color : 'black'),
            dt,
            'system'
        );
    });
    $("#abortGame").click(function() {
        var msg = {
            "c" : "abort"
        };
        sendMsg(msg);
    });
    $("#stand").click(function() {
        var msg = {
            "c" : "stand"
        };
        sendMsg(msg);
    });
    $("#sit").click(function() {
        var msg = {
            "c" : "sit"
        };
        sendMsg(msg);
    });
    $("#4wayTeamsFFALabel").click(function() {
        var msg = {
            'message' : '/teams free for all',
            'uid' : currentGameUid,
            'auth' : anonKey,
            'gameId' : gameId,
            'c' : 'chat',
        };
        sendMsg(msg);
    });
    $("#4wayTeamsWhiteBlackLabel").click(function() {
        var msg = {
            'message' : '/teams white black',
            'uid' : currentGameUid,
            'auth' : anonKey,
            'gameId' : gameId,
            'c' : 'chat',
        };
        sendMsg(msg);
    });
    $("#4wayTeamsWhiteRedLabel").click(function() {
        var msg = {
            'message' : '/teams white red',
            'uid' : currentGameUid,
            'auth' : anonKey,
            'gameId' : gameId,
            'c' : 'chat',
        };
        sendMsg(msg);
    });
    $("#4wayTeamsWhiteGreenLabel").click(function() {
        var msg = {
            'message' : '/teams white green',
            'uid' : currentGameUid,
            'auth' : anonKey,
            'gameId' : gameId,
            'c' : 'chat',
        };
        sendMsg(msg);
    });
  var orig_speedAdvantage  = speedAdvantage;
  var orig_timerSpeed      = timerSpeed;
  var orig_timerRecharge   = timerRecharge;
  var orig_timerSpeedWhite = timerSpeedWhite;
  var orig_timerSpeedBlack = timerSpeedBlack;
  var orig_timerSpeedRed   = timerSpeedRed;
  var orig_timerSpeedGreen = timerSpeedGreen;
  var orig_timerRechargeWhite = timerRechargeWhite;
  var orig_timerRechargeBlack = timerRechargeBlack;
  var orig_timerRechargeRed   = timerRechargeRed;
  var orig_timerRechargeGreen = timerRechargeGreen;

    var setGameSpeed = function(speed) {
        speedAdvantage  = orig_speedAdvantage * speed;
        timerSpeed      = orig_timerSpeed * speed;
        timerRecharge   = orig_timerRecharge * speed;
        timerSpeedWhite = orig_timerSpeedWhite * speed;
        timerSpeedBlack = orig_timerSpeedBlack * speed;
        timerSpeedRed   = orig_timerSpeedRed * speed;
        timerSpeedGreen = orig_timerSpeedGreen * speed;
        timerRechargeWhite = orig_timerRechargeWhite * speed;
        timerRechargeBlack = orig_timerRechargeBlack * speed;
        timerRechargeRed   = orig_timerRechargeRed * speed;
        timerRechargeGreen = orig_timerRechargeGreen * speed;

        for(id in pieces){
            pieces[id].setPieceSpeed();
        }
    }

    var replayGame = function(speed = 1, jumpTo = 0, jumpToPercent = 0) {
        replayMode = true;

        setGameSpeed(speed);

        clearBoard();

        // clears all active timeouts
        var id = window.setTimeout(function() {}, 0);
        while (id--) {
            window.clearTimeout(id); // will do nothing if no timeout with id is present
        }

        var startTime = 0;
        var gameStart = false;
        var spawnFound = false;
        var lastCategory = 'null';
        var stopSpawning = false;
        gameLog.forEach(function (logMsg) {
            lastCategory = logMsg.msg.c;
            if (logMsg.msg.c == 'spawn') {
                spawnFound = true;
                if (stopSpawning == false) {
                    handleMessage(logMsg.msg);
                }
            } else {
                if (spawnFound) {
                    stopSpawning = true;
                }
            }
        });
        // get the game length and possibly breakpoints of spawn groups
        var gameLength = 0;
        gameLog.forEach(function (logMsg) {
            if (logMsg.msg.c == 'gameBegins') {
                startTime = logMsg.time + 3;
            } else {
                // sort of dumb to loop through them all but the last msg will set this finally
                gameLength = logMsg.time - startTime;
            }
        });

        if (jumpToPercent) {
            jumpTo = (gameLength * jumpToPercent);
        }

        var gameTimeElapsed = 0;      // in game with nothing altered
        var realTimeElapsed = 0;      // time if sped up / slowed down
        var hasJumped = false;

        var lastMsgTime = 0;
        var hasStartedDelayedMsgs = false;
        gameLog.forEach(function (logMsg) {
            if (logMsg.msg.c == 'gameBegins') {
                startTime = logMsg.time + 3;
                gameStart = true;
            } else {
                var msgTimeout = 0;
                var timeSinceLast = (logMsg.time - lastMsgTime);
                realTimeElapsed += (timeSinceLast * speed);
                if (logMsg.msg.c != 'spawn' && logMsg.msg.c != 'playerReady') {
                    if (jumpTo > 0 && realTimeElapsed < jumpTo) {
                        handleMessage(logMsg.msg);
                        setGameSpeed(0.0001);
                    } else {
                        if (! hasStartedDelayedMsgs) {
                            //startTime = lastMsgTime;
                            setGameSpeed(speed);
                            hasStartedDelayedMsgs = true;

                        }
                        msgTimeout = (logMsg.time - startTime);
                        msgTimeout *= speed;

                        setTimeout(
                            function() {
                                handleMessage(logMsg.msg);
                            },
                            msgTimeout * 1000
                        );
                    }
                }
            }
            lastMsgTime = logMsg.time;
        });
        progress(gameLength - jumpTo, gameLength, $("#progressBar"));

    };
    $("#replayGameFast").click(function() {
        replayGame(0.5);
    });
    $("#replayGame").click(function() {
        replayGame(1);
    });
    $("#replayGameSlow").click(function() {
        replayGame(2);
    });
    // game chat
    $('#game-chat-input').bind("enterKey",function(e){
        var dataPost = {
            'message' : $(this).val(),
            'uid' : currentGameUid,
            'auth' : anonKey,
            'gameId' : gameId,
            'c' : 'chat',
        };
        $(this).val('');
        sendMsg(dataPost);
    });

    $('#game-chat-input').keyup(function(e){
        if(e.keyCode == 13)
        {
            $(this).trigger("enterKey");
        }
    });
});

function progress(timeleft, timetotal, $element) {
    var progressBarWidth = $element.width() - (timeleft * $element.width() / timetotal);
    if (timeleft < 0) {
        timeleft = 0;
    }

    var timeHtml = "";
    if (Math.floor(timeleft/60) > 0) {
        timeHtml = Math.floor(timeleft/60).toString().padStart(2, '0') + ":"+ Math.floor(timeleft % 60).toString().padStart(2, '0');
    } else if ((timeleft/60) > 10) {
        timeHtml = Math.floor(timeleft % 60).toString().padStart(2, '0');
    } else if (timeleft > 0) {
        timeHtml = Math.floor(timeleft % 60);
    }
    
    $element.find('div').animate(
        { width: progressBarWidth }
        , 500
    ).html(timeHtml);
    if(timeleft > 0) {
        setTimeout(function() {
            progress(timeleft - 1, timetotal, $element);
        }, 1000);
    }
};

/*
 *  Creates a progressbar.
 *  @param id the id of the div we want to transform in a progressbar
 *  @param duration the duration of the timer example: '10s'
 *  @param callback, optional function which is called when the progressbar reaches 0.
 */
function createProgressbar(id, duration, callback) {
  // We select the div that we want to turn into a progressbar
  var progressbar = document.getElementById(id);
  progressbar.className = 'progressbar';

  // We create the div that changes width to show progress
  var progressbarinner = document.createElement('div');
  progressbarinner.className = 'inner';

  // Now we set the animation parameters
  progressbarinner.style["animation-duration"]  = duration + "s";

  // Eventually couple a callback
  if (typeof(callback) === 'function') {
    progressbarinner.addEventListener('animationend', callback);
  }

  // Append the progressbar to the main progressbardiv
  $("#" + id).empty();
  progressbar.appendChild(progressbarinner);

  // When everything is set up we start the animation
  progressbarinner.style.animationPlayState = 'running';
}
