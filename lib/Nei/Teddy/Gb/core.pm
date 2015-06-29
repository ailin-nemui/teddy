use strict;
use warnings;

my $custom_xform;
sub gb_custom_xform : lvalue { $custom_xform }
my $version_info = 'Irssi v'.Irssi::parse_special('$J')." - Teddy v". our $VERSION;
sub gb_version_info { $version_info }

sub enable_wee_sync {
    my ($client) = @_;
    add_signal_binds($client, {
	'print text'			=> \&gb_line_add_started,
	'gui print text finished'	=> \&gb_line_added,
	'gui print text after finished' => \&gb_line_after_added,
	'gui textbuffer line removed'	=> \&gb_line_removed,
	'window created'		=> \&gb_signal_win_created,
	'window destroyed'		=> \&gb_signal_win_destroyed,
	# #'channel created'		=> ...,
	# #'channel destroyed'		=> ...,
	# 'channel joined'		=> \&gb_signal_send_nicklist,
	'channel topic changed'		=> \&gb_signal_item_title_changed,
	# #'query created'		=> ...,
	# #'query destroyed'		=> ...,
	# #'query nick changed'		=> ...,
	'query server changed'		=> \&gb_signal_item_name_changed,
	'nicklist new'			=> \&gb_signal_nick_new,
	'nicklist changed'		=> \&gb_signal_nick_change,
	'nicklist remove'		=> \&gb_signal_nick_remove,
	'server connected'		=> \&gb_signal_server_connected,
	'server disconnected'		=> \&gb_signal_server_disconnected,
	'nick mode changed'		=> \&gb_signal_nick_mode_change,
	'window item new'		=> \&gb_signal_item_new,
	'window item remove'		=> \&gb_signal_item_remove,
	'window item moved'		=> \&gb_signal_item_moved,
	'window item changed'		=> \&gb_signal_item_changed,
	'window item name changed'	=> \&gb_signal_item_name_changed,
	'window changed'		=> \&gb_check_switch_window,
	# #'window changed automatic'	=> ...,
	'window refnum changed'		=> \&gb_signal_refnum_changed,
	'window name changed'		=> \&gb_signal_name_changed,
	'window server changed'		=> \&gb_signal_window_server_changed,
	'window activity'		=> \&gb_signal_check_dehilight,
       });
    return;
}

sub disable_wee_sync {
    my ($client) = @_;
    add_signal_binds($client, {
	'print text'			=> undef,
	'gui print text finished'	=> undef,
	'gui print text after finished' => undef,
	'gui textbuffer line removed'	=> undef,
	'window created'		=> undef,
	'window destroyed'		=> undef,
	# #'channel created'		=> undef,
	# #'channel destroyed'		=> undef,
	# 'channel joined'		=> undef,
	'channel topic changed'		=> undef,
	# #'query created'		=> undef,
	# #'query destroyed'		=> undef,
	# #'query nick changed'		=> undef,
	'query server changed'		=> undef,
	'nicklist new'			=> undef,
	'nicklist changed'		=> undef,
	'nicklist remove'		=> undef,
	'server connected'		=> undef,
	'server disconnected'		=> undef,
	'nick mode changed'		=> undef,
	'window item new'		=> undef,
	'window item remove'		=> undef,
	'window item moved'		=> undef,
	'window item changed'		=> undef,
	'window item name changed'	=> undef,
	'window changed'		=> undef,
	# #'window changed automatic'	=> undef,
	'window refnum changed'		=> undef,
	'window name changed'		=> undef,
	'window server changed'		=> undef,
	'window activity'		=> undef,
       });
    return;
}

sub wee_channel_nicklist {
    my $ch = shift;
    my $pg = wee_nicklist_prefix_groups($ch);
    my @list = wee_nicklist_group_format($ch, 'root');

    my @wnicks = map {
	wee_nicklist_nick_format($ch, $_)
    } $ch->nicks;
    for my $p (sort { $pg->{$a} cmp $pg->{$b} } keys %$pg) {
	push @list, wee_nicklist_group_format($ch, $pg->{$p})
	    , grep { $_->{prefix} eq $p } @wnicks;
    }
    return @list;
}

sub handle_gb_nicklist {
    my ($client, $msg) = @_;
    my ($win, $serobj, $itobj) = gb_find_window($msg->{buffer});

    if ($itobj) {
	$client->{gb_nicklists}{$itobj->{_irssi}} = 1;
	if ($itobj->isa('Irssi::Channel')) {
	    return [ wee_channel_nicklist($itobj) ];
	}
	return [ wee_nicklist_group_format($itobj, 'root') ]
    }
    elsif ($serobj) {
	# todo
	$client->{gb_nicklists}{$serobj->{_irssi}} = 1;
	return [ wee_nicklist_group_format($serobj, 'root') ];
    }
    elsif ($win) { # empty
	$client->{gb_nicklists}{$win->{_irssi}} = 1;
	return [ wee_nicklist_group_format($win, 'root') ];
    }
    logmsg('unknown command: nicklist '.shortdump($msg));
}

