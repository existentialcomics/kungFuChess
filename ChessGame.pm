package ChessGame;
use strict;
use warnings;
use Time::HiRes;
use JSON::XS;
use Data::Dumper;

sub new {
	my $class = shift;

	my $self = {};
	bless( $self, $class );

	if ($self->_init(@_)){
		return $self;
	} else {
		return undef;
	}
}

sub _init {
	my $self = shift;
    my ($id, $auth) = @_;
	$self->{id} = $id;

    $self->{playersByAuth} = {};
    $self->{playersConn}   = {};
    $self->{readyToPlay}   = 0;
    $self->{auth}          = $auth;
    $self->{serverConn}    = 0;

	return 1;
}

sub setServerConnection {
    my $self = shift;
    my $conn= shift;

    $self->{serverConn} = $conn;
}

sub addConnection {
    my $self = shift;
    my ($id, $conn) = @_;

    $self->{playersConn}->{$id} = $conn;
}

# returns which color the player is authed to move
sub authMove {
    my $self = shift;
    my $msg = shift;

    return 0 if (! defined($msg->{auth}));
    return 0 if (! defined($self->{playersByAuth}->{$msg->{auth}}));
    return $self->{playersByAuth}->{$msg->{auth}}->{color};
}

sub serverBroadcast {
    my $self = shift;
    my $msg = shift;
	print "server broadcast for game: $self->{id}\n";
    print Dumper($msg);
	$self->{serverConn}->send(encode_json $msg);
}

sub playerBroadcast {
    my $self = shift;
    my $msg = shift;

	print "player broadcast game $self->{id}\n";
	delete $msg->{auth};

	foreach my $player (values %{ $self->{playersConn}}){
		print "broadcasting to player $msg->{c}\n";
        print Dumper($player);
		$player->send(encode_json $msg);
	}

}

sub addPlayer {
    my $self = shift;
    my ($user, $color) = @_;

    $user->{color} = (defined($color) ? $color : 'none');

    $self->{playersByAuth}->{$user->{auth}} = $user;
}

1;
