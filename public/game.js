var width  = 320;
var height = 320;

var boardContent = $("#boardContainer");
var game_chatContent = $('#game-chat-log');
var input = $('#game-chat-input');

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
		var ret = {
			'c' : 'join',
            'gameId' : gameId
		};
        gameId = gameId;
        sendMsg(ret);
};

var playerJoinGame = function(){
		var ret = {
			'c' : 'playerjoin',
            'gameId' : gameId,
		};
        gameId = gameId;
        sendMsg(ret);
        $('#join').attr('disabled', 'disabled');
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
var conn = new WebSocket("ws://" + wsDomain + ":3000/ws");
bindGameEvents(conn);

var game_reconnectInterval;
var game_reconnectMain = function() {
    if (isConnected == false) {
        $("#connectionStatus").html("Reconnecting...");
        conn = null;
        conn = new WebSocket("ws://" + wsDomain + ":3000/ws");
        bindGameEvents(main_conn);
    } else {
        reconnectInterval = null;
    }
}


sendMsg = function(msg) {
    if (msg.c != 'pong') {
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

var handleMessage = function(msg) {
    if (msg.c == 'move'){
        pieces[msg.id].move(msg.x, msg.y);
    } else if (msg.c == 'promote'){
		pieces[msg.id].image.destroy();
		var newQueen = getQueen(pieces[msg.id].x, pieces[msg.id].y, pieces[msg.id].color);
		newQueen.id = msg.id;
		pieceLayer.add(newQueen.image);
		pieces[msg.id] = newQueen;
        if (pieces[msg.id].color == myColor || myColor == 'both'){
            pieces[msg.id].image.draggable(true);
        }
		pieceLayer.draw();
    } else if (msg.c == 'joined'){
        console.debug(msg);
		console.log('joined ' + authId + ", ", myColor);
		// TODO mark all color pieces as draggabble
		for(id in pieces){
            console.log(myColor);
			if (pieces[id].color == myColor || myColor == 'both'){
				pieces[id].image.draggable(true);
			}
		}
        console.debug(msg);
		resetGamePieces();
		pieceLayer.draw();
    } else if (msg.c == 'spawn'){
        var piece;
        if (msg.type == 'queen'){
            piece = getQueen(msg.x, msg.y, msg.color);
        } else if (msg.type == 'king'){
            piece = getKing(msg.x, msg.y, msg.color);
        } else if (msg.type == 'rook'){
            piece = getRook(msg.x, msg.y, msg.color);
        } else if (msg.type == 'bishop'){
            piece = getBishop(msg.x, msg.y, msg.color);
        } else if (msg.type == 'knight'){
            piece = getKnight(msg.x, msg.y, msg.color);
        } else if (msg.type == 'pawn'){
            piece = getPawn(msg.x, msg.y, msg.color);
        } 
        piece.id = msg.id;
		if (! (msg.id in pieces)){
			pieceLayer.add(piece.image);
			pieces[msg.id] = piece;
			if (piece.color == myColor || myColor == 'both'){
				pieces[msg.id].image.draggable(true);
			}
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
        console.log('killing ' + msg.id);
        pieces[msg.id].image.destroy();
        if (pieces[msg.id].delayRect){
            pieces[msg.id].delayRect.destroy();
        }
        delete pieces[msg.id];
        pieceLayer.draw();
    } else if (msg.c == 'gameBegins'){
        console.log('setting readyToStart timeout');
		for(id in pieces){
            console.log(myColor);
            pieces[id].setDelayTimer(3);
		}
        setTimeout(startGame, 3000)
    } else if (msg.c == 'chat') {
        console.log("chat recieved");
        input.removeAttr('disabled'); // let the user write another message
        var dt = new Date();
        addGameMessage(
            msg.author,
            msg.message,
            "green",
            'black',
            dt
        );
    } else if (msg.c == 'newgame') { // both players agreed to rematch
        console.log("new game" + msg.gameId);
        if (anonKey) {
            window.location.replace('/game/' + msg.gameId + "?anonKey=" + anonKey);
        } else {
            window.location.replace('/game/' + msg.gameId);
        }
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
        console.log("msg: " + evt.data);
    }
    handleMessage(msg);
};

var startGame = function(){
    if (! replayMode) {
        console.log('starting game');
        $('#gameStatusWaitingToStart').hide();
        $('#gameStatusActive').show();
        $('#gameStatusWaitingToEnded').hide();
    }
}

var endGame = function(){
    if (! replayMode) {
        console.log('ending');
        $('#gameStatusWaitingToStart').hide();
        $('#gameStatusActive').hide();
        $('#gameStatusEnded').show();

        for(id in pieces){
            console.log(myColor);
            if (pieces[id].color == myColor || myColor == 'both'){
                pieces[id].image.draggable = false;
            }
        }
    }
}

var rematch = function(){
    console.log('rematch');
    $('#rematch').attr('disabled', true);
	var msg = {
		'c'  : 'rematch',
	}
    sendMsg(msg);
}

var getBoardPos = function(pos){
    var bPos = {};
    console.log(pos.x);
    console.log(pos.y);
    bPos.x = Math.floor(getX(pos.x) / width * 8);
    bPos.y = Math.floor(getY(pos.y) / height * 8);
	if (myColor == 'black'){
		bPos.y++;
	}
	console.debug(bPos);
    return bPos;
};

var getPixelPos = function(pos){
    var bPos = {};
    console.log(pos.x);
    bPos.x = Math.floor(getX(pos.x) * width / 8);
    bPos.y = Math.floor(getY(pos.y) * height / 8);
    return bPos;
};

var getX = function(x){
	if (myColor == 'black'){
		//return width - x - (width / 8);
	}
	return x;
};

var getY = function(y){
	if (myColor == 'black'){
		return height - y - (height / 8);
	}
	return y;
};

var getPieceImage = function(x, y, image){
    var pieceImage = new Konva.Image({
        image: image,
        x: x * width / 8,
        y: getY(y * height / 8),
        width: width / 8,
        height: height / 8,
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
        if (x < 0){ return false };
        if (y < 0){ return false };
        if (x > 7){ return false };
        if (y > 7){ return false };

        isLegal = this.legalMove(this.x - x, this.y - y);
        if (!isLegal){
            return false;
        }
        this.start_x = this.x;
        this.start_y = this.y;
        if (isLegal){
            this.x = x;
            this.y = y;
        }
        //piece.setImagePos();
        if (this.x != this.start_x || this.y != this.start_y){
            this.image.draggable = false;
            this.isMoving = true;
            piece.firstMove = false;
            //piece.anim_length = Math.sqrt( Math.pow(Math.abs(this.start_x - this.x), 2) + Math.pow(Math.abs(this.start_y - this.y), 2)) * timer * 100;
            // diagonal pieces move just as fast forward as straight pieces
            var x_dist = Math.abs(this.start_x - this.x);
            var y_dist = Math.abs(this.start_y - this.y);
            var longer_dist = (x_dist > y_dist ? x_dist : y_dist);
            piece.anim_length =  (longer_dist * timerSpeed / 10) * 1000;
            piece.anim = new Konva.Animation(function(frame) {
                var new_x = (piece.start_x * width / 8) + ((piece.x - piece.start_x) * (frame.time / piece.anim_length) * width / 8);
                var new_y = (piece.start_y * width / 8) + ((piece.y - piece.start_y) * (frame.time / piece.anim_length) * width / 8);
                piece.image.setX(getX(new_x));
                piece.image.setY(getY(new_y));

                if (frame.time > piece.anim_length){
                    this.stop();
                    piece.image.draggable = true;
                    piece.isMoving = false;

                    piece.setDelayTimer(timerRecharge)

                    piece.setImagePos(piece.x, piece.y);
                }
            }, pieceLayer);
            piece.anim.start();
        }
    }

    piece.setDelayTimer = function(timeToDelay) {
        var rect = new Konva.Rect({
            x: getX(piece.x * width / 8),
            y: getY(piece.y * width / 8),
            width: width / 8,
            height: height / 8,
            fill: '#888822',
            opacity: 0.5
        });
        delayLayer.add(rect);

        var tween = new Konva.Tween({
            node: rect,
            // TIMER
            duration: timeToDelay,
            height: 0,
            y: (getY(piece.y * width / 8) + (width / 8)),
        });
        piece.delayRect = rect;
        tween.play();
        delayLayer.draw();
    }

    piece.legalMove = function(x, y){
        return true;
    }

    piece.setImagePos = function(x, y){
        piece.image.setX(getX(this.x * width / 8));
        piece.image.setY(getY(this.y * width / 8));
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
        width: width,
        height: height
    });
    for(var i = 0; i < 8; i++){
        for(var j = 0; j < 8; j++){
            var rect = new Konva.Rect({
              x: i * (width / 8),
              y: j * (width / 8),
              width: width / 8,
              height: height / 8,
              fill: (( (j + (i % 2) ) % 2) != 0 ? '#EEEEEE' : '#c1978e'),
            });
            boardLayer.add(rect);
        }
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
	e.target.offsetX(e.target.x() - pos.x + (width  / 8 / 2));
	e.target.offsetY(e.target.y() - pos.y + (height / 8 / 2));
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

	var msg = {
		'c'  : 'move',
		'id' : piece.id,
		'x'  : boardPos.x,
		'y'  : boardPos.y
	}
    sendMsg(msg);
    //piece.move(boardPos.x, boardPos.y);

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
            + '</span> ' + escapeHtml(message) + '</p>');
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
        console.log("replaying game");
        clearBoard();
        console.log(gameLog);

        // clears all active timeouts
        var id = window.setTimeout(function() {}, 0);
        while (id--) {
            window.clearTimeout(id); // will do nothing if no timeout with id is present
        }

        var startTime = 0;
        var gameStart = false;
        gameLog.forEach(function (logMsg) {
            console.log(logMsg.time);
            console.log(logMsg.msg.c);
            if (logMsg.msg.c == 'gameBegins') {
                startTime = logMsg.time + 3;
                gameStart = true;
                console.log("start time: " + startTime);
                console.log(logMsg);
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
