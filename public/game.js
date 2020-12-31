var checkPoolRunning = false;
var checkPoolGameSpeed = gameSpeed;
var cancelCheckPool = false;

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

function rematchPool(originalThread = false) {
    if (cancelRematchPool) {
        console.log("canceling rematch pool");
        rematchPoolRunning = false;
        cancelRematchPool = false;
        return ;
    }
    var setInterval = originalThread;
    if (rematchPoolRunning == false) {
        console.log("setting rematch interval");
        rematchPoolRunning = true;
        setInterval = true;
    }
    $.ajax({
        type : 'GET',
        url  : '/ajax/rematch?gameId=' + gameId,
        dataType : 'json',
        success : function(data){
            var jsonRes = data;
            if (jsonRes.hasOwnProperty('gameId')) {
                window.location.replace('/game/' + jsonRes.gameId);
            }
            if (setInterval) {
                intervalPlayer = setTimeout(
                    function() {
                        rematchPool(true);
                    },
                    2000
                );
            }
        }
    });
}

$(function () {
    $("#enter-pool").click(function() {
        if (checkPoolRunning) {
            cancelCheckPool = true;
            $(this).html('Enter Pool');
        } else {
            $(this).html('Enter Pool<br /><span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>');
            checkPoolGameSpeed = gameSpeed;
            checkPool();
        }
    });
    $("#rematch").click(function() {
        if (rematchPoolRunning) {
            cancelRematchPool = true;
            $(this).html('Rematch');
        } else {
            $(this).html('Requesting Rematch...<br /><span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>');
            rematchPool();
        }
    });
});

var width  = 320;
var height = 320;

var boardContent = $("#boardContainer");
var game_chatContent = $('#game-chat-log');
var input = $('#game-chat-input');

var maxPieceId = 1;

width = boardContent.width();
height = $("#boardContainer").width();

$(window).resize(function(){
    width = boardContent.width();
    height = $("#boardContainer").width();
});

var blackLastSeen = null;
var whiteLastSeen = null;

var myPing = null;
var blackPing = null;
var whitePing = null;

var boardLayer = new Konva.Layer();
var pieceLayer = new Konva.Layer();
var delayLayer = new Konva.Layer();

var pieces = {};
var piecesByImageId = {};
var piecesByBoardPos = {};
var suspendedPieces = {};
ranks.forEach(function (rank, index) {
    ranks.forEach(function (file, index) {
        piecesByBoardPos["" + rank + file] = null;
        suspendedPieces["" + rank + file] = null;
    });
});

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
console.log(xToFile);
console.log(yToRank);

var globalIdCount = 1;
var replayMode = false;

console.log("connecting..." + authId);

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
};

var joinGame = function(){
        console.log("joinGame()");
		var ret = {
			'c' : 'join',
            'gameId' : gameId
		};
        gameId = gameId;
        sendMsg(ret);
};

var resetGamePieces = function(){
    for(id in pieces){
		pieces[id].image.x(getX(pieces[id].image.x()));
		pieces[id].image.y(getY(pieces[id].image.y()));
    }
	pieceLayer.draw();
};

var bindGameEvents = function(ws_conn) {
    conn.onopen = function(evt) {
        // finished connecting.
        // maybe query for ready to join
        console.log("connected!");
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
        joinGame();
        initialMessages.forEach(function (item, index) {
            handleMessage(item);
        });
    };

    conn.onerror = function(e) {
        console.log('Error!');
    };

    conn.onclose = function(e) {
        console.log('Disconnected!');
        game_reconnectInterval = setTimeout(
            game_reconnectMain,
            1000
        );
    };
};
var conn = new WebSocket("wss://" + wsDomain + "/ws");
bindGameEvents(conn);

var game_reconnectInterval;
var game_reconnectMain = function() {
    if (isConnected == false) {
        $("#connectionStatus").html("Reconnecting...");
        conn = null;
        conn = new WebSocket("wss://" + wsDomain + "/ws");
        bindGameEvents(main_conn);
    } else {
        reconnectInterval = null;
    }
}


sendMsg = function(msg) {
    if (msg.c != 'ping') {
        console.log("sending msg:");
        console.log(msg);
    }
    msg.gameId = gameId;
    msg.auth = authId;
    conn.send(JSON.stringify(msg));
};

readyToStart = function() {
    $("#readyToStart").attr("disabled","disabled");
    
    var msg = {
        "c" : "readyToBegin"
    };
    sendMsg(msg);
}

