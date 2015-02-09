use strict;
use warnings;

sub cmd_ipw {
    my ($data, $server, $witem) = @_;
    $data =~ s/\s+$//;
    unless (length $data) {
	$data = 'list';
    }
    Irssi::command_runsub('ipw', $data, $server, $witem);
}

sub cmd_ipw_rawlog {
    my ($data, $server, $witem) = @_;
    $data =~ s/\s+$//;
    Irssi::command_runsub('ipw rawlog', $data, $server, $witem);
}

sub cmd_ipw_rawlog_save {
    my ($data) = @_;
    return unless teddy_rawlog_on();
    $data =~ s/\s+$//;
    teddy_rawlog_on()->save($data);
}

sub cmd_ipw_rawlog_open {
    my ($data) = @_;
    return unless teddy_rawlog_on();
    $data =~ s/\s+$//;
    teddy_rawlog_on()->open($data);
}

sub cmd_ipw_rawlog_close {
    return unless teddy_rawlog_on();
    teddy_rawlog_on()->close;
}

sub cmd_ipw_internal_windowinput {
    for my $cl (@{teddy_all_clients()}) {
	next unless $cl;
	if ($cl->{sent_own_command}) {
	    Irssi::signal_emit('send command', @{ delete $cl->{windowinput} })
		    if $cl->{windowinput};
	}
    }
}

sub cmd_ipw_list {
    my ($data, $server, $witem) = @_;
    $data =~ s/\s+$//;
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, thm 'client_header');
    my $i = 1;
    for my $cl (@{teddy_all_clients()}) {
	next unless $cl;
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, thm 'client_line', $i++, $cl->tx->remote_address,
			   $cl->{authenticated} ? '(authenticated)' : $cl->{s2} ? '(challenged)' : '(?)',
			   (scalar keys %{$cl->{signal}||+{}}), scalar localtime $cl->{connect_time},
			   $cl->{sent_own_command} ? '*' : ' ', $cl->{rawlog_id} // 0);
    }
    for my $wcl (@{teddy_ws_client_disconnected_waiting()}) {
	next unless $wcl;
	Irssi::printformat(MSGLEVEL_CLIENTCRAP, thm 'client_line', $i++, $wcl->[0],
			   '(disconnected)', 0, scalar localtime $wcl->[2],
			   $wcl->[1], 0);
    }
    Irssi::printformat(MSGLEVEL_CLIENTCRAP, thm 'client_footer');
}

sub cmd_ipw_disconnect {
    my ($data, $server, $witem) = @_;
    $data =~ s/\s+$//;
    my $i = 1;
    for my $cl (@{teddy_all_clients()}) {
	next unless $cl;
	if ($data eq $i || ($data eq '' && $cl->{sent_own_command})) {
	    $cl->finish;
	    return;
	}
    }
    logmsg('Client not found: ' . $data);
}

sub cmd_ipw_stop {
    my ($data, $server, $witem) = @_;
    teddy_server_cmd_stop();
}

sub cmd_ipw_start {
    my ($data, $server, $witem) = @_;

    start_server() if delete teddy_get_S()->{stopped};
}

sub teddy_commands_init {
    Irssi::command_bind({
	'ipw'		   => 'cmd_ipw',
	'ipw list'	   => 'cmd_ipw_list',
	'ipw disconnect'   => 'cmd_ipw_disconnect',
	'ipw stop'	   => 'cmd_ipw_stop',
	'ipw start'	   => 'cmd_ipw_start',
	'ipw proxyinput'   => 'cmd_ipw_internal_windowinput',
	'ipw rawlog'       => 'cmd_ipw_rawlog',
	'ipw rawlog save'  => 'cmd_ipw_rawlog_save',
	'ipw rawlog open'  => 'cmd_ipw_rawlog_open',
	'ipw rawlog close' => 'cmd_ipw_rawlog_close',
    });
    return;
}

1;
