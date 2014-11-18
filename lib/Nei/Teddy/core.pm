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
	if (hmac_sha256_base64(teddy_get_S()->{password}, $client->{s2}.$client->{s1}) eq $msg) {
	    $client->{authenticated} = 1;
	    weaken $client;
	    $client->{ping} =
		Irssi::timeout_add(1000*10, sub {
				       $client->send({json => {}})
				   }, '');
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
