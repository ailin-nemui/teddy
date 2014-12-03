use strict;
use warnings;

my %channel_nicklist_tracker;

## Filter mechanism

sub nu_check_id {
    my ($client, $cl, $key, $id) = @_;
    my ($otype, $cat) = @$cl;
    if (exists $client->{sub}{$otype}
	    && exists $client->{sub}{$otype}{$cat}) {
	my $ref = $client->{sub}{$otype}{$cat};
	if (exists $ref->{$key} && !exists $ref->{$key}{$id}) {
	    return 0;
	}
	if (exists $ref->{-$key} && exists $ref->{-$key}{$id}) {
	    return 0;
	}
    }
    return 1;
}

sub nu_check_get_spec {
    my ($client, $cl, $key, $spec_id, $ret) = @_;
    my ($otype, $cat) = @$cl;
    if (exists $client->{sub}{$otype}
	    && exists $client->{sub}{$otype}{$cat}) {
	my $ref = $client->{sub}{$otype}{$cat};
	if (exists $ref->{$spec_id} && exists $ref->{$spec_id}{$key}) {
	    return $ref->{$spec_id}{$key};
	}
	elsif (exists $ref->{$key}) {
	    return $ref->{$key};
	}
    }
    return $ret;
}

sub nu_check_get {
    my ($client, $cl, $key, $ret) = @_;
    my ($otype, $cat) = @$cl;
    if (exists $client->{sub}{$otype}
	    && exists $client->{sub}{$otype}{$cat}) {
	my $ref = $client->{sub}{$otype}{$cat};
	if (exists $ref->{$key}) {
	    return $ref->{$key};
	}
    }
    return $ret;
}

## Event handlers for subscription

sub nu_line_add_started {
    my $class = [ 'line', 'add' ];
    my ($client, $signame, $textdest) = @_;
    my $view = $textdest->{window}->view || return;
    nu_check_id($client, $class, view => $view->{_irssi}) || return;
    $client->{line_add_started}{ $view->{_irssi} }
	= ($view->{buffer}{cur_line}||+{})->{_irssi};

    return;
}

sub nu_line_added {
    my $class = [ 'line', 'add' ];
    my ($client, $signame, $win) = @_;
    my $view = $win->view;
    my $viewid = $view->{_irssi};
    my $line = $view->{buffer}{cur_line};
    my $previd = delete $client->{line_add_started}{ $viewid } || 0;
    return unless $line;
    nu_check_id($client, $class, view => $viewid) || return;
    my $need_text = nu_check_get_spec($client, $class, 'text', $viewid, 0);
    my $onlevel = nu_check_get_spec($client, $class, 'level', $viewid);
    my $offlevel = nu_check_get_spec($client, $class, '-level', $viewid);
    my $lv = nu_check_get_spec($client, $class, 'lv', $viewid, 0);

    my @lines;
    for (; $line && $line->{_irssi} != $previd; $line = $line->prev) {
	my $l = nu_line_collect($line, $need_text, $onlevel, $offlevel);
	unshift @lines, $l if $l;
    }
    return unless @lines;
    nu_check_line_removals_before_add($client, $viewid, \@lines);

    $client->{earliest_line_time}{$viewid} ||= time;
    $client->send({json => +{
	'line added' => +{
	    $viewid => [map {
		_update_line_time($client, $viewid, $_->{time});
		nu_line_format($_, $lv)
	    } @lines],
	}
       } });

    return;
}

# $client <= {
#   send_line_delayed_rmaa => {
#     timer => $tag,
#     box   => [
#       { type => 'add_after', <viewid> => [...] },
#       { type => 'rm', <viewid> => [...], ... },
#       ...
#     ],
#   }

sub nu_send_line_delayed_rmaa {
    my $class = [ 'line', 'alter' ];
    my ($client) = @_;
    my $rmaa = delete $client->{send_line_delayed_rmaa} or return;
    my $tid = delete $rmaa->{timer};
    my $box = delete $rmaa->{box} or return;
    my $vw;
    ipw_rawlog_record($client, [_ => 'rmaa begin', $tid]) if @$box > 1;
    for my $ev (@$box) {
	my $type = delete $ev->{type};
	if ('rm' eq $type) {
	    nu_send_line_removals($client, $ev);
	}
	elsif ('add_after' eq $type) {
	    nu_send_line_after_adds($client, $ev);
	}
    }
    ipw_rawlog_record($client, [_ => 'rmaa end', $tid]) if @$box > 1;
    return;
}

