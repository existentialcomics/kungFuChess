var width  = 320;
var height = 320;

var boardContent = $("#boardContainer");
var chatContent = $('#chatlog');
var input = $('#chat-input');

width = boardContent.width();
height = $("#boardContainer").width();

if (width > 600){
    width=600;
}
if (height > 600){
    height=600;
}

$(window).resize(function(){
    width = boardContent.width();
    height = $("#boardContainer").width();
});

//if (width < height){
    //height = width;
//}
//if (height < width){
    //width = height;
//}

var boardLayer = new Konva.Layer();
var pieceLayer = new Konva.Layer();
var delayLayer = new Konva.Layer();

var pieces = {};
var piecesByImageId = {};

var globalIdCount = 1;

console.log("connecting..." + authId);
var conn = new WebSocket("ws://www1.existentialcomics.com:3000/ws");

var joinGame = function(){
		var ret = {
			'c' : 'join',
            'gameId' : gameId
		};
        gameId = gameId;
        sendMsg(ret);
}

var playerJoinGame = function(){
		var ret = {
			'c' : 'playerjoin',
            'gameId' : gameId,
		};
        gameId = gameId;
        sendMsg(ret);
        $('#join').attr('disabled', 'disabled');
}

var resetGamePieces = function(){
    for(id in pieces){
		pieces[id].image.x(getX(pieces[id].image.x()));
		pieces[id].image.y(getY(pieces[id].image.y()));
    }
	pieceLayer.draw();
};

conn.onopen = function(evt) {
	// finished connecting.
	// maybe query for ready to join
	console.log("connected!");
    pingServer = setInterval(function() {
        console.log("ping");
        heartbeat_msg = {
            "c" : "ping"
        };
        conn.send(JSON.stringify(heartbeat_msg));
    }, 2000); 
	joinGame();
}

conn.onerror = function(e) {
    console.log('Error!');
};

conn.onclose = function(e) {
    console.log('Disconnected!');
};

sendMsg = function(msg) {
    console.log(msg);
    msg.gameId = gameId;
    msg.auth = authId;
    conn.send(JSON.stringify(msg));
}

displayPlayers = function(color) {
    console.log("display players...");
    console.log("white:");
    console.debug(whitePlayer);
    console.log("black");
    console.debug(blackPlayer);
    //if (whitePlayer.screenname !== null){
        //$('#whitePlayer').text(whitePlayer.screenname + " " + whitePlayer.rating_standard);
    //}
    //if (blackPlayer.screenname !== null){
        //$('#blackPlayer').text(blackPlayer.screenname + " " + blackPlayer.rating_standard);
    //}
    if (blackPlayer.screenname !== null && whitePlayer.screenname !== null){
        if ( gameBegan) {
            $('#resign').removeAttr('disabled');
            $('#requestDraw').removeAttr('disabled');
            $('#rematch').attr('disabled', true);
            $('#enter-pool').attr('disabled', true);
        } else {
            console.log('enabling ready to start...');
            $('#readyToStart').removeAttr('disabled'); 
        }
    }
}

displayPlayers();

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

requestDraw = function() {
    var msg = {
        "c" : "requestDraw"
    };
    sendMsg(msg);
}

requestRematch = function() {
    var msg = {
        "c" : "requestRematch"
    };
    sendMsg(msg);
}

