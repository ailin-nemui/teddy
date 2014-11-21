use strict;
use warnings;

sub gb_line_add_started {
    my ($client, $signame, $textdest) = @_;
    $client->{gb_line_add_started}{ $textdest->{window}{_irssi} }
	= ($textdest->{window}->view->{buffer}{cur_line}||+{})->{_irssi};
    return;
}

sub gb_line_added {
    my ($client, $signame, $win) = @_;
    my $winid = $win->{_irssi};
    my $view = $win->view;
    my $line = $view->{buffer}{cur_line};
    my $previd = delete $client->{gb_line_add_started}{ $winid } || 0;
    return unless $line;

    my @lines;
    for (; $line && $line->{_irssi} != $previd; $line = $line->prev) {
	unshift @lines, wee_line_collect($line);
    }
    gb_check_line_removals_before_add($client, $view->{_irssi}, \@lines);
    $client->{gb_earliest_line_time}{$winid} ||= time if @lines;
    $client->send({ json => {
	id => 'gb._buffer_line_added',
	'gb.hdata' => [map {
	    $client->{gb_earliest_line_time}{$winid} = $_->{time}
		if $_->{time} && $_->{time} < $client->{gb_earliest_line_time}{$winid};
	    wee_line_format($winid, $_)
	} @lines],
    } });
    return;
}

# $client <= {
#   send_line_delayed_rmaa => {
#     timer => $tag,
#     box   => [
#       { type => 'add_after', data => [...] },
#       { type => 'rm', <viewid> => [...], ... },
#       ...
#     ],
#   }

sub gb_send_line_delayed_rmaa {
    my ($client) = @_;
    my $rmaa = delete $client->{gb_send_line_delayed_rmaa} or return;
    my $tid = delete $rmaa->{timer};
    my $box = delete $rmaa->{box} or return;
    my $vw;
    ipw_rawlog_record($client, [_ => 'rmaa begin', $tid]) if @$box > 1;
    for my $ev (@$box) {
	my $type = delete $ev->{type};
	if ('rm' eq $type) {
	    $vw ||= +{ map { ($_->view->{_irssi} => $_->{_irssi}) } Irssi::windows }; # expensive
	    gb_send_line_removals($client, $ev, $vw);
	}
	elsif ('add_after' eq $type) {
	    gb_send_line_after_adds($client, delete $ev->{data});
	}
    }
    ipw_rawlog_record($client, [_ => 'rmaa end', $tid]) if @$box > 1;
    return;
}

sub gb_send_line_after_adds {
    my ($client, $adds) = @_;
    return unless $adds;
    for my $l (@$adds) {
	$client->send({ json => {
	    id => 'gb._buffer_line_added_after',
	    'gb.hdata' => [map {
		$client->{gb_earliest_line_time}{ $l->{winid} } = $_->{time}
		    if $_->{time} && $_->{time} < $client->{gb_earliest_line_time}{ $l->{winid} };
		wee_line_format($l->{winid}, $_)
	    } @{$l->{lines}}],
	    prevline => $l->{previd},
	} })
    };
    return;
}

