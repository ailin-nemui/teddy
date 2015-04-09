use strict;
use warnings;

sub gb_find_window {
    my ($data, $needserver) = @_;
    my ($foundwin, $serobj, $itobj);

    if ($data =~ /^0x(-?\d+)$/) {
	my $id = $1;
    LOOP: {
	    for my $ser (Irssi::servers) {
		if ($ser->{_irssi} == $id) {
		    $serobj = $ser;
		    $foundwin = $serobj->window_find_closest('', Irssi::level2bits('ALL'));
		    last LOOP;
		}
	    }
	    for my $win (Irssi::windows) {
		if ($win->{_irssi} == $id) {
		    $foundwin = $win;
		    if ($needserver
			    && (my $win = Irssi::window_find_closest('', Irssi::level2bits('ALL')))) {
			$serobj = $win->{active_server};
		    }
		    last LOOP;
		}
		for my $it ($win->items) {
		    if (_iid_or_self($it) == $id) {
			$foundwin = $win;
			$serobj = $it->{server};
			$itobj = $it;
			last LOOP;
		    }
		}
	    }
	}
    }
    else {
	my ($chatnet, $server, $item) = split /\./, $data, 3;

	if ($chatnet eq 'empty') {
	    $foundwin = Irssi::window_find_refnum($server);
	    if ($needserver
		    && (my $win = Irssi::window_find_closest('', Irssi::level2bits('ALL')))) {
		$serobj = $win->{active_server};
	    }
	}
	elsif ($serobj = Irssi::server_find_tag($server)) {
	    if (length $item) {
		if ($itobj = $serobj->window_item_find($item)) {
		    $foundwin = $itobj->window;
		}
	    }
	    else {
		$foundwin = $serobj->window_find_closest('', Irssi::level2bits('ALL'));
	    }
	}
    }

    ($foundwin, $serobj, $itobj)
}

sub gb_input_stop_quit {
    Irssi::signal_stop();
    Irssi::command('ipw disconnect');
}

sub handle_gb_input {
    my ($client, $msg) = @_;
    if ($msg->{buffer} eq 'core.weechat') {
	local $client->{gb_sent_own_command} = 1;
	my $data = $msg->{data};
	if ($data =~ s,^/buffer\s,,) {
	    my ($win, $serobj, $itobj) = gb_find_window($data);
	    my $awin = Irssi::active_win;
	    unless ($serobj) {
		$win->set_active if $win && $win->{_irssi} != $awin->{_irssi};
	    }
	    if ($serobj && $itobj) {
		my $win = $itobj->window;
		$itobj->set_active if $itobj->{_irssi} != $win->{active}{_irssi};
		$win->set_active if $win->{_irssi} != $awin->{_irssi};
	    }
	    elsif ($serobj) {
		if ($win) {
		    $win->set_active if $win->{_irssi} != $awin->{_irssi};
		    $win->change_server($serobj)
			if $win->{active_server}{_irssi} != $serobj->{_irssi};
		}
	    }
	    return;
	}
	elsif ($data =~ s,^/clearhotlist\s,,) {
	    return unless teddy_get_S()->{dehilight};
	    my ($clearwin, $serobj, $itobj) = gb_find_window($data);
	    Irssi::signal_emit('window dehilight', $clearwin)
		    if $clearwin;
	    return;
	}
	elsif ($data eq '/quit') {
	    $client->finish;
	    return;
	}
	logmsg('unknown command: input '.$msg->{buffer}.' '.$msg->{data});
	return;
    }
    my ($win, $serobj, $itobj) = gb_find_window($msg->{buffer}, 1);
    $win ||= Irssi::active_win;
    local $client->{sent_own_command} = 1;
    local $client->{windowinput} = [ $msg->{data}, $serobj, $itobj ];
    my $stop_quit = !teddy_get_S()->{enable_quit};
    if ($stop_quit) {
	Irssi::signal_add_first('command quit', 'gb_input_stop_quit');
    }
    $win->command('ipw proxyinput');
    if ($stop_quit) {
	Irssi::signal_remove('command quit', 'gb_input_stop_quit');
    }
    return;
}

1;
