var interval;

var games = {};

function getGames() {
    if (document.getElementById('gamesContent')) {
        $.ajax({
            type : 'GET',
            url  : '/games',
            dataType : 'html',
            success : function(data){
                $('#gamesContent').html(data);
                console.log('success');
                interval = setTimeout(getGames, 1000)
            }
        });
    } else {
        interval = setTimeout(getGames, 1000)
    }
}

console.log('getGames');

getGames();