sub _update_line_time {
    my ($client, $viewid, $time) = @_;
    $client->{earliest_line_time}{ $viewid } = $time
	if $time && $time < $client->{earliest_line_time}{ $viewid };
}

sub nu_send_line_after_adds {
    my $class = [ 'line', 'alter' ];
    my ($client, $adds) = @_;
    return unless $adds;
    return unless %$adds;
    $client->send({ json => {
	'line added after' => +{
	    (map {
		my $viewid = $_;
		my $lv = nu_check_get_spec($client, $class, 'lv', $viewid, 0);
		( $viewid => [map {
		    _update_line_time($client, $viewid, $_->{time});
		    nu_line_format($_, $lv)
		} @{$adds->{$viewid}}] ),
	    } sort { $a <=> $b } keys %$adds),
	}
       } });
    return;
}

sub nu_line_after_added {
    my $class = [ 'line', 'alter' ];
    my ($client, $signame, $win, $line, $prev) = @_;
    my $viewid = $win->view->{_irssi};
    my $previd = $prev->{_irssi} || 0;
    return unless $line;
    nu_check_id($client, $class, view => $viewid) || return;

    my $maxtime = 2*time;
    return unless exists $client->{earliest_line_time}{$viewid};
    return if $prev && $prev->{info}{time} && $prev->{info}{time} < $maxtime
	&& $client->{earliest_line_time}{$viewid} > $prev->{info}{time};
    return if $line->{info}{time} && $line->{info}{time} < $maxtime
	&& $client->{earliest_line_time}{$viewid} > $line->{info}{time};

    my $need_text = nu_check_get_spec($client, $class, 'text', $viewid, 0);
    my $onlevel = nu_check_get_spec($client, $class, 'level', $viewid);
    my $offlevel = nu_check_get_spec($client, $class, '-level', $viewid);

    my @lines;
    for (; $line && $line->{_irssi} != $previd; $line = $line->prev) {
	my $l = nu_line_collect($line, $need_text, $onlevel, $offlevel);
	unshift @lines, $l if $l;
    }
    return unless @lines;

    my $rmaa = $client->{send_line_delayed_rmaa} ||= +{};
    my $box = $rmaa->{box} ||= [];
    push @$box, +{ type => 'add_after' }
	unless @$box && 'add_after' eq $box->[-1]{type};
    my $last = $box->[-1]{ $viewid } ||= [];
    # see if this is a continuation, then optimise
    if (@$last && $last->[-1]{ref} == ($prev ? $prev->{_irssi} : 0)) {
	# continuation, no need to record prevline
    }
    else {
	$lines[0]{previd} = ($prev||{})->{_irssi};
    }
    push @$last, @lines;
    Irssi::timeout_remove(delete $rmaa->{timer})
	    if exists $rmaa->{timer};
    weaken $client;

    $rmaa->{timer} = Irssi::timeout_add_once(
	100, sub {
	    return unless $client;
	    return unless $client->{authenticated};
	    nu_send_line_delayed_rmaa($client)
	}, '');
    return;
}

sub nu_send_line_removals {
    my ($client, $rms) = @_;
    return unless $rms;
    $client->send({ json => {
	'line removed' => $rms
       } });
    return;
}

sub nu_check_line_removals_before_add {
    my ($client, $viewid, $lines) = @_;
    my $rmaa = $client->{send_line_delayed_rmaa} or return;
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
	    return nu_send_line_delayed_rmaa($client);
	}
    }
}