conn.onmessage = function(evt) {
    console.log("msg: " + evt.data);

	var msg = JSON.parse(evt.data);

    // move:<piece_id>,<x>,<y>
    // Example: move:123,1,4
    if (msg.c == 'move'){
        pieces[msg.id].move(msg.x, msg.y);
    } else if (msg.c == 'promote'){
		console.log('promoting ' + msg.id);
		pieces[msg.id].image.destroy();
		var newQueen = getQueen(pieces[msg.id].x, pieces[msg.id].y, pieces[msg.id].color);
		newQueen.id = msg.id;
		pieceLayer.add(newQueen.image);
		pieces[msg.id] = newQueen;
		newQueen.image.draggable(pieces[msg.id].image.draggable());
		pieceLayer.draw();
	} else if (msg.c == 'readyToJoin'){
		console.log('readyToJoin');
        $('#join').removeAttr('disabled'); // let the user write another message
    } else if (msg.c == 'joined'){
        console.debug(msg);
		console.log('joined ' + authId + ", ", myColor);
		// TODO mark all color pieces as draggabble
		for(id in pieces){
            console.log(myColor);
			if (pieces[id].color == myColor){
				pieces[id].image.draggable(true);
			}
		}
        console.debug(msg);
		console.log('begin reset');
		resetGamePieces();
		console.log('end reset');
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
            console.log(myColor);
			if (piece.color == myColor){
				pieces[msg.id].image.draggable(true);
			}
			pieceLayer.draw();
		}
    } else if (msg.c == 'kill'){
        console.log('killing ' + msg.id);
        pieces[msg.id].image.destroy();
        if (pieces[msg.id].delayRect){
            pieces[msg.id].delayRect.destroy();
        }
        delete pieces[msg.id];
        pieceLayer.draw();
    } else if (msg.c == 'playerjoined'){
        if (msg.user.color == 'white'){
            console.log("joined white");
            whitePlayer = msg.user;
        } else if (msg.user.color == 'black'){
            console.log("joined black");
            blackPlayer = msg.user;
        } else {
            console.log("joined nocolor");
            console.debug(msg.user.color);
        }
        displayPlayers();
    } else if (msg.c == 'gameBegins'){
        console.log('setting readyToStart timeout');
		for(id in pieces){
            console.log(myColor);
            pieces[id].setDelayTimer(3);
		}
        setTimeout(startGame, 3000)
    } else if (msg.c == 'gameover'){

    } else if (msg.c == 'chat') {
        console.log("chat recieved");
        input.removeAttr('disabled'); // let the user write another message
        var dt = new Date();
        addMessage(
            msg.author,
            msg.message,
            "green",
            dt
        );
    } else if (msg.c == 'newgame') { // both players agreed to rematch
        console.log("new game" + msg.gameId);
        window.location.replace('/game/' + msg.gameId);
    } else if (msg.c == 'playerlost') {
        var dt = new Date();
        endGame();
        addMessage(
            "SYSTEM",
            msg.color + " has lost.",
            "red",
            dt
        );
    } else if (msg.c == 'drawRequested') {
        addMessage(
            "SYSTEM",
            msg.color + " as requested a draw.",
            "red",
            dt
        );
    } else if (msg.c == 'gameDrawn') {
        var dt = new Date();
        endGame();
        addMessage(
            "SYSTEM",
            "The game has drawn.",
            "red",
            dt
        );
    } else if (msg.c == 'resign') {
        var dt = new Date();
        endGame();
        addMessage(
            "SYSTEM",
            msg.color + " has resigned.",
            "red",
            dt
        );
    } else {
        console.log("unknown msg recieved");
        console.debug(msg);
    }
};

var startGame = function(){
    console.log('starting game');
    $('#resign').removeAttr('disabled');
    $('#requestDraw').removeAttr('disabled');
    $('#rematch').attr('disabled', true);
    $('#enter-pool').attr('disabled', true);
}

var endGame = function(){
    console.log('ending');
    $('#resign').attr('disabled', true);
    $('#requestDraw').attr('disabled', true);
    $('#rematch').removeAttr('disabled');
    $('#enter-pool').removeAttr('disabled');
    for(id in pieces){
        console.log(myColor);
        if (pieces[id].color == myColor){
            pieces[id].image.draggable = false;
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

        console.log("x: " + x + ", y: " + y);
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
			// TODO 1000 is speed
            //piece.anim_length = Math.sqrt( Math.pow(Math.abs(this.start_x - this.x), 2) + Math.pow(Math.abs(this.start_y - this.y), 2)) * timer * 100;
            // diagonal pieces move just as fast forward as straight pieces
            var x_dist = Math.abs(this.start_x - this.x);
            var y_dist = Math.abs(this.start_y - this.y);
            var longer_dist = (x_dist > y_dist ? x_dist : y_dist);
            piece.anim_length =  longer_dist * timer * 100;
            piece.anim = new Konva.Animation(function(frame) {
                var new_x = (piece.start_x * width / 8) + ((piece.x - piece.start_x) * (frame.time / piece.anim_length) * width / 8);
                var new_y = (piece.start_y * width / 8) + ((piece.y - piece.start_y) * (frame.time / piece.anim_length) * width / 8);
                piece.image.setX(getX(new_x));
                piece.image.setY(getY(new_y));

                if (frame.time > piece.anim_length){
                    this.stop();
                    piece.image.draggable = true;
                    piece.isMoving = false;

                    piece.setDelayTimer(timer)

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
function addMessage(author, message, color, dt) {
    console.log(author + ", " + message);
    console.debug(chatContent);
    console.debug(dt);
    chatContent.append('<p><span style="color:' + color + '">' + author + '</span> @ ' +
            + (dt.getHours() < 10 ? '0' + dt.getHours() : dt.getHours()) + ':'
            + (dt.getMinutes() < 10 ? '0' + dt.getMinutes() : dt.getMinutes())
            + ': ' + message + '</p>');
    chatContent.scrollTop = chatContent.scrollHeight;
}
