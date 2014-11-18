use strict;
use warnings;
use Irssi;
our %IRSSI;

my %S;
sub teddy_get_S { \%S }

#my $version_info = 'Irssi v'.Irssi::parse_special('$J')." - Teddy v$VERSION";

sub setup_changed {
    my %old_S = %S;
    %S = (
	host		 => Irssi::settings_get_str( set 'host'),
	port		 => Irssi::settings_get_int( set 'port'),
	cert		 => Irssi::settings_get_str( set 'cert'),
	key		 => Irssi::settings_get_str( set 'key'),
	#docroot	 => Irssi::settings_get_str( set 'docroot'),
	ssl		 => Irssi::settings_get_bool(set 'ssl'),
	password	 => Irssi::settings_get_str( set 'password'),
	stopped		 => ($old_S{stopped} || 0),
	rawlog		 => Irssi::settings_get_bool(set 'rawlog'),

	enable_quit	 => Irssi::settings_get_bool(set 'enable_quit'),

	timestamp_fmt	 => Irssi::settings_get_str('timestamp_format'),
	timestamp_theme	 => $old_S{timestamp_theme},
	timestamp_render => $old_S{timestamp_render},
       );
    lock_keys %S;

    if (length $S{cert} && !-e $S{cert}) {
	logmsg("Certificate file doesn't exist: $S{cert}");
	delete $S{cert};
    }
    if (length $S{key} && !-e $S{key}) {
	logmsg("Key file doesn't exist: $S{key}");
	delete $S{key};
    }
    if (!$S{ssl}) {
	delete @S{'cert', 'key'};
    }

    if ($S{rawlog} && !teddy_rawlog_on()) {
	teddy_rawlog_on() = Irssi::rawlog_create();
    }
    elsif (teddy_rawlog_on() && !$S{rawlog}) {
	teddy_rawlog_on()->destroy;
	teddy_rawlog_on() = undef;
    }

    for (values %{teddy_extensions()}) {
	$_->{setup_changed}->(\%old_S)
	    if exists $_->{setup_changed};
    }

    my @need_restart = qw(host port cert key ssl password); # docroot
    if ((join $;, map { defined $S{$_} ? ($_, $S{$_}) : () } @need_restart)
	    ne (join $;, map { defined $old_S{$_} ? ($_, $old_S{$_}) : () } @need_restart)) {
	start_server() unless $S{stopped};
    }
}

sub init {
    for (values %{teddy_extensions()}) {
	$_->{update_formats}->()
	    if exists $_->{update_formats};
    }

    Irssi::timeout_add_once(10, 'setup_changed', '');
}

sub teddy_setup {
    my $thm_start = '{line_start}{hilight ' . $IRSSI{name} . ':} ';
    Irssi::theme_register([
	setc()		    => $thm_start.'$0',
	thm client_header	    => $IRSSI{name}.' Client List:',
	thm client_line	    => '%#$[-4]0: From: $1 $2 $5 ($3 signals) @$4',
	thm client_footer	    => '',
	thm client_connected    => $thm_start.'Client Connected From: $0',
	thm client_disconnected => $thm_start.'Client From: $0 Closed',
       ]);

    Irssi::settings_add_str( setc, set 'host'	  => 'localhost');
    Irssi::settings_add_int( setc, set 'port'	  => 9001 + $< % 999);
    Irssi::settings_add_bool(setc, set 'ssl'	  => 1);
    Irssi::settings_add_str( setc, set 'cert'	  => '');
    Irssi::settings_add_str( setc, set 'key'	  => '');
    Irssi::settings_add_str( setc, set 'password'     => '');
    Irssi::settings_add_bool(setc, set 'rawlog'	  => 1);

    Irssi::settings_add_bool(setc, set 'enable_quit'  => 0);

    init();
    for (values %{teddy_extensions()}) {
	$_->{init}->()
	    if exists $_->{init};
    }

    Irssi::signal_add_last({
	'setup changed'  => 'setup_changed',
	#'setup reread'   => 'setup_changed',
    });
}

1;
