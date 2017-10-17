#!/usr/bin/perl
#
use strict; use warnings;
use Mojolicious::Lite;

get '/' => {
	text => 'I ♥ Mojolicious!'
};

get '/game/(:gameId)' => {

};

post '/game/create' => {

};

get '/login' => {

};

post '/login' => {

};

app->start;