sub gb_line_after_added {
    my ($client, $signame, $win, $line, $prev) = @_;
    my $winid = $win->{_irssi};
    my $viewid = $win->view->{_irssi};
    my $previd = $prev->{_irssi} || 0;
    return unless $line;

    my $maxtime = 2*time;
    return unless exists $client->{gb_earliest_line_time}{$winid};
    return if $prev && $prev->{info}{time} && $prev->{info}{time} < $maxtime
	&& $client->{gb_earliest_line_time}{$winid} > $prev->{info}{time};
    return if $line->{info}{time} && $line->{info}{time} < $maxtime
	&& $client->{gb_earliest_line_time}{$winid} > $line->{info}{time};

    my @lines;
    for (; $line && $line->{_irssi} != $previd; $line = $line->prev) {
	unshift @lines, wee_line_collect($line);
    }

    #ipw_rawlog_record($client, [_ => 'line after added', $winid, $viewid, [map { $_->{ref} } @lines], ($prev||{})->{_irssi}]);
    my $rmaa = $client->{gb_send_line_delayed_rmaa} ||= +{};
    my $box = $rmaa->{box} ||= [];
    push @$box, +{ type => 'add_after', data => [] }
	unless @$box && 'add_after' eq $box->[-1]{type};
    my $data = $box->[-1]{data};
    my $last = @$data ? $data->[-1] : undef;
    # see if this is a continuation, then optimise
    if ($last && $last->{winid} == $winid
	    && $last->{lines}[-1]{ref} == ($prev ? $prev->{_irssi} : 0)) {
	push @{$last->{lines}}, @lines;
    }
    else {
	push @$data, +{
	    lines => \@lines,
	    winid => $winid,
	    viewid => $viewid,
	    previd => ($prev||{})->{_irssi},
	};
    }
    Irssi::timeout_remove(delete $rmaa->{timer})
	    if exists $rmaa->{timer};
    weaken $client;

    $rmaa->{timer} = Irssi::timeout_add_once(
	100, sub {
	    return unless $client;
	    return unless $client->{authenticated};
	    gb_send_line_delayed_rmaa($client)
	}, '');
    return;
}

sub gb_send_line_removals {
    my ($client, $rms, $vw) = @_;
    return unless $rms;
    $client->send({ json => {
	id => 'gb._buffer_line_removed',
	lines => +{ map { exists $vw->{$_} ? ($vw->{$_} => delete $rms->{$_}) : () } keys %$rms },
    } });
    return;
}

sub gb_check_line_removals_before_add {
    my ($client, $viewid, $lines) = @_;
    my $rmaa = $client->{gb_send_line_delayed_rmaa} or return;
    my $box = $rmaa->{box} or return;
    my %lines;
    @lines{ (map { $_->{ref} } @$lines) } = ();
    my @matches;
    for my $ev (@$box) {
	next unless 'rm' eq $ev->{type};
	my $rms = $ev->{$viewid} or next;
	push @matches, grep { exists $lines{$_} } @$rms;
	if (@matches) {
	    Irssi::timeout_remove(delete $rmaa->{timer})
		    if exists $rmaa->{timer};
	    ipw_rawlog_record($client, [_ => 'sending line removals', $viewid, \@matches]);
	    return gb_send_line_delayed_rmaa($client);
	}
    }
}

sub gb_line_removed {
    my ($client, $signame, $view, $line, $prevline) = @_;
    return unless $view;
    return unless $line;
    # searching the window is expensive

    #ipw_rawlog_record($client, [_ => 'line removed', $view->{_irssi}, $line->{_irssi}, $line->get_text(0)]);
    my $rmaa = $client->{gb_send_line_delayed_rmaa} ||= +{};
    my $box = $rmaa->{box} ||= [];
    push @$box, +{ type => 'rm' }
	unless @$box && 'rm' eq $box->[-1]{type};
    push @{$box->[-1]{$view->{_irssi}}}, $line->{_irssi};

    Irssi::timeout_remove(delete $rmaa->{timer})
	    if exists $rmaa->{timer};
    weaken $client;

    if ($view->{buffer}{cur_line}
	    && $line->{_irssi} == $view->{buffer}{cur_line}{_irssi}) {
	# hiding the last printed line
	return gb_send_line_delayed_rmaa($client);
    }

    $rmaa->{timer} = Irssi::timeout_add_once(
	500, sub {
	    return unless $client;
	    return unless $client->{authenticated};
	    gb_send_line_delayed_rmaa($client)
	}, '');
    return;
}

sub gb_signal_handler {
    my ($client, $signame, @args) = @_;
    return;
}

sub gb_buffer_opened {
    my ($client, $data) = @_;
    $client->send({ json => {
	id => 'gb._buffer_opened',
	'gb.hdata' => [$data],
    } });
    return;
}

