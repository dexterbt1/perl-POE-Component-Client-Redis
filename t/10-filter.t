use strict;
use warnings;
use Test::More qw/no_plan/;

BEGIN {
    use_ok 'POE::Filter::Redis';
}

my $CRLF = "\r\n";
my $f;
my $o;

$f = POE::Filter::Redis->new;
ok defined($f);
isa_ok $f, 'POE::Filter::Redis';
can_ok $f, qw/
    get_one_start
    get_one
    get
/;

# single line (+)
# =======================================

$f->get_one_start(["+PONG$CRLF"]);
is_deeply $f->get_one(), [ [ REDIS_CTYPE_ONELINE(), 'PONG' ] ];
is_deeply $f->get_one(), [ ];

# multi chunk single line replies 
$f->get_one_start(["+PONG$CRLF", "+PONG$CRLF"]);
is_deeply $f->get_one(), [ [ REDIS_CTYPE_ONELINE(), 'PONG' ] ];
is_deeply $f->get_one(), [ [ REDIS_CTYPE_ONELINE(), 'PONG' ] ];
is_deeply $f->get_one(), [ ];

$f->get_one_start(["+PONG$CRLF", "+PONG$CRLF"]);
is_deeply $f->get(), [
    [ REDIS_CTYPE_ONELINE(), 'PONG' ],
    [ REDIS_CTYPE_ONELINE(), 'PONG' ],
];
is_deeply $f->get(), [ ];

# incomplete single line replies
$f->get_one_start(["+PON"]);
is_deeply $f->get_one(), [ ];
$f->get_one_start(["G$CRLF"]);
is_deeply $f->get_one(), [ [ REDIS_CTYPE_ONELINE(), 'PONG' ] ];

# error (-)
# =======================================

$f->get_one_start(["-ERR wrong number of arguments ", "for 'exists' command$CRLF"]);
is_deeply $f->get_one(), [ [ REDIS_CTYPE_ERROR(), "ERR wrong number of arguments for 'exists' command" ] ];

$f->get_one_start(["-ERR"]);
is_deeply $f->get_one(), [ ];
$f->get_one_start([" test error$CRLF"]);
is_deeply $f->get_one(), [ [ REDIS_CTYPE_ERROR(), 'ERR test error' ] ];

# bulk ($)
# =======================================

$f->get_one_start(["\$3$CRLF","bar$CRLF"]);
is_deeply $f->get_one, [ [ REDIS_CTYPE_BULK(), 'bar' ] ];

# partial bulk
$f->get_one_start(["\$3"]);
is_deeply $f->get_one, [ ];
$f->get_one_start(["$CRLF"]);
is_deeply $f->get_one, [ ];
$f->get_one_start(["foo$CRLF"]);
is_deeply $f->get_one, [ [ REDIS_CTYPE_BULK(), 'foo' ] ];

# undef
$f->get_one_start(["\$-1$CRLF"]);
is_deeply $f->get_one, [ [ REDIS_CTYPE_BULK(), undef ] ];


# multi-bulk (*)
# =======================================

$f->get_one_start([join($CRLF, '*4', '$3', 'foo', '$3', 'bar', '$5', 'Hello', '$5', 'World')]);
is_deeply $f->get, [ ];
$f->get_one_start([$CRLF]);
is_deeply $f->get, [ [ REDIS_CTYPE_MULTIBULK(), [ 'foo', 'bar', 'Hello', 'World' ] ] ];


$f->get_one_start(['*-1', $CRLF]);
is_deeply $f->get, [ [ REDIS_CTYPE_MULTIBULK(), undef ] ];

$f->get_one_start([join($CRLF,'*3','$-1','$3','bar','$-1'),$CRLF]);
is_deeply $f->get, [ [ REDIS_CTYPE_MULTIBULK(), [ undef, 'bar', undef ] ] ];


# integer (:)
# =======================================

$f->get_one_start([':1234', $CRLF]);
is_deeply $f->get, [ [ REDIS_CTYPE_INTEGER(), 1234 ] ];




__END__
