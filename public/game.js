var width  = 600;
var height = 600;

var boardLayer = new Konva.Layer();
var pieceLayer = new Konva.Layer();
var delayLayer = new Konva.Layer();

var pieces = {};
var piecesByImageId = {};

var globalIdCount = 1;
var authId;
var myColor = "";

var timer = 1;

console.log("connecting...");
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
            'gameId' : gameId
		};
        gameId = gameId;
        sendMsg(ret);
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
	joinGame();
}

sendMsg = function(msg) {
    msg.gameId = gameId;
    msg.auth = authId;
    conn.send(JSON.stringify(msg));
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
		var ret = {
			'c' : 'join',
            'gameId' : msg.gameId
		};
        gameId = msg.gameId;
        sendMsg(ret);
    } else if (msg.c == 'joined'){
        authId = msg.p_auth;
        myColor = msg.color;
		console.log('joined ' + authId + ", ", myColor);
		// TODO mark all color pieces as draggabble
		for(id in pieces){
			if (pieces[id].color == myColor){
				pieces[id].image.draggable(true);
			}
		}
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
        console.log('adding piece ' + msg.type);
		if (! (msg.id in pieces)){
			pieceLayer.add(piece.image);
			pieces[msg.id] = piece;
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
    } else if (msg.c == 'gameover'){

    }
};

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
        y: y * height / 8,
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
            piece.anim_length = Math.sqrt( Math.pow(Math.abs(this.start_x - this.x), 2) + Math.pow(Math.abs(this.start_y - this.y), 2)) * timer * 100;
            piece.anim = new Konva.Animation(function(frame) {
                var new_x = (piece.start_x * width / 8) + ((piece.x - piece.start_x) * (frame.time / piece.anim_length) * width / 8);
                var new_y = (piece.start_y * width / 8) + ((piece.y - piece.start_y) * (frame.time / piece.anim_length) * width / 8);
                piece.image.setX(getX(new_x));
                piece.image.setY(getY(new_y));
                if (frame.time > piece.anim_length){
                    this.stop();
                    piece.image.draggable = true;
                    piece.isMoving = false;
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
                        duration: timer,
                        height: 0,
                        y: (getY(piece.y * width / 8) + (width / 8)),
                    });
                    piece.delayRect = rect;
                    tween.play();
                    delayLayer.draw();
                    piece.setImagePos(piece.x, piece.y);
                }
            }, pieceLayer);
            piece.anim.start();
        }
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
