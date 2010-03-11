#!/usr/bin/perl -w
use strict;
use warnings;
use POE::Component::Client::Redis;
use POE::Session;

my $redis = POE::Component::Client::Redis->spawn(
    host        => 'localhost',
    port        => 6379,
    alias       => 'redis',
);

POE::Session->create(
    inline_states => {
        _start  => sub {
            my $session = $_[SESSION];
            $_[KERNEL]->alias_set( "$session" );
            $_[KERNEL]->post( 'redis', 'send_command', 'on_redis_response', [ 'SET', 'hello', 'world' ] );
            #$redis->send_command( 'on_redis_response', [ 'SET', 'hello', 'world' ] );
        },
        on_redis_response => sub {
            my ($req, $res) = @_[ARG0, ARG1];
            print Dumper( $req, $res );
        },
    },
);


POE::Kernel->run;


1;

__END__
