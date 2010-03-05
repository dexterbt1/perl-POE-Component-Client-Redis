package POE::Filter::Redis;
use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw/
    REDIS_CTYPE_ONELINE    
    REDIS_CTYPE_ERROR
    REDIS_CTYPE_INTEGER   
    REDIS_CTYPE_BULK
    REDIS_CTYPE_MULTIBULK
/;


sub REDIS_CTYPE_ONELINE     { '+' }
sub REDIS_CTYPE_ERROR       { '-' }
sub REDIS_CTYPE_INTEGER     { ':' }
sub REDIS_CTYPE_BULK        { '$' }
sub REDIS_CTYPE_MULTIBULK   { '*' }



our $CRLF = "\r\n";

# ----------------------------------

sub new {
    my ($class) = @_;
    my $buffer  = [
        '',         # 0: string;    BUFFER
        0,          # 1: boolean;   partial multi-bulk mode
        [ ],        # 2: arrayref;  multi-bulk queue
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
            $incomplete_buffer = 1;

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

            # INTEGER
            ($ctype eq ':') and do {
                $incomplete_buffer = 1; # assume it's incomplete unless otherwise
                if ($self->[0] =~ /^:(\d+?)$CRLF/) {
                    $self->[0] =~ s/^:(\d+?)$CRLF//;
                    push @out, [
                        REDIS_CTYPE_INTEGER(),
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
                    my $bulk_value = undef;
                    if ($bytes < 0) {
                        $self->[0] =~ s/^\$(\-{0,1}\d+?)$CRLF//;
                        if ($self->[1] > 0) {
                            # this is part of the multi bulk operation
                            $self->[1]--; 
                            push @{$self->[2]}, undef;
                            $incomplete_buffer = 0;
                        }
                        else {
                            push @out, [
                                REDIS_CTYPE_BULK(),
                                $bulk_value,
                            ];       
                            $i++;
                            $incomplete_buffer = 0;
                            last SWITCH;
                        }
                    }
                    # bulk data is not undefined
                    # TODO: this could later be optimized to use less memory thru partial parsing
                    if ($self->[0] =~ /^\$(\d+?)$CRLF(.{$bytes})$CRLF/) {
                        $self->[0] =~ s/^\$(\d+?)$CRLF(.{$bytes})$CRLF//;
                        $bulk_value = $2;
                        if ($self->[1] > 0) {
                            # this is part of the multi bulk operation
                            $self->[1]--;
                            push @{$self->[2]}, $bulk_value;
                            $incomplete_buffer = 0;
                        }
                        else {
                            push @out, [
                                REDIS_CTYPE_BULK(),
                                $bulk_value,
                            ];
                            $i++;
                            $incomplete_buffer = 0;
                            last SWITCH;
                        }
                    }
                }
            };

            # MULTI-BULK
            ($ctype eq '*') and do {
                $incomplete_buffer = 1;
                if ($self->[0] =~ /^\*(\-{0,1}\d+?)$CRLF/) {
                    $self->[0] =~ s/^\*(\-{0,1}\d+?)$CRLF//;
                    $self->[1] = int($1);
                    $incomplete_buffer = 0;
                    if ($self->[1] <= 0) {
                        $self->[1] = 0;
                        push @out, [
                            REDIS_CTYPE_MULTIBULK(),
                            undef,
                        ];
                        $i++;
                    }
                }
                last SWITCH;
            };

            # flush multi-bulk 
            if ( ($self->[1] == 0) and (scalar @{$self->[2]} > 0) ) {
                push @out, [
                    REDIS_CTYPE_MULTIBULK(),
                    $self->[2],
                ];
                $self->[2] = [ ];
                $i++;
                $incomplete_buffer = 0;
                last SWITCH;
            }

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