sub nu_line_removed {
    my $class = [ 'line', 'alter' ];
    my ($client, $signame, $view, $line, $prevline) = @_;
    return unless $view;
    return unless $line;
    my $viewid = $view->{_irssi};
    nu_check_id($client, $class, view => $viewid) || return;
    # searching the window is expensive

    my $onlevel = nu_check_get_spec($client, $class, 'level', $viewid);
    my $offlevel = nu_check_get_spec($client, $class, '-level', $viewid);

    return if ((defined $onlevel || defined $offlevel)
	    && !nu_line_collect($line, 0, $onlevel, $offlevel));

    #ipw_rawlog_record($client, [_ => 'line removed', $viewid, $line->{_irssi}, $line->get_text(0)]);
    my $rmaa = $client->{send_line_delayed_rmaa} ||= +{};
    my $box = $rmaa->{box} ||= [];
    push @$box, +{ type => 'rm' }
	unless @$box && 'rm' eq $box->[-1]{type};
    push @{$box->[-1]{$viewid}}, $line->{_irssi};

    Irssi::timeout_remove(delete $rmaa->{timer})
	    if exists $rmaa->{timer};
    weaken $client;

    if ($view->{buffer}{cur_line}
	    && $line->{_irssi} == $view->{buffer}{cur_line}{_irssi}) {
	# hiding the last printed line
	return nu_send_line_delayed_rmaa($client);
    }

    $rmaa->{timer} = Irssi::timeout_add_once(
	500, sub {
	    return unless $client;
	    return unless $client->{authenticated};
	    nu_send_line_delayed_rmaa($client)
	}, '');
    return;
}

sub nu_signal_win_created {
    my $class = [ 'window', 'ex' ];
    my ($client, $signame, $win) = @_;
    my $view = $win->view;
    my $viewid = $view->{_irssi};
    $client->{earliest_line_time}{$viewid} = time if $win;
    my $lv = nu_check_get_spec($client, $class, 'lv', $viewid, 0);
    $client->send({ json => {
	'window created' => nu_window_info($win, $view, undef, $lv),
       } });
    return;
}

sub nu_signal_win_destroyed {
    my $class = [ 'window', 'ex' ];
    my ($client, $signame, $win) = @_;
    my $viewid = $win->view->{_irssi};
    delete $client->{earliest_line_time}{$viewid};
    $client->send({ json => {
	'window destroyed' => $win->{_irssi},
    } });
    return;
}

sub nu_signal_refnum_changed {
    my $class = [ 'window', 'attr' ];
    my ($client, $signame, $win, $oldnum) = @_;
    nu_check_id($client, $class, id => $win->{_irssi}) || return;
    $client->send({ json => {
	'window refnum changed' => +{
	    id => $win->{_irssi},
	    kvslice($win, 'refnum'),
	    'old refnum' => $oldnum,
	},
    } });
    return;
}

sub nu_signal_name_changed {
    my $class = [ 'window', 'attr' ];
    my ($client, $signame, $win) = @_;
    nu_check_id($client, $class, id => $win->{_irssi}) || return;
    $client->send({ json => {
	'window name changed' => +{
	    id => $win->{_irssi},
	    kvslice_uni2($win, 'name'),
	},
    } });
    return;
}

sub nu_signal_window_server_changed {
    my $class = [ 'window', 'attr' ];
    my ($client, $signame, $win, $server) = @_;
    nu_check_id($client, $class, id => $win->{_irssi}) || return;
    $client->send({ json => {
	'window server changed' => +{
	    id => $win->{_irssi},
	    ($server ? (active_server => $server->{tag}) : ()),
	},
    } });
    return;
}

sub nu_signal_window_level_changed {
    my $class = [ 'window', 'attr' ];
    my ($client, $signame, $win, $server) = @_;
    nu_check_id($client, $class, id => $win->{_irssi}) || return;
    $client->send({ json => {
	'window level changed' => +{
	    id => $win->{_irssi},
	    level => [ split ' ', Irssi::bits2level($win->{level}) ],
	},
    } });
    return;
}

sub nu_send_item_changed {
    my $class = [ 'window', 'attr' ];
    my ($client, $id, $ref) = @_;
    delete $client->{nu_item_change}{$ref};
    nu_check_id($client, $class, id => $ref) || return;
    $client->send({ json => {
	'window item changed' => +{
	    id => $ref,
	    active => $id,
	},
    } });
    return;
}

sub nu_signal_item_changed {
    my ($client, $signame, $win, $it) = @_;
    my $id = ref $it ? $it->{_irssi} : $it;
    my $ref = $win->{_irssi};
    Irssi::timeout_remove(delete $client->{nu_item_change}{$ref})
	    if $client->{nu_item_change}{$ref};
    weaken $client;
    $client->{nu_item_change}{$ref}
	= Irssi::timeout_add_once(
	    10, sub {
		return unless $client;
		return unless $client->{authenticated};
		nu_send_item_changed($client, $id, $ref);
	    }, '');
    return;
}

