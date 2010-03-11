package POE::Component::Client::Redis;

use warnings;
use strict;
use Carp;
use POE::Session;
use POE::Component::Client::Keepalive;
use POE::Driver::SysRW;
use POE::Filter::Redis;

=head1 NAME

POE::Component::Client::Redis - an asynchronous Redis client

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    use POE::Component::Client::Redis;


=cut


=head1 METHODS

=over 4

=item CLASS->spawn( %options )

Creates a new POE session.

%options keys are:

    host                => SCALAR,  # required, Redis server host
    port                => SCALAR,  # required, Redis server port
    alias               => SCALAR,  # optional, the POE alias
    connection_manager  => SCALAR,  # optional, instance of POE::Component::Client::Keepalive

returns the object instance

=cut
sub spawn {
    my $class = shift;
    my $self = bless { }, $class;
    my %options = @_;
    my $host        = delete $options{host}
        or croak "Required param 'host'";
    my $port        = delete $options{port}
        or croak "Required param 'port'";
    my $alias       = delete $options{alias} || "$self";
    my $cm          = delete $options{connection_manager};
    my $sid = POE::Session->create(
        inline_states   => {
            _start              => sub {
                $_[KERNEL]->alias_set( $alias ) == 0
                    or croak "cannot set alias [$alias]";
                if (not $_[HEAP]->{cm}) {
                    $_[HEAP]->{cm} = POE::Component::Client::Keepalive->new;
                }
            },
            _default            => sub {
                my $command = $_[ARG0];
                croak "unsupported event called: ".$command;
            },
            _child              => sub { },
            _stop               => sub { },
        },
        object_states   => [
            $self => {
                'send_command'          => '_send_command',
                'got_connection'        => '_got_connection',
            },
            $self => [qw/
                _got_socket_error
                _got_server_input
                _got_server_flush
            /],
        ],
        heap => {
            alias   => $alias,
            cm      => $cm,
            host    => $host,
            port    => $port,
        },
    );
    $self->{_alias}                 = $alias;
    $self->{_session_id}            = $sid;

    return $self;
}


sub _send_command {
    my $self = $_[OBJECT];
    my $cmd = {
        sender_session  => $_[SENDER],
        sender_event    => $_[ARG0],
        reqs            => [ @_[ARG1..$#_] ],
    };
    # enqueue request
    $_[HEAP]->{cm}->allocate(
        scheme      => 'redis',
        addr        => $_[HEAP]->{host},
        port        => $_[HEAP]->{port},
        context     => $cmd,
        event       => 'got_connection',
    );
}


sub _got_connection {
    my $r = $_[ARG0];
    my $cmd = $r->{'context'};
    $_[HEAP]->{wheels}->{$cmd->{id}} = POE::Wheel::ReadWrite->new(
        Handle       => $r->{'connection'}->[0], # fragile
        Driver       => POE::Driver::SysRW->new(),
        Filter       => POE::Filter::Redis->new(),
        ErrorEvent   => '_got_socket_error',
        InputEvent   => '_got_server_input',
        FlushedEvent => '_got_server_flush',
    );
}


sub _got_socket_error {
}


sub _got_server_input {
}


sub _got_server_flush {
}








=head1 AUTHOR

Dexter Tad-y, C<< <dtady at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-poe-component-client-redis at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=POE-Component-Client-Redis>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc POE::Component::Client::Redis


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=POE-Component-Client-Redis>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/POE-Component-Client-Redis>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/POE-Component-Client-Redis>

=item * Search CPAN

L<http://search.cpan.org/dist/POE-Component-Client-Redis/>

=back


=head1 COPYRIGHT & LICENSE

Copyright 2010 Dexter Tad-y, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of POE::Component::Client::Redis