resign = function(){
    var msg = {
        "c" : "resign"
    };
    sendMsg(msg);
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

var handleMessage = function(msg) {
    if (msg.c == 'move'){  // called when a piece changes positions (many times in one "move")
        var from = getSquareFromBB(msg.fr_bb);
        var to   = getSquareFromBB(msg.to_bb);

        pieceFrom = piecesByBoardPos[from];
        //console.log("pieceFrom:");
        //console.log(pieceFrom);
        //console.log("board:");
        console.log(piecesByBoardPos);
        piecesByBoardPos[to]   = pieceFrom;
        piecesByBoardPos[from] = null;
        console.log("moved " + from + " to " + to);
        //console.log(piecesByBoardPos);
    } else if (msg.c == 'moveAnimate'){ // called when a player moves a piece
        var m = msg.move.split('');

        console.log('moveAnimate');
        console.log(msg);

        var from = m[0].concat(m[1]);
        var to   = m[2].concat(m[3]);
        
        console.log("animate move from " + from + "," + to);

        if (msg.moveType == 3) {        // OO
            var pieceFrom = piecesByBoardPos[from];
            var pieceTo   = piecesByBoardPos[to];
            var y_king = rankToX[m[3]];
            var x_king = parseInt(fileToY[m[2]]) - 1;
            pieceFrom.move(x_king, y_king);

            var y_rook = rankToX[m[1]];
            var x_rook = parseInt(fileToY[m[0]]) + 1;
            console.log(y_rook + " , " + x_rook);
            pieceTo.move(x_rook, y_rook);
        } else if (msg.moveType == 4) { // OOO
            var pieceFrom = piecesByBoardPos[from];
            var pieceTo   = piecesByBoardPos[to];
            var y_king = rankToX[m[3]];
            var x_king = parseInt(fileToY[m[2]]) + 1;
            pieceFrom.move(x_king, y_king);

            var y_rook = rankToX[m[1]];
            var x_rook = parseInt(fileToY[m[0]]) - 2;
            console.log(y_rook + " , " + x_rook);
            pieceTo.move(x_rook, y_rook);
        } else { // all others
            var pieceFrom = piecesByBoardPos[from];
            console.log('animating piece');
            console.log(pieceFrom);
            console.log(m);
            var y = rankToX[m[3]];
            var x = fileToY[m[2]];
            pieceFrom.move(x, y);
        }
    } else if (msg.c == 'promote'){
        var square = getSquareFromBB(msg.bb);
        var piece = piecesByBoardPos[square];

		pieces[piece.id].image.destroy();
		var newQueen = getQueen(piece.x, piece.y, piece.color);
		newQueen.id = piece.id;
		pieceLayer.add(newQueen.image);
		pieces[newQueen.id] = newQueen;
        console.log(piece);
        console.log(newQueen);
        newQueen.setImagePos(newQueen.x, newQueen.y);
        if (piece.color == myColor || myColor == 'both'){
            newQueen.image.draggable(true);
        }
        piecesByBoardPos[square] = newQueen;
		pieceLayer.draw();
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
        console.debug(msg);
		resetGamePieces();
		pieceLayer.draw();
    } else if (msg.c == 'suspend'){
        // knights and castles are removed from the board entirely 
        // when they move, until they land.
        var from = getSquareFromBB(msg.fr_bb);
        var to   = getSquareFromBB(msg.to_bb);
        console.log('suspending ' + from + ", " + to);
        var piece = piecesByBoardPos[from];
        suspendedPieces[to] = piece;

        piecesByBoardPos[from] = null;
    } else if (msg.c == 'unsuspend'){
        // this is for knights and castles where the piece
        // is removed from the board then put down at the destination
        var square = getSquareFromBB(msg.to_bb);
        var piece = suspendedPieces[square];

        console.log('unsuspending ' + square + "(" + msg.to_bb + ")");
        console.log(piece);
        piecesByBoardPos[square] = piece;
        suspendedPieces[square] = null;
    } else if (msg.c == 'spawn'){
        var piece;
        var chr = msg.chr;
        var m = msg.square.split('');
        var f = m[0];
        var r = m[1];

        var piece  = piecesByBoardPos[msg.square];

        console.log('spawning at ' + m + ' piece: ' + chr);
        console.log('current piece:');
        console.log(piece);
        console.log(piecesByBoardPos);

        if (piece == null) {
            var type = chr;

            var color = 'white';
            if (type > 100) {
                color = 'black';
            }
            if (type > 200) {
                color = 'red';
            }
            if (type > 200) {
                color = 'green';
            }

            var y = rankToX[r];
            var x = fileToY[f];

            if (type % 100 == 6){
                piece = getQueen(x, y, color);
            } else if (type % 100 == 5){
                piece = getKing(x, y, color);
            } else if (type % 100 == 2){
                piece = getRook(x, y, color);
            } else if (type % 100 == 4){
                piece = getBishop(x, y, color);
            } else if (type % 100 == 3){
                piece = getKnight(x, y, color);
            } else if (type % 100 == 1){
                piece = getPawn(x, y, color);
            } 
            piece.id = maxPieceId++;
            pieceLayer.add(piece.image);
            pieces[piece.id] = piece;
            if (piece.color == myColor || myColor == 'both'){
                pieces[piece.id].image.draggable(true);
            }
            var square = getPieceSquare(piece);
            piecesByBoardPos[square] = piece;

            pieceLayer.draw();
        }
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
        } else if (msg.color = 'white') {
            whitePing = msg.ping;
            whiteLastSeen = timestamp;
            updateTimeStamps();
            // i sent this message so the ping timestamp is mine
            if (myColor == 'white') {
                myPing = timestamp - msg.timestamp;
            }
        }
    } else if (msg.c == 'kill'){
        var square = getSquareFromBB(msg.bb);
        var piece  = piecesByBoardPos[square];

        if (piece != null) {
            piece.image.destroy();
            if (piece.delayRect){
                piece.delayRect.destroy();
            }
            delete pieces[piece.id];
            piecesByBoardPos[square] = null;

            pieceLayer.draw();
        }
    } else if (msg.c == 'gameBegins'){
		for(id in pieces){
            pieces[id].setDelayTimer(3);
		}
        setTimeout(startGame, 3000)
    } else if (msg.c == 'chat') {
        input.removeAttr('disabled'); // let the user write another message
        var dt = new Date();
        addGameMessage(
            msg.author,
            msg.message,
            "green",
            'black',
            dt
        );
    } else if (msg.c == 'playerlost') {
        var dt = new Date();
        endGame();
        addGameMessage(
            "SYSTEM",
            msg.color + " has lost.",
            "red",
            'black',
            dt
        );
    } else if (msg.c == 'requestDraw') {
        if (msg.color == myColor) {

        }
        addGameMessage(
            "SYSTEM",
            msg.color + " as requested a draw.",
            "red",
            'black',
            dt
        );
    } else if (msg.c == 'gameDrawn') {
        var dt = new Date();
        endGame();
        addGameMessage(
            "SYSTEM",
            "The game has drawn.",
            "red",
            'black',
            dt
        );
    } else if (msg.c == 'resign') {
        var dt = new Date();
        endGame();
        addGameMessage(
            "SYSTEM",
            msg.color + " has resigned.",
            "red",
            'black',
            dt
        );
    } else if (msg.c == 'abort') {
        var dt = new Date();
        endGame();
        addGameMessage(
            "SYSTEM",
            "game has been aborted.",
            "red",
            'black',
            dt
        );
    } else {
        console.log("unknown msg recieved");
        console.debug(msg);
    }

}

