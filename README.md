# kungFuChess

# sass
sass version: 1.38.0, install from npm
sass command to compile all belt css:

sass scss/basic.scss public/css/basic.css && sass scss/green.scss public/css/green.css && sass scss/yellow.scss public/css/yellow.css && sass scss/orange.scss public/css/orange.css && sass scss/red.scss public/css/red.css && sass scss/brown.scss public/css/brown.css && sass scss/black.scss public/css/black.css && sass scss/doubleblack.scss public/css/doubleblack.css && sass scss/tripleblack.scss public/css/tripleblack.css;


# how to run on dev:
To server web pages:
morbo KungFuWeb.pl -l "http://localhost:3000" -w templates/ -w KungFuChess/
To run the games websockets (on a seperate port so it doesn't block itself):
morbo KungFuWeb.pl -l "http://localhost:3001" -w templates/ -w KungFuChess/

Morbo will reload if itself if you change any files.

# how to install:
You need all perl packages in cpan-required.sh
Possible you can run it as a shell script to install them.
In general it's better to install from yum or apt, if possible.

Load the schema.sql into a mysql server. You *might* need to do some inserts for users for AI or anonymous users to work.
Fill out the kungFuChess.cnf will your credentials, by looking at kungFuChess.cnf.example.

The server will be available at http://localhost:3000/
