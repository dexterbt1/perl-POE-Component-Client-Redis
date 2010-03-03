#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'POE::Component::Client::Redis' );
}

diag( "Testing POE::Component::Client::Redis $POE::Component::Client::Redis::VERSION, Perl $], $^X" );
