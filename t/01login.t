# -*- perl -*-
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/mock";
use lib "$FindBin::Bin/lib";
use lib "$FindBin::Bin/../lib";

use Irssi::Test;
use Test::Mojo;
use Test::More;
use List::Util 'shuffle';
use Mojo::JSON 'decode_json';

do './demo_setup'; die $@ if $@;

do "../teddy-nu.pl"; die $@ if $@;

my $t = Test::Mojo->new;

my $secret = substr +(join '', map { chr } shuffle 0x21..0x7e), 0, 32;

$t->websocket_ok('/teddy')
    ->send_ok({json => { challenge => $secret } })
    ->message_ok;

my $data = decode_json($t->message->[1]);
my $pass = teddy_get_S()->{password};

$t->send_ok({json => { login => hmac_sha256_base64(
    $pass, $data->{challenge} . $secret) } })
    ->message_ok
    ->json_message_is('/login' => 1)
    ->json_message_is('/version/teddy' => our $VERSION)
    ->finish_ok;

$_->finish for @{teddy_all_clients()};
UNLOAD();
Mojo::IOLoop->one_tick for 1..2;
done_testing();
