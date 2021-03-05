use strict;
use warnings;
our $VERSION = '0.94';
our %IRSSI = (
    contact     => 'Nei @ anti@conference.jabber.teamidiot.de',
    url         => "http://anti.teamidiot.de/",
    name	=> 'teddy',
    description => 'Proxy module that listens on a WebSocket',
   );
our %core;

use Irssi;
use Irssi::TextUI;

use File::Basename 'dirname';
use File::Spec;
use Cwd 'abs_path';
use constant ScriptFile => __FILE__;

use lib File::Spec->catdir(dirname(abs_path(+ScriptFile)), 'lib');

use IrssiX::include;
use Nei::Mojo::Reactor::Irssi4;
use Mojolicious::Lite;
use Mojo::Server::Daemon;

use Encode;
use Scalar::Util qw(weaken looks_like_number);
use Hash::Util 'lock_keys';
use List::Util 'shuffle';
use POSIX 'strftime';
use Digest::SHA 'hmac_sha256_base64';
use Storable 'dclone';

use again 'Nei::Mojolicious::ControllerWithRawlogSend';

# based on irssi_proxy_websocket by Timothy J Fontaine

my @all_clients;
sub teddy_all_clients { \@all_clients }

include 'Nei::Teddy::utils';
include 'Nei::Teddy::setup';
include 'Nei::Teddy::extension_system';
include 'Nei::Teddy::rawlog';
include 'Nei::Teddy::server';

#### Extensions specifics added

include 'Nei::Teddy::Nu';
include 'Nei::Teddy::Gb';

### End extension specifics

include 'Nei::Teddy::signals';
include 'Nei::Teddy::core';
include 'Nei::Teddy::commands';

teddy_setup();
teddy_core_init();
teddy_commands_init();

{ package Irssi::Nick }

sub UNLOAD {
    for (teddy_all_clients()) {
	$_->finish;
	ws_client_disconnect($_);
    }
    @{teddy_all_clients()} = ();
    teddy_server_stop();
    teddy_rawlog_stop();
    return;
}