var clearBoard = function() {
    for(id in pieces){
		pieces[id].image.destroy();
    }
    pieces = [];
    pieceLayer.draw();
}

conn.onmessage = function(evt) {

	var msg = JSON.parse(evt.data);
    if (msg.c != 'pong') {
        console.log("msg recieved: " + evt.data);
    }
    handleMessage(msg);
};

var startGame = function(){
    if (! replayMode) {
        $('#gameStatusWaitingToStart').hide();
        $('#gameStatusActive').show();
        $('#gameStatusWaitingToEnded').hide();
    }
}

var endGame = function(){
    if (! replayMode) {
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
    bPos.x = Math.floor(getX(pos.x) / width * boardSize);
    bPos.y = Math.floor(getY(pos.y) / height * boardSize);
	if (myColor == 'black'){
		bPos.y++;
	}
    return bPos;
};

var getPixelPos = function(pos){
    var bPos = {};
    bPos.x = Math.floor(getX(pos.x) * width / boardSize);
    bPos.y = Math.floor(getY(pos.y) * height / boardSize);
    return bPos;
};

var getX = function(x){
	if (myColor == 'black'){
		//return width - x - (width / boardSize);
	}
	return x;
};

var getY = function(y){
	if (myColor == 'black'){
		return height - y - (height / boardSize);
	}
	return y;
};

var getPieceImage = function(x, y, image){
    var pieceImage = new Konva.Image({
        image: image,
        x: x * width / boardSize,
        y: getY(y * height / boardSize),
        width: width / boardSize,
        height: height / boardSize,
        draggable: false
    });
    return pieceImage;
};

var getPawn = function(x, y, color){
    var pawnImage;
    if (color == "white"){
        pawnImage = whitePawn;
    } else {
        pawnImage = blackPawn;
    }
    var piece = getPiece(x, y, color, pawnImage);

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

var getQueen = function(x, y, color){
    var queenImage;
    if (color == "white"){
        queenImage = whiteQueen;
    } else {
        queenImage = blackQueen;
    }
    var piece = getPiece(x, y, color, queenImage);

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
    } else {
        kingImage = blackKing;
    }
    var piece = getPiece(x, y, color, kingImage);

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
    } else {
        rookImage = blackRook;
    }
    var piece = getPiece(x, y, color, rookImage);

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
    } else {
        bishopImage = blackBishop;
    }
    var piece = getPiece(x, y, color, bishopImage);

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
    } else {
        knightImage = blackKnight;
    }
    var piece = getPiece(x, y, color, knightImage);

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
    piece.isMoving  = false;
    piece.firstMove = true;

    piece.image_id = piece.image._id;
    piecesByImageId[piece.image_id] = piece;

    piece.move = function(x, y){
        //if (x < 0){ return false };
        //if (y < 0){ return false };
        //if (x > 7){ return false };
        //if (y > 7){ return false };

        isLegal = this.legalMove(this.x - x, this.y - y);
        //if (!isLegal){
            //return false;
        //}
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
            //piece.anim_length = Math.sqrt( Math.pow(Math.abs(this.start_x - this.x), 2) + Math.pow(Math.abs(this.start_y - this.y), 2)) * timer * 100;
            // diagonal pieces move just as fast forward as straight pieces
            var x_dist = Math.abs(this.start_x - this.x);
            var y_dist = Math.abs(this.start_y - this.y);
            var longer_dist = (x_dist > y_dist ? x_dist : y_dist);
            piece.anim_length =  (longer_dist * timerSpeed / 10) * 1000;
            piece.anim = new Konva.Animation(function(frame) {
                var new_x = (piece.start_x * width / boardSize) + ((piece.x - piece.start_x) * (frame.time / piece.anim_length) * width / boardSize);
                var new_y = (piece.start_y * width / boardSize) + ((piece.y - piece.start_y) * (frame.time / piece.anim_length) * width / boardSize);
                piece.image.setX(getX(new_x));
                piece.image.setY(getY(new_y));

                if (frame.time > piece.anim_length){
                    this.stop();
                    piece.image.draggable(true);
                    piece.isMoving = false;

                    if (pieces[piece.id] != null) {
                        piece.setDelayTimer(timerRecharge)
                    }

                    piece.setImagePos(piece.x, piece.y);
                }
            }, pieceLayer);
            piece.anim.start();
        }
    }

    piece.setDelayTimer = function(timeToDelay) {
        var rect = new Konva.Rect({
            x: getX(piece.x * width / boardSize),
            y: getY(piece.y * width / boardSize),
            width: width / boardSize,
            height: height / boardSize,
            fill: '#888822',
            opacity: 0.5
        });
        delayLayer.add(rect);

        var tween = new Konva.Tween({
            node: rect,
            // TIMER
            duration: timeToDelay,
            height: 0,
            y: (getY(piece.y * width / boardSize) + (width / boardSize)),
        });
        piece.delayRect = rect;
        tween.play();
        delayLayer.draw();
    }

    piece.legalMove = function(x, y){
        return true;
    }

    piece.setImagePos = function(x, y){
        piece.image.setX(getX(this.x * width / boardSize));
        piece.image.setY(getY(this.y * width / boardSize));
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

    for(var i = 0; i < boardSize; i++){
        for(var j = 0; j < boardSize; j++){
            var rect = new Konva.Rect({
              x: i * (width / boardSize),
              y: j * (width / boardSize),
              width: width / boardSize,
              height: height / boardSize,
              fill: (( (j + (i % 2) ) % 2) != 0 ? '#EEEEEE' : '#c1978e'),
            });
            boardLayer.add(rect);
        }
    }  

    for(var i = 0; i < boardSize; i++){
        var rank = new Konva.Text({
            x: i * (width / boardSize) + (width / (boardSize * 2)),
            y: height + 6,
            text: String.fromCharCode(97 + i),
            fontSize: 14,
            fontFamily: 'Calibri',
            fill: 'black'
        });
        var file = new Konva.Text({
            x: height + 6,
            y: i * (width / boardSize) + (boardSize * 2),
            text: boardSize - i,
            fontSize: 14,
            fontFamily: 'Calibri',
            fill: 'black'
        });
        boardLayer.add(rank);
        boardLayer.add(file);
    }

    stage.add(boardLayer);

    pieceLayer.draw();
    stage.add(pieceLayer);
    stage.add(delayLayer);

    return stage;
} 