sub gb_buffer_closed {
    my ($client, $ref) = @_;
    delete $client->{gb_nicklists}{$ref->{_irssi}};
    $client->send({ json => {
	id => 'gb._buffer_closing',
	'gb.hdata' => [+{pointers=>[$ref->{_irssi}]}],
    } });
    return;
}

sub gb_signal_win_created {
    my ($client, $signame, $win) = @_;
    $client->{gb_earliest_line_time}{$win->{_irssi}} = time if $win;
    return gb_buffer_opened($client, wee_gui_buffers_empty($win));
}

sub gb_signal_win_destroyed {
    my ($client, $signame, $win) = @_;
    delete $client->{gb_earliest_line_time}{$win->{_irssi}};
    return gb_buffer_closed($client, $win);
}

sub gb_signal_server_connected {
    my ($client, $signame, $server) = @_;
    return gb_buffer_opened($client, wee_gui_buffers_server($server));
}

sub gb_signal_server_disconnected {
    my ($client, $signame, $server) = @_;
    return gb_buffer_closed($client, $server);
}

sub gb_signal_item_new {
    my ($client, $signame, $win, $item) = @_;
    gb_buffer_opened($client, wee_gui_buffers_item($item));
    if (@{[$win->items]} == 1) {
	gb_signal_win_destroyed(@_);
    }
    return;
}

sub gb_signal_item_remove {
    my ($client, $signame, $win, $item) = @_;
    if (@{[$win->items]} == 0) {
	gb_signal_win_created(@_);
    }
    return gb_buffer_closed($client, $item);
}

sub gb_send_item_changed {
    my ($client, $id, $ref) = @_;
    delete $client->{gb_item_change}{$ref};
    $client->send({ json => {
	id => 'gb._buffer_item_active',
	item => $id,
    } });
    return;
}

sub gb_signal_item_changed {
    my ($client, $signame, $win, $item) = @_;
    return if $client->{gb_sent_own_command};
    my $id = ($item||$win)->{_irssi};
    my $ref = $win->{_irssi};
    Irssi::timeout_remove(delete $client->{gb_item_change}{$ref})
	    if $client->{gb_item_change}{$ref};
    weaken $client;
    $client->{gb_item_change}{$ref}
	= Irssi::timeout_add_once(
	    10, sub {
		return unless $client;
		return unless $client->{authenticated};
		gb_send_item_changed($client, $id, $ref);
	    }, '');
    return;
}

sub gb_signal_window_server_changed {
    my ($client, $signame, $win, $server) = @_;
    my $zwin = $server?$server->window_find_closest('', Irssi::level2bits('ALL')):$win;
    return if $client->{gb_sent_own_command};
    if ($zwin->{refnum} == $win->{refnum}) {
	return gb_signal_item_changed($client, $signame, $win, $server);
    }
    return;
}

sub gb_signal_item_moved {
    my ($client, $signame, $win, $item, $oldwin) = @_;
    gb_signal_item_remove($client, $signame, $oldwin, $item);
    return gb_signal_item_new($client, $signame, $win, $item);
}

sub gb_signal_refnum_changed {
    my ($client, $signame, $win, $oldnum) = @_;
    my @bwins;
    my @items = $win->items;
    unless (@items) {
	unshift @bwins, wee_gui_buffers_empty($win);
	for my $server (Irssi::servers) {
	    my $data = wee_gui_buffers_server($server);
	    push @bwins, $data if $data->{number} == $win->{refnum};
	}
	my $act = $win->{active_server}{_irssi} || 0;
	@bwins = sort { $b->{pointers}[0] != $act } @bwins;
    }
    else {
	my $act = $win->{active}{_irssi} || 0;
	for my $it (sort { $b->{_irssi} != $act } @items) {
	    push @bwins, wee_gui_buffers_item($it);
	}
    }
    $client->send({ json => {
	id => 'gb._buffer_title_changed',
	'gb.hdata' => [$_]
       } }) for @bwins;
    return;
}