sub gb_gui_buffers {
    my @bwins;
    for my $server (Irssi::servers) {
	push @bwins, wee_gui_buffers_server($server);
    }
    if (my $win = Irssi::window_find_closest('', Irssi::level2bits('ALL'))) {
	my $act = $win->{active_server}{_irssi} || 0;
	@bwins = sort { $b->{pointers}[0] != $act } @bwins;
    }
    my @wins = sort { $a->{refnum} <=> $b->{refnum} } Irssi::windows();
    my $first = 1;
    for my $win (sort { $a->{refnum} <=> $b->{refnum} } @wins) {
	my @items = $win->items;
	unless (@items) {
	    my $data = wee_gui_buffers_empty($win);
	    if ($first) {
		unshift @bwins, $data;
		$first = undef;
	    }
	    else {
		push @bwins, $data;
	    }
	}
	else {
	    #my $ii = 0;
	    my $act = $win->{active}{_irssi} || 0;
	    for my $it (sort { $b->{_irssi} != $act } @items) {
		push @bwins, wee_gui_buffers_item($it);
	    }
	}
    }
    \@bwins
}

sub gb_gui_hotlist {
    my @hotlist;
    for my $win (Irssi::windows) {
	next unless $win->{data_level} > 1;
	my $view = $win->view;
	my $line = $view->get_bookmark('trackbar') || $view->{startline};
	next unless $line;
	my @count = (0)x4;
	for (; $line; $line = $line->next) {
	    my $level = $line->{info}{level};
	    $count [ $level & (MSGLEVEL_MSGS|MSGLEVEL_DCCMSGS) ? 2
		: $level & MSGLEVEL_HILIGHT ? 3
		    : (($level & MSGLEVEL_PUBLIC) && !($level & MSGLEVEL_NO_ACT)) ? 1
			: 0 ]++;
	}
	push @hotlist, +{
	    buffer => $win->{_irssi},
	    count => \@count,
	};
    }
    \@hotlist
}

sub gb_lines_for {
    my ($client, $winid, $lastlines, $skiplines) = @_;
    my ($win) = grep { $_->{_irssi} == $winid } Irssi::windows();
    return unless $win;

    $skiplines ||= 0;

    my @lines;

    my $view = $win->view;
    my $line = $view->{buffer}{cur_line};
    my $count = 0;
    while ($line && $count < $lastlines) {
	if ($count >= $skiplines) {
	    push @lines, wee_line_collect($line);
	}
    }
    continue {
	++$count;
	$line = $line->prev;
    }
    $client->{gb_earliest_line_time}{$winid} ||= time;
    [ map {
	$client->{gb_earliest_line_time}{$winid} = $_->{time}
	    if $_->{time} && $_->{time} < $client->{gb_earliest_line_time}{$winid};
	wee_line_format($winid, $_)
    } @lines ]
}

my %simple_hdata = (
    'buffer:gui_buffers(*)' => \&gb_gui_buffers,
    'hotlist:gui_hotlist(*)' => \&gb_gui_hotlist,
   );

sub handle_gb_hdata {
    my ($client, $msg) = @_;
    my $path = delete $msg->{path};
    if (my $fun = $simple_hdata{$path}) {
	$fun->($client, $msg);
    }
    elsif ($path =~ m{^buffer:0x(-?\d+)/own_lines/last_line\(-(\d+)(?:,(\d+))?\)/data$}) {
	my ($winid, $lastlines, $skiplines) = ($1, $2, $3);
	gb_lines_for($client, $winid, $lastlines, $skiplines);
    }
    else {
	logmsg("unknown hdata request: $path ".shortdump($msg));
    }
}

my %gb_info = (
    version => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	return "4.$version_info";
    },
   );

my %gb_main = (
    info => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	if (my $r = dispatch_table(\%gb_info, $msg->{name}//'', "$key/".($msg->{name}//'???'), $client, $msg)) {
	    return +{ $msg->{name} => $r }
	}
    },
    hdata => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	handle_gb_hdata($client, $msg);
    },
    input => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	handle_gb_input($client, $msg);
    },
    nicklist => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	handle_gb_nicklist($client, $msg);
    },
    sync => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	enable_wee_sync($client, $msg);
    },
    desync => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	disable_wee_sync($client, $msg);
    },
   );

sub gb_main_get_commands { +{ (map { ("gb.$_" => $gb_main{$_}) } keys %gb_main) } }

1;