var stage = setupBoard();

var tempLayer = new Konva.Layer();
stage.add(tempLayer);
var text = new Konva.Text({
    fill : 'black'
});
stage.on("dragstart", function(e){
    //e.target.moveTo(tempLayer);
    var pos = stage.getPointerPosition();
	e.target.offsetX(e.target.x() - pos.x + (width  / boardSize / 2));
	e.target.offsetY(e.target.y() - pos.y + (height / boardSize / 2));
    pieceLayer.draw();
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

    console.log(boardPos);
	var msg = {
		'c'  : 'move',
		'id' : piece.id,
		'x'  : boardPos.x,
		'y'  : boardPos.y,
        'move' : xToFile[piece.x] + yToRank[piece.y] + xToFile[boardPos.x] + yToRank[boardPos.y]
	}
    sendMsg(msg);

    pieceLayer.draw();
});
stage.on("dragenter", function(e){
    pieceLayer.draw();
});

stage.on("dragleave", function(e){
    e.target.fill('blue');
    pieceLayer.draw();
});

stage.on("dragover", function(e){
    pieceLayer.draw();
});

stage.on("drop", function(e){
    var pos = stage.getPointerPosition();
    //e.target.fill('red');

    //var anim = new Konva.Animation(function(frame) {
        //var piece = e.target;
        //piece.setX(amplitude * Math.sin(frame.time * 2 * Math.PI / period) + centerX);
    //}, pieceLayer);
    pieceLayer.draw();
});

