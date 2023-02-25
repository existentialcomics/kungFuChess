#!/usr/bin/perl
#
use strict;
use warnings;
use Config::Simple;
use Data::Dumper;
use DBI;
use UUID::Tiny ':std';

my $cfg = new Config::Simple('kungFuChess.cnf');

my $dsn = 'dbi:mysql:dbname=' . $cfg->param('database') .';host=' . $cfg->param('dbhost');

my $dbh = DBI->connect(
    $dsn, $cfg->param('dbuser'), $cfg->param('dbpassword'),
    {
        'pg_enable_utf8' => 1,
        'mysql_enable_utf8' => 1,
        'RaiseError' => 1,
        'mysql_auto_reconnect' => 1,
    }
);

my $player1 = shift;
my $player2 = shift;
my $gameId = shift;
my $folder = shift;

my $type = '2way';
my $auth = create_uuid_as_string();
print "auth: $auth\n";
my $pieceSpeed = 0.5;
my $pieceRecharge = 5;

my $play1 = $dbh->selectrow_hashref(
    'SELECT * FROM players where player_id = ? OR screenname = ?',
    { 'Slice' => {} },
    $player1,
    $player1
);
my $play2 = $dbh->selectrow_hashref(
    'SELECT * FROM players where player_id = ? OR screenname = ?',
    { 'Slice' => {} },
    $player2,
    $player2
);

$dbh->do("INSERT IGNORE INTO games (game_id) VALUES (-1)", {});
$dbh->do("UPDATE games SET
    white_player = ?,
    black_player = ?,
    `status` = ?,
    `server_auth_key` = ?,
    `ws_server` = ?,
    `piece_speed` = ?,
    `piece_recharge` = ?
    WHERE game_id = -1", {},
    $play1->{player_id},
    $play2->{player_id},
    'active',
    $auth,
    '127.0.0.1:3001',
    $pieceSpeed,
    $pieceRecharge,
);

my $cmd = sprintf('/usr/bin/perl ./kungFuChessGame%s.pl %s %s %s %s %s >%s 2>%s &',
    $type,
    $gameId,
    $auth,
    $pieceSpeed,
    $pieceRecharge,
    "1:1:1:1",
    '/var/log/kungfuchess/_AI_' . $gameId . '-game.log',
    '/var/log/kungfuchess/_AI_' . $gameId . '-error.log'
);

print "$cmd\n";
system($cmd);

my $cmdAi = sprintf('/usr/bin/perl ./kungFuChessGame%sAi.pl %s %s %s %s %s %s %s %s 1>%s 2>%s &',
    $type,
    '-1',
    $play1->{auth_token},
    $pieceSpeed,
    $pieceRecharge,
    "1:1:1:1",
    3,
    'white',
    'ws://localhost:3001/ws',
    '/var/log/kungfuchess/_AI-game-white-ai.log',
    '/var/log/kungfuchess/_AI-error-white-ai.log'
);
print "$cmdAi\n";
system($cmdAi);

my $cmdAi2 = sprintf('/usr/bin/perl ' . $folder . '/kungFuChessGame%sAi.pl %s %s %s %s %s %s %s %s 1>%s 2>%s &',
    $type,
    '-1',
    $play2->{auth_token},
    $pieceSpeed,
    $pieceRecharge,
    "1:1:1:1",
    3,
    'black',
    'ws://localhost:3001/ws',
    '/var/log/kungfuchess/_AI-game-black-ai.log',
    '/var/log/kungfuchess/_AI-error-black-ai.log'
);
print "$cmdAi2\n";
system($cmdAi2);


my $return = 1;
while ($return) {
    $return = `ps aux | grep $auth | grep -v grep`;
    print $return;
    sleep 5;
}
print "\n";
