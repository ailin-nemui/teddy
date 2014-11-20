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

do './demo_setup'; die $@ if $@;

do "../teddy-nu.pl"; die $@ if $@;

my $t = Test::Mojo->new;
$t->websocket_ok('/teddy');
$t->finish_ok;

$_->finish for @{teddy_all_clients()};
UNLOAD();
Mojo::IOLoop->one_tick for 1..2;
done_testing();