// ------------- CHAT


/**
 * Send mesage when user presses Enter key
 */
input.keydown(function(e) {
    if (e.keyCode === 13) {
        var message = $(this).val();
        if (! message ){
            return;
        }

        var msg = {
            'c' : 'chat',
            'message' : message,
        };
        console.log(msg);
        // send the message as an ordinary text
        sendMsg(msg);
        $(this).val('');
        // disable the input field to make the user wait until server
        // sends back response
        input.attr('disabled', 'disabled');
    }
});

/**
 * Add message to the chat window
 */
function addGameMessage(author, message, color, textcolor, dt) {
    game_chatContent.append('<p><span style="color:' + color + '">' + author + '</span><span style="font-size: 12px;color:grey"> ' +
            + (dt.getHours() < 10 ? '0' + dt.getHours() : dt.getHours()) + ':'
            + (dt.getMinutes() < 10 ? '0' + dt.getMinutes() : dt.getMinutes())
            + '</span> ' + message + '</p>');
    game_chatContent.scrollTop = game_chatContent.scrollHeight;
}

//$(document).ready(function () {
$(function () {
    $("#abortGame").click(function() {
        var msg = {
            "c" : "abort"
        };
        sendMsg(msg);
    });
    $("#replayGame").click(function() {
        replayMode = true;
        clearBoard();

        // clears all active timeouts
        var id = window.setTimeout(function() {}, 0);
        while (id--) {
            window.clearTimeout(id); // will do nothing if no timeout with id is present
        }

        var startTime = 0;
        var gameStart = false;
        gameLog.forEach(function (logMsg) {
            if (logMsg.msg.c == 'gameBegins') {
                startTime = logMsg.time + 3;
                gameStart = true;
            } else {
                var msgTimeout = 0;
                if (gameStart) {
                    msgTimeout = (logMsg.time - startTime) * 1000;
                }
                setTimeout(
                    function() {
                        handleMessage(logMsg.msg);
                    },
                    msgTimeout
                );
            }
        });
    });
});
