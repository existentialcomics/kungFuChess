var interval;
var intervalPool;

var games = {};

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

function getPlayers() {
    if (document.getElementById('playersContent')) {
        $.ajax({
            type : 'GET',
            url  : '/activePlayers',
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


$(document).ready(function () {
    console.log("document.ready");
    $("#enter-pool").click(function() {
        console.log('check pool click');
        checkPool();
    });

});

function checkPool() {
    console.log('check pool');
    $("#enter-pool").html('<span class="spinner-border spinner-border-sm" role="status" aria-hidden="true"></span>');
    $.ajax({
        type : 'GET',
        url  : '/ajax/pool',
        dataType : 'html',
        success : function(data){
            var jsonRes = JSON.parse(data);
            console.log(jsonRes);
            if (jsonRes.hasOwnProperty('gameId')) {
                window.location.replace('/game/' + jsonRes.gameId);
            }
            intervalPool = setTimeout(checkPool, 1000)
        }
    });

}

getPlayers();
