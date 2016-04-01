use strict;
use warnings;
our %core;
our $VERSION;

## On-login info

my %core_info = (
    version => sub {
	+{ teddy => $VERSION, irssi => Irssi::parse_special('$J') }
    },
    extensions => sub {
	[sort map { lc } keys %{teddy_extensions()}],
    },
   );

sub core_add_client_ping {
    my ($client, $time, $include_time) = @_;
    $include_time = !!$include_time;
    weaken $client;
    my $ping_sub = sub {
	$client->send({json => $include_time ?
			   [+time]: +{}})
	    if $client;
	logmsg("client lost")
	    unless $client;
    };
    $ping_sub->() if core_remove_client_ping($client);
    $client->{ping} = Irssi::timeout_add(1000*$time, $ping_sub, '');
    return;
}
sub core_remove_client_ping {
    my ($client) = @_;
    if (defined $client->{ping}) {
	Irssi::timeout_remove(delete $client->{ping});
	return 1;
    }
    return;
}

my %commands = (
    challenge => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	return unless length $msg;
	$client->{s1} = $msg;
	$client->{s2} = substr +(join '', map { chr } shuffle 0x21..0x7e), 0, 32;
    },
    login => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	return unless length $msg;
	return unless exists $client->{s2};
	if (hmac_sha256_base64(teddy_get_S()->{password}, $client->{s2}.$client->{s1}) eq $msg) {
	    $client->{authenticated} = 1;
	    core_add_client_ping($client, 10);
	    return \1;
	}
	delete @{$client}{'s1','s2'};
	return;
    },
    eval => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	local $@;
	eval $msg;
    },
    bind => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	return unless ref $msg && $msg =~ /HASH/;
	add_signal_binds($client, $msg);
    },
    'send keepalive' => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	return unless ref $msg && $msg =~ /HASH/;
	if (exists $msg->{interval}) {
	    my $interval = $msg->{interval};
	    $interval = 10 unless looks_like_number($interval);
	    $interval = 10 if $interval < 10;
	    $interval = 300 if $interval > 300;
	    unless ($msg->{none}) {
		core_remove_client_ping($client);
	    }
	    else {
		core_add_client_ping($client, $interval, $msg->{time});
	    }
	    $client->inactivity_timeout(int( $interval * 3 / 2 ));
	}
	return;
    },
    ### add in extension specific commands:
    map { exists $_->{main_commands} ? %{$_->{main_commands}->()} : () }
	values %{teddy_extensions()},
   );

sub teddy_core_init {
    $core{commands} = \%commands;
    $core{info} = \%core_info;
    return;
}

1;