sub nu_signal_window_changed {
    my $class = [ 'window', 'change' ];
    my ($client, $signame, $win, $oldwin) = @_;
    !$client->{sent_own_command} || nu_check_get($client, $class, 'remote', 1)
	|| return;
    my $ev = $client->{sent_own_command} ? 'window changed' : 'window changed remote';
    $client->send({ json => {
	$ev => +{
	    id => $win->{_irssi},
	    ($oldwin ? ('old id' => $oldwin->{_irssi}) : ()),
	},
    } });
    return;
}

sub nu_signal_window_activity {
    my $class = [ 'window', 'act' ];
    my ($client, $signame, $win, $oldlv) = @_;
    return if $win->{data_level} == $oldlv;
    nu_check_id($client, $class, id => $win->{_irssi}) || return;
    my $minlv = nu_check_get($client, $class, 'data_level', 0);
    return unless (($win->{data_level} == 0 && $oldlv >= $minlv)
		       || $win->{data_level} >= $minlv);
    $client->send({ json => {
	'window activity' => +{
	    id => $win->{_irssi},
	    kvslice($win, qw(data_level hilight_color)),
	    'old data_level' => $oldlv,
	},
    } });
    return;
}

sub nu_signal_nicklist_new {
    my $class = [ 'nicklist', 'ex' ];
    my ($client, $signame, $ch, $nick) = @_;
    return unless $channel_nicklist_tracker{$ch->{_irssi}};
    nu_check_id($client, $class, item => $ch->{_irssi}) || return;
    my $lv = nu_check_get_spec($client, $class, 'lv', $ch->{_irssi}, 0);
    my $data = nu_nicklist_nick_info($nick, $lv);
    return unless $data;
    $client->send({ json => {
	'nicklist new' => +{
	    $ch->{_irssi} => $data,
	},
    } });
    return;
}

sub nu_signal_nicklist_changed {
    my $class = [ 'nicklist', 'ex' ];
    my ($client, $signame, $ch, $nick, $oldnick) = @_;
    nu_check_id($client, $class, item => $ch->{_irssi}) || return;
    $client->send({ json => {
	'nicklist changed' => +{
	   $ch->{_irssi} => +{
	       kvslice_uni2($nick, 'nick'),
	       'old nick' => as_uni2($oldnick),
	   },
       },
    } });
    return;
}

sub nu_signal_nicklist_remove {
    my $class = [ 'nicklist', 'ex' ];
    my ($client, $signame, $ch, $nick) = @_;
    return unless $channel_nicklist_tracker{$ch->{_irssi}};
    nu_check_id($client, $class, item => $ch->{_irssi}) || return;
    $client->send({ json => {
	'nicklist remove' => +{
	   $ch->{_irssi} => +{
	       kvslice_uni2($nick, 'nick'),
	   },
       },
    } });
    return;
}

sub nu_signal_nick_mode_change {
    my $class = [ 'nicklist', 'attr' ];
    my ($client, $signame, $ch, $nick, undef, $mode, $type) = @_;
    nu_check_id($client, $class, item => $ch->{_irssi}) || return;
    $client->send({ json => {
	'nick mode change' => +{
	    $ch->{_irssi} => +{
		kvslice($nick, qw(prefixes)),
		kvslice_uni2($nick, qw(nick)),
		mode => $mode,
		type => $type,
	    },
	},
    } });
    return;
}

sub nu_signal_server_connected {
    my $class = [ 'server', 'ex' ];
    my ($client, $signame, $server) = @_;
    nu_check_id($client, $class, tag => $server->{tag}) || return;
    my $lv = nu_check_get($client, $class, 'lv', 0);
    $client->send({ json => {
	'server connected' => nu_server_info($server, $lv),
       } });
    return;
}

sub nu_signal_server_disconnected {
    my $class = [ 'server', 'ex' ];
    my ($client, $signame, $server) = @_;
    nu_check_id($client, $class, tag => $server->{tag}) || return;
    $client->send({ json => {
	'server disconnected' => $server->{tag},
       } });
    return;
}

sub nu_signal_server_nick_changed {
    my $class = [ 'server', 'attr' ];
    my ($client, $signame, $server) = @_;
    nu_check_id($client, $class, tag => $server->{tag}) || return;
    $client->send({ json => {
	'server nick changed' => {
	    tag => $server->{tag},
	    kvslice_uni2($server, qw(nick)),
	},
       } });
    return;
}