sub gb_signal_name_changed {
    my ($client, $signame, $win) = @_;
    my @items = $win->items;
    unless (@items) {
	my $data = wee_gui_buffers_empty($win);
	$client->send({ json => {
	    id => 'gb._buffer_title_changed',
	    'gb.hdata' => [$data]
	   } });
	$client->send({ json => {
	    id => 'gb._buffer_renamed',
	    'gb.hdata' => [$data]
	   } });
    }
    return;
}

sub gb_signal_item_title_changed {
    my ($client, $signame, $it) = @_;
    my $data = wee_gui_buffers_item($it);
    $client->send({ json => {
	id => 'gb._buffer_title_changed',
	'gb.hdata' => [$data]
       } });
    return;
}

sub gb_signal_item_name_changed {
    my ($client, $signame, $it) = @_;
    my $data = wee_gui_buffers_item($it);
    $client->send({ json => {
	id => 'gb._buffer_title_changed',
	'gb.hdata' => [$data]
       } });
    $client->send({ json => {
	id => 'gb._buffer_renamed',
	'gb.hdata' => [$data]
       } });
    return;
}

sub gb_signal_send_nicklist {
    my ($client, $signame, $it) = @_;
    $client->send({ json => {
    	id => 'gb._nicklist',
    	'gb.hdata' => [wee_channel_nicklist($it)],
    } });
    return;
}

sub gb_signal_nick_new {
    my ($client, $signame, $ch, $nick) = @_;
    return unless $client->{gb_nicklists}{$ch->{_irssi}};
    my $pg = wee_nicklist_prefix_groups($ch);
    my $data = wee_nicklist_nick_format($ch, $nick);
    return unless $data;
    $data->{_diff} = ord '+';
    $client->send({ json => {
	id => 'gb._nicklist_diff',
	'gb.hdata' => [wee_nicklist_group_format($ch, $pg->{$data->{prefix}}),
		  $data],
       } });
    return;
}

sub gb_signal_nick_change {
    my ($client, $signame, $ch, $nick, $oldnick) = @_;
    return unless $client->{gb_nicklists}{$ch->{_irssi}};
    $client->send({ json => {
	id => 'gb._nicklist_diff',
	'gb.hdata' => [+{
	    _diff => ord 'v',
	    pointers => [ $ch->{_irssi},  $nick->{_irssi} ],
	    name => $nick->{nick},
	    oldname => $oldnick,
	   }],
       } });
    return;
}

sub gb_signal_nick_remove {
    my ($client, $signame, $ch, $nick) = @_;
    return unless $client->{gb_nicklists}{$ch->{_irssi}};
    $client->send({ json => {
	id => 'gb._nicklist_diff',
	'gb.hdata' => [+{
	    _diff => ord '!',
	    pointers => [ $ch->{_irssi},  $nick->{_irssi} ],
	    name => $nick->{nick},
	   }],
       } });
    return;
}

sub gb_signal_nick_mode_change {
    my ($client, $signame, $ch, $nick, undef, $mode, $type) = @_;
    return unless $client->{gb_nicklists}{$ch->{_irssi}};
    my $pg = wee_nicklist_prefix_groups($ch);
    my $data = wee_nicklist_nick_format($ch, $nick);
    $data->{_diff} = ord '@';
    $client->send({ json => {
	id => 'gb._nicklist_diff',
	'gb.hdata' => [wee_nicklist_group_format($ch, $pg->{$data->{prefix}}),
		  $data],
       } });
    return;
}

sub gb_signal_check_dehilight {
    my ($client, $signame, $win, $oldlv) = @_;
    if (teddy_get_S()->{dehilight} && $win->{data_level} == 0 && $oldlv > 0) {
	$client->send({ json => {
	    id => 'gb._buffer_clear_hotlist',
	    buffer => $win->{_irssi},
	   } });
    }
    return;
}

sub gb_check_switch_window {
    my ($client, $signame, $win) = @_;
    if ($client->{sent_own_command}) {
	$client->send({ json => {
	    id => 'gb._buffer_activate',
	    buffer => $win->{_irssi},
	} });
    }
    return;
}

1;
