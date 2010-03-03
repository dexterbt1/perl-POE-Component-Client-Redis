package POE::Filter::Redis;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw/
    REDIS_CTYPE_ONELINE    
    REDIS_CTYPE_ERROR
    REDIS_CTYPE_BULK
/;


sub REDIS_CTYPE_ONELINE     { '+' }
sub REDIS_CTYPE_ERROR       { '-' }
sub REDIS_CTYPE_BULK        { '$' }



our $CRLF = "\r\n";

# ----------------------------------

sub new {
    my ($class) = @_;
    my $buffer  = [
        '', # 0: BUFFER
    ];
    my $self = bless $buffer, $class;
    return $self;
}


sub get_one_start {
    my ($self, $stream) = @_;
    if ((defined $stream) and (ref($stream) eq 'ARRAY')) {
        $self->[0] .= join('',@$stream);
    }
    return;
}


sub get_one {
    my ($self) = @_;
    return $self->_get_redis_pdus(1);
}


sub get {
    my ($self, $stream) = @_;
    if ((defined $stream) and (ref($stream) eq 'ARRAY')) {
        $self->[0] .= join('',@$stream);
    }
    return $self->_get_redis_pdus();
}


# ===========================================


sub _get_redis_pdus {
    my ($self, $wanted_count) = @_;
    my @out                 = ();
    my $i                   = 0;
    my $incomplete_buffer   = 0;

    while (not $incomplete_buffer) {
        my $ctype = 0;
        if (length $self->[0] > 0) {
            $ctype = substr($self->[0], 0, 1);
        }

        SWITCH: {

            # ONELINEs
            ($ctype eq '+') and do {
                $incomplete_buffer = 1; # assume it's incomplete unless otherwise
                if ($self->[0] =~ /^\+(.+?)$CRLF/) {
                    $self->[0] =~ s/^\+(.+?)$CRLF//;
                    push @out, [
                        REDIS_CTYPE_ONELINE(),
                        $1,                
                    ];       
                    $i++;
                    $incomplete_buffer = 0;
                    last SWITCH;
                }
            };

            # ERRORs
            ($ctype eq '-') and do {
                $incomplete_buffer = 1;
                if ($self->[0] =~ /^\-(.+?)$CRLF/) {
                    $self->[0] =~ s/^\-(.+?)$CRLF//;
                    push @out, [
                        REDIS_CTYPE_ERROR(),
                        $1,                
                    ];       
                    $i++;
                    $incomplete_buffer = 0;
                    last SWITCH;
                }
            };

            # BULK
            ($ctype eq '$') and do {
                $incomplete_buffer = 1;
                if ($self->[0] =~ /^\$(\-{0,1}\d+?)$CRLF/) {
                    my $bytes = int($1);
                    if ($bytes < 0) {
                        $self->[0] =~ s/^\$(\-{0,1}\d+?)$CRLF//;
                        push @out, [
                            REDIS_CTYPE_BULK(),
                            undef,
                        ];       
                        $i++;
                        $incomplete_buffer = 0;
                    }
                    # bulk data is not undefined
                    if ($self->[0] =~ /^\$(\d+?)$CRLF(.{$bytes})$CRLF/) {
                        $self->[0] =~ s/^\$(\d+?)$CRLF(.{$bytes})$CRLF//;
                        push @out, [
                            REDIS_CTYPE_BULK(),
                            $2,
                        ];       
                        $i++;
                        $incomplete_buffer = 0;
                        last SWITCH;
                    }
                }
            };

            $incomplete_buffer = 1;
        } 

        if ( defined($wanted_count) and ($i>=$wanted_count) ) {
            last; # break from the loop
        }

    }
    return \@out;
}



1;

__END__

=head1 NAME

POE::Filter::Redis - implements the Redis client protocol

=head1 METHODS

=over

=item CLASS->new()

=item $obj->get_one_start( \@stream_chunks )

=item $obj->get_one()

=item $obj->get()

=back

=head1 SEE ALSO
 
L<POE::Filter> - documents the POE::Filter API and standalone use

L<http://code.google.com/p/redis/wiki/ProtocolSpecification>

=head1 AUTHOR
 
Dexter Tad-y, <dtady@cpan.org>
 
=head1 COPYRIGHT AND LICENSE
 
Copyright (C) 2010 by Dexter Tad-y
 
This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.
 
 
=cut