sub nu_signal_server_away_changed {
    my $class = [ 'server', 'attr' ];
    my ($client, $signame, $server) = @_;
    nu_check_id($client, $class, tag => $server->{tag}) || return;
    $client->send({ json => {
	'server away mode changed' => {
	    tag => $server->{tag},
	    kvslice_bool($server, qw(usermode_away)),
	    kvslice_uni2($server, qw(away_reason)),
	},
       } });
    return;
}

sub nu_signal_item_new {
    my $class = [ 'item', 'ex' ];
    my ($client, $signame, $win, $it) = @_;
    nu_check_id($client, $class, type => (ref $it ? $it->{type} : ''))
	|| return;
    my $lv = nu_check_get($client, $class, 'lv', 0);
    $client->send({ json => {
	'window item new' => nu_item_info($it, $win, $lv),
    } });
    return;
}

sub nu_signal_item_remove {
    my $class = [ 'item', 'ex' ];
    my ($client, $signame, $win, $it) = @_;
    nu_check_id($client, $class, type => (ref $it ? $it->{type} : ''))
	|| return;
    $client->send({ json => {
	'window item remove' => ref $it ? $it->{_irssi} : $it,
    } });
    return;
}

sub nu_signal_item_moved {
    my $class = [ 'item', 'attr' ];
    my ($client, $signame, $win, $it, $oldwin) = @_;
    nu_check_id($client, $class, type => (ref $it ? $it->{type} : ''))
	|| return;
    nu_check_id($client, $class, id => (ref $it ? $it->{_irssi} : $it))
	|| return;
    $client->send({ json => {
	'window item moved' => +{
	    id     => ref $it ? $it->{_irssi} : $it,
	    window => $win->{_irssi},
	    'old window' => $oldwin->{_irssi},
	},
    } });
    return;
}

sub nu_signal_item_name_changed {
    my $class = [ 'item', 'attr' ];
    my ($client, $signame, $it) = @_;
    nu_check_id($client, $class, type => (ref $it ? $it->{type} : ''))
	|| return;
    nu_check_id($client, $class, id => (ref $it ? $it->{_irssi} : $it))
	|| return;
    $client->send({ json => {
	'window item name changed' => +{
	    id => ref $it ? $it->{_irssi} : $it,
	    (ref $it ? kvslice_uni2($it, qw(name visible_name)) : ()),
	    lfilter_sub(ref $it && !$it->isa('Irssi::Channel'),
			sub { (topic => as_uni2($it->parse_special('$topic'))) }),
	},
    } });
    return;
}

sub nu_signal_item_topic_changed {
    my $class = [ 'item', 'attr' ];
    my ($client, $signame, $it) = @_;
    return unless ref $it;
    nu_check_id($client, $class, type => $it->{type}) || return;
    nu_check_id($client, $class, id => $it->{_irssi}) || return;
    $client->send({ json => {
	'window item topic changed' => +{
	    id => $it->{_irssi},
	    topic => as_uni2($it->parse_special('$topic')),
	},
    } });
    return;
}

sub nu_signal_item_server_changed {
    my $class = [ 'item', 'attr' ];
    my ($client, $signame, $it) = @_;
    return unless ref $it;
    nu_check_id($client, $class, type => $it->{type}) || return;
    nu_check_id($client, $class, id => $it->{_irssi}) || return;
    $client->send({ json => {
	'window item server changed' => +{
	    id => $it->{_irssi},
	    (exists $it->{server_tag} ? (server_tag => $it->{server_tag}) : ()),
	    ($it->{server} ? (server => $it->{server}{tag}) : ()),
	},
    } });
    return;
}

sub nu_signal_channel_joined_send_nicklist {
    my $class = [ 'nicklist', 'onjoin' ];
    my ($client, $signame, $ch) = @_;
    return unless ref $ch && $ch->can('nicks');
    my $lv = nu_check_get($client, $class, 'lv', 0);
    $client->send({ json => {
	nicklist => +{
	    $ch->{_irssi} => [
		map { nu_nicklist_nick_info($_, $lv) } $ch->nicks
	       ],
	},
    } });
    return;
}

sub nu_channel_nicklist_tracker {
    my ($ch) = @_;
    $channel_nicklist_tracker{ $ch->{_irssi} } = 1;
}
sub nu_channel_nicklist_tracker_stop {
    my ($ch) = @_;
    delete $channel_nicklist_tracker{ $ch->{_irssi} };
}

1;
