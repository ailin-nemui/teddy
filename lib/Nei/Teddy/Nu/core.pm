use strict;
use warnings;
our $VERSION;

## Subscription events and categories

my %nu_events = (
    line => +{
	'.spec' => +{
	    get => {  scalar => [qw[count skip]], list => [qw[level -level]], bool => [qw[text]], max => [qw[lv]],
		      _view_map_ => { scalar => [qw[count skip after_line before_line]], list => [qw[level -level]], bool => [qw[text]], max => [qw[lv]] }} ,
	    earliest => { _view_map => 'scalar' },
	    bookmark => {  scalar => [qw[name]], bool => [qw[text count]], max => [qw[lv]],
		      _view_map_ => { bool => [qw[text count]], max => [qw[lv]] }} ,
	},
	add => +{
	    '.spec' => +{
		sub => {  list => [qw[view -view level -level]], max => [qw[lv]], bool => [qw[text]],
		      _view_map_ => { list => [qw[level -level]], bool => [qw[text]], max => [qw[lv]] } },
	    },
	    'print text'	      => \&nu_line_add_started,
	    'gui print text finished' => \&nu_line_added,
	},
	alter => +{
	    '.spec' => +{
		sub => {  list => [qw[view -view level -level]], max => [qw[lv]], bool => [qw[text]],
		      _view_map_ => { list => [qw[level -level]], bool => [qw[text]], max => [qw[lv]] } },
	    },
	    'gui print text after finished' => \&nu_line_after_added,
	    'gui textbuffer line removed'   => \&nu_line_removed,
	},
    },

    window => +{
	'.spec' => +{
	    get => +{  list => [qw[refnum id]], min => [qw[data_level]], max => [qw[lv]], bool => [qw[active]] } ,
	    find => +{  scalar => [qw[name server]], list => [qw[level]], max => [qw[lv]] } ,
	},
	ex => +{
	    '.spec' => +{
		sub => +{  max => [qw[lv]] } ,
	    },
	    'window created'   => \&nu_signal_win_created,
	    'window destroyed' => \&nu_signal_win_destroyed,
	},
	attr => +{
	    '.spec' => +{
		sub => +{  list => [qw[id -id]] } ,
	    },
	    'window refnum changed' => \&nu_signal_refnum_changed,
	    'window name changed'   => \&nu_signal_name_changed,
	    'window server changed' => \&nu_signal_window_server_changed,
	    'window item changed'   => \&nu_signal_item_changed,
	    'window level changed'  => \&nu_signal_window_level_changed,
	},
	change => +{
	    '.spec' => +{
		sub => +{ bool => [qw[remote]] },
	    },
	    'window changed'		  => \&nu_signal_window_changed,
	    # #'window changed automatic' => ...,
	},
	act => +{
	    '.spec' => +{
		sub => +{  list => [qw[id -id]], min => [qw[data_level]] } ,
	    },
	    'window activity' => \&nu_signal_window_activity,
	},
    },

    nicklist => +{
	'.spec' => +{
	    get => +{  list => [qw[item nick]], _item_map_ => 'list', scalar => [qw[prefix]], max => [qw[lv]] } ,
	    find => +{ scalar => [qw[mask item]], max => [qw[lv]], bool => [qw[multiple]] },
	},
	onjoin => +{
	    '.spec' => +{
		sub => +{  max => [qw[lv]] } ,
	    },
	    'channel joined' => \&nu_signal_channel_joined_send_nicklist,
	   },
	ex => +{
	    '.spec' => +{
		sub => +{  list => [qw[item -item]], max => [qw[lv]] } ,
	    },
	    'nicklist new'     => \&nu_signal_nicklist_new,
	    'nicklist changed' => \&nu_signal_nicklist_changed,
	    'nicklist remove'  => \&nu_signal_nicklist_remove,
	},
	attr => +{
	    '.spec' => +{
		sub => +{  list => [qw[item -item]] } ,
	    },
	    'nick mode changed'	=> \&nu_signal_nick_mode_change,
	},
    },

    server => +{
	'.spec' => +{
	    get => +{  list => [qw[tag]], max => [qw[lv]] } ,
	},
	ex => +{
	    '.spec' => +{
		sub => +{  max => [qw[lv]] } ,
	    },
	    'server connected'	  => \&nu_signal_server_connected,
	    'server disconnected' => \&nu_signal_server_disconnected,
	},
	attr => +{
	    '.spec' => +{
		sub => +{  list => [qw[tag -tag]] } ,
	    },
	    'server nick changed' => \&nu_signal_server_nick_changed,
	    'away mode changed' => \&nu_signal_server_away_changed,
	},
    },

    item => +{
	'.spec' => +{
	    get => +{  list => [qw[window id type]], max => [qw[lv]] } ,
	    find => +{  scalar => [qw[server name window type]], max => [qw[lv]] } ,
	},
	ex => +{
	    '.spec' => +{
		sub => +{  list => [qw[type -type]], max => [qw[lv]] } ,
	    },
	    'window item new'	 => \&nu_signal_item_new,
	    'window item remove' => \&nu_signal_item_remove,
	},
	attr => +{
	    '.spec' => +{
		sub => +{  list => [qw[id -id type -type]] } ,
	    },
	    'window item moved'	       => \&nu_signal_item_moved,
	    'window item name changed' => \&nu_signal_item_name_changed,
	    'channel topic changed'    => \&nu_signal_item_topic_changed,
	    # #'query nick changed'    => ...,
	    'query server changed'     => \&nu_signal_item_server_changed,
	},
    },

    '.tl' => +{
	'.spec' => +{
	    input => +{ list => [qw[data command text]], scalar => [qw[item server window]], bool => [qw[active]] },
	    parse => +{ list => [qw[data]], scalar => [qw[item server window]], bool => [qw[active]] },
	    'complete word' => +{ scalar => [qw[window item word linestart]] },
	   },
       },
   );

## subscription management

sub _get_args_from_spec_1 {
    my ($spec, $msg, $ret, $empty_spec) = @_;
    return unless 'HASH' eq ref $msg;
    my %unused; @unused{(keys %$msg)} = ();
    for my $name (@{ $spec->{scalar} // [] }, @{ $spec->{min} // [] }, @{ $spec->{max} // [] }) {
	if (exists $msg->{$name} && !ref $msg->{$name} &&
		(defined $msg->{$name} || $empty_spec)) {
	    $ret->{$name} = $msg->{$name}; delete $unused{$name};
	}
    }
    for my $sname (@{ $spec->{list} // [] }) {
	(my $name = $sname) =~ s/^-/not /;
	if (exists $msg->{$name}) {
	    if ('ARRAY' eq ref $msg->{$name}) {
		$ret->{$sname} = [ grep { defined } @{$msg->{$name}} ]; delete $unused{$name};
	    }
	    elsif (defined $msg->{$name} && !ref $msg->{$name}) {
		$ret->{$sname} = [ $msg->{$name} ]; delete $unused{$name};
	    }
	    elsif (!defined $msg->{$name} && $empty_spec) {
		$ret->{$sname} = undef; delete $unused{$name};
	    }
	}
    }
    for my $name (@{ $spec->{bool} // [] }) {
	if (exists $msg->{$name}) {
	    $ret->{$name} = ($empty_spec && !defined $msg->{$name}) ? undef
		: !!$msg->{$name}; delete $unused{$name};
	}
    }
    my ($smap) = grep { /_map_$/ } keys %$spec;
    if (defined $smap) {
	my @ids = sort { $a <=> $b } grep { looks_like_number($_) } keys %$msg;
	if ('HASH' eq ref $spec->{$smap}) { # sub-spec
	    for my $id (@ids) {
		if ('HASH' eq ref $msg->{$id}) {
		    my @unused =
			_get_args_from_spec_1($spec->{$smap}, $msg->{$id}, $ret->{$smap}{$id} = +{});
		    delete $unused{$id};
		    @unused{(map { "$id/$_" } @unused)} = ();
		}
		elsif (!defined $msg->{$id} && $empty_spec) {
		    $ret->{$smap}{$id} = undef; delete $unused{$id};
		}
	    }
	}
	elsif ('list' eq $spec->{$smap}) {
	    for my $id (@ids) {
		if (defined $msg->{$id}) {
		    $ret->{$smap}{$id} = 'ARRAY' eq ref $msg->{$id}
			? [ grep { defined } @{$msg->{$id}} ] : [ $msg->{$id} ]; delete $unused{$id};
		}
		elsif ($empty_spec) {
		    $ret->{$smap}{$id} = undef; delete $unused{$id};
		}
	    }
	}
	elsif ('scalar' eq $spec->{$smap} || 'max' eq $spec->{$smap} || 'min' eq $spec->{$smap}) {
	    for my $id (@ids) {
		if (!ref $msg->{$id} && (defined $msg->{$id} || $empty_spec)) {
		    $ret->{$smap}{$id} = $msg->{$id}; delete $unused{$id};
		}
	    }
	}
	elsif ('bool' eq $spec->{$smap}) {
	    for my $id (@ids) {
		$ret->{$smap}{$id} = ($empty_spec && !defined $msg->{$id}) ? undef
		    : !!$msg->{$id}; delete $unused{$id};
	    }
	}
    }
    return sort keys %unused;
}

sub _get_args_from_spec {
    my ($msg, $cl, $sub) = @_;
    my ($otype, $cat) = @$cl;
    my $spec = $sub ? $nu_events{$otype}{$cat}{'.spec'}{sub}
	: $nu_events{$otype}{'.spec'}{$cat};
    my @unused =
	_get_args_from_spec_1($spec, $msg, my $ret = +{}, $sub && $sub eq 'sub_empty');
    logmsg("unused spec in ".(join '/', ($sub ? 'sub' : 'main'), grep { !/^\./ } @$cl).": "
	       .(join ', ', @unused))
	if !$sub && $cl && @unused;
    return $ret;
}

sub _level_array_to_bit {
    my $bits = 0;
    for my $l (@_) {
	$bits |= Irssi::level2bits($l);
    }
    $bits
}

sub _subscription_transform_args {
    my ($args, $map_r) = @_;
    my ($smap) = grep { /_map_$/ } keys %$args;
    my $map = defined $smap ? delete $args->{$smap} : undef;
    for my $arg ($args, (defined $map ? values %$map : ())) {
	for (qw(level -level)) {
	    $args->{$_} = _level_array_to_bit(@{$args->{$_}})
		if defined $args->{$_};
	}
	for my $k (sort keys %$arg) {
	    if ('ARRAY' eq ref $arg->{$k}) {
		$arg->{$k} = +{ map { $_ => undef } @{$arg->{$k}} };
	    }
	}
    }
    $$map_r = $map;
}

sub _subscribe_events {
    my ($class, $client) = @_;
    my ($otype, $cat) = @$class;
    my $subscribed = exists $client->{sub}{$otype}
	&& exists $client->{sub}{$otype}{$cat};
    my $sigs = $nu_events{$otype}{$cat};
    add_signal_binds($client, +{
	(map { ( $_ => $sigs->{$_} ) } grep { !/^\./ } keys %$sigs)
       }) if !$subscribed;
    return;
}

sub _unsubscribe_events {
    my ($class, $client) = @_;
    my ($otype, $cat) = @$class;
    my $subscribed = exists $client->{sub}{$otype}
	&& exists $client->{sub}{$otype}{$cat};
    my $sigs = $nu_events{$otype}{$cat};
    if ($subscribed) {
	add_signal_binds($client, +{
	    (map { ( $_ => undef ) } grep { !/^\./ } keys %$sigs)
	   });
    }
    delete $client->{sub}{$otype}{$cat};
    delete $client->{sub}{$otype} unless %{$client->{sub}{$otype}};
    return;
}

# IDs: view id item tag type
# specs: level -level text lv
# gets: remote data_level lv
sub _subscription_set  {
    my ($class, $client, $msg) = @_;
    my ($otype, $cat) = @$class;
    if (!defined $msg) { # unsubscribe case
	_unsubscribe_events($class, $client);
	return;
    }

    # subscribe case
    my $args = _get_args_from_spec($msg, $class, 'sub');
    _subscription_transform_args($args, \(my $map));
    %$args = (%$args, %$map) if $map;

    _subscribe_events($class, $client);
    $client->{sub}{$otype}{$cat} = $args;

    return;
}

sub _subscription_add  {
    my ($class, $client, $msg) = @_;
    my ($otype, $cat) = @$class;
    if (!defined $msg) { # unsubscribe case
	return _subscription_set($class, $client);
    }

    my $gr;
    # subscribe case
    my $args = _get_args_from_spec($msg, $class, 'sub_empty') || return;
    _subscription_transform_args($args, \(my $map));
    for my $zm (undef, ($map ? sort { $a <=> $b } keys %$map : ())) {
	my $ar; my $sr;
	if (!defined $zm) {
	    _subscribe_events($class, $client);
	    $ar = $args;
	    $gr = $sr = $client->{sub}{$otype}{$cat} //= +{};
	}
	else {
	    $ar = $map->{$zm};
	    if (!defined $ar) {
		delete $gr->{$zm};
		next;
	    }
	    elsif (!exists $gr->{$zm}) {
		$gr->{$zm} = $map->{$zm};
		next;
	    }
	}
	for my $k (sort keys %$ar) {
	    if (!defined $ar->{$k}) {
		delete $sr->{$k};
	    }
	    elsif ($k eq 'level' || $k eq '-level') {
		$sr->{$k} |= $ar->{$k};
	    }
	    elsif (!ref $ar->{$k} || !ref $sr->{$k}) {
		$sr->{$k} = $ar->{$k};
	    }
	    else {
		%{$sr->{$k}} = (%{$sr->{$k}}, %{$ar->{$k}});
	    }
	}
    }

    return;
}

sub _subscription_rm  {
    my ($class, $client, $msg) = @_;
    my ($otype, $cat) = @$class;
    if (!defined $msg) { # unsubscribe case
	return;
    }

    my $gr;
    # subscribe case
    my $args = _get_args_from_spec($msg, $class, 'sub_empty') || return;
    _subscription_transform_args($args, \(my $map));
    for my $zm (undef, ($map ? sort { $a <=> $b} keys %$map : ())) {
	my $ar; my $sr;
	if (!defined $zm) {
	    return unless $client->{sub}{$otype} && $client->{sub}{$otype}{$cat};
	    $ar = $args;
	    $gr = $sr = $client->{sub}{$otype}{$cat};
	}
	else {
	    $ar = $map->{$zm};
	    if (!exists $gr->{$zm}) {
		next;
	    }
	    if (!defined $map->{$zm}) {
		delete $gr->{$zm};
		next;
	    }
	}
	for my $k (sort keys %$ar) {
	    if ($k eq 'level' || $k eq '-level') {
		$sr->{$k} &= ~$ar->{$k}
		    if defined $ar->{$k};
	    }
	    elsif (!ref $ar->{$k} || !ref $sr->{$k}) {
		next;
	    }
	    else {
		delete @{$sr->{$k}}{ keys %{$ar->{$k}} };
	    }
	}
    }

    return;
}

sub _make_subscription_sub {
    my ($otype, $cb) = @_;
    return sub {
	my $key = pop;
	my ($client, $msg) = @_;
	$msg = +{ '*' => undef } unless defined $msg;
	return unless 'HASH' eq ref $msg;
	my @cats = sort grep { !/^\./ } keys %{$nu_events{$otype}};
	if (exists $msg->{'*'}) {
	    for my $cat (@cats) {
		if (ref $msg->{'*'}) {
		    my $n = dclone $msg->{'*'};
		    if (ref $msg->{$cat}) {
			%{$msg->{$cat}} = (%$n, %{$msg->{$cat}});
		    }
		    else {
			$msg->{$cat} = $n;
		    }
		}
		elsif (!defined $msg->{'*'}) {
		    $msg->{$cat} = undef;
		}
	    }
	}
	for my $cat (@cats) {
	    $cb->([ $otype, $cat ], $client, $msg->{$cat})
		if exists $msg->{$cat};
	}
	return;
    }
}

sub _make_subscription_subs {
    my ($otype) = @_;
    return (
       'sub'	 => _make_subscription_sub($otype, \&_subscription_set),
       'sub_add' => _make_subscription_sub($otype, \&_subscription_add),
       'sub_rm'	 => _make_subscription_sub($otype, \&_subscription_rm),
      );
}

## core commands

my %nu_m_window = (
    _make_subscription_subs('window'),
    'dehilight' => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	$msg = [$msg] unless ref $msg;
	return unless 'ARRAY' eq ref $msg;
	my %ids; @ids{@$msg}=();
	for my $win (Irssi::windows) {
	    if (exists $ids{ $win->{_irssi} }) {
		Irssi::signal_emit('window dehilight', $win);
	    }
	}
	return;
    },
    'server change' => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	local $client->{nu_sent_change_command} = 1;
	for my $win (Irssi::windows) {
	    if (exists $msg->{ $win->{_irssi} }) {
		my $serobj = Irssi::server_find_tag($msg->{ $win->{_irssi} });
		next unless $serobj;
		$win->change_server($serobj)
		    if $win->{active_server}{_irssi} != $serobj->{_irssi};
	    }
	}
	return;
    },
    'item change' => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	local $client->{nu_sent_change_command} = 1;
	for my $win (Irssi::windows) {
	    if (exists $msg->{ $win->{_irssi} }) {
		my $tid = $msg->{ $win->{_irssi} };
		next if $win->{active} && _iid_or_self($win->{active}) == $tid;
		for my $it ($win->items) {
		    if (_iid_or_self($it) == $tid) {
			(ref $it ? $it : (bless +{ _irssi => $it } => 'Irssi::Windowitem'))
			    ->set_active;
			last; # item loop
		    }
		}
	    }
	}
	return;
    },
    'change' => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	return unless !ref $msg;
	local $client->{nu_sent_change_command} = 1;
	for my $win (Irssi::windows) {
	    if ($win->{_irssi} == $msg) {
		$win->set_active;
		return;
	    }
	}
	return;
    },
    'get' => sub {
	my $class = [ 'window', 'get' ];
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	my $args = _get_args_from_spec($msg, $class);
	my $refnum = $args->{refnum} ? +{ map { $_ => undef } @{ $args->{refnum} } } : undef;
	my $id = $args->{id} ? +{ map { $_ => undef } @{ $args->{id} } } : undef;
	my $data_level = $args->{data_level};
	my $lv = $args->{lv} // 2;
	my $active = $args->{active};
	my $awin = Irssi::active_win;
	return [ map { nu_window_info($_, undef, $awin, $lv) }
		     grep {
			 if (!defined $_) {}
			 elsif (defined $data_level && $_->{data_level} < $data_level) {}
			 elsif ($refnum && !exists $refnum->{$_->{refnum}}) {}
			 elsif ($id && !exists $id->{$_->{_irssi}}) {}
			 else { 1 }
		     } $active ? $awin
			 : $refnum ? (map { Irssi::window_find_refnum($_) } sort { $a <=> $b } keys %$refnum)
			     : do { Irssi::windows } ];
    },
    'find' => sub {
	my $class = [ 'window', 'find' ];
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	my $args = _get_args_from_spec($msg, $class);
	my $level = $args->{level} ? _level_array_to_bit(@{$args->{level}}) : undef;
	my $server = defined $args->{server} ? (Irssi::server_find_tag($args->{server})
		|| return []) : undef;
	my $lv = $args->{lv} // 0;
	my $awin = Irssi::active_win;
	if ($server) {
	    return [ (map { nu_window_info($_, undef, $awin, $lv) } grep { defined }
			 defined $args->{name} && defined $level ? $server->window_find_closest($args->{name}, $level)
			     : defined $args->{name} ? $server->window_find_closest($args->{name}, Irssi::level2bits('ALL'))
				 : defined $level ? $server->window_find_level($level)
				     : ()), [] ]->[0];
	}
	else {
	    return [ (map { nu_window_info($_, undef, $awin, $lv) } grep { defined }
			 (defined $args->{name} && defined $level) ? Irssi::window_find_closest($args->{name}, $level)
			     : defined $args->{name} ? Irssi::window_find_name($args->{name})
				 : defined $level ? Irssi::window_find_level($level)
				     : ()), [] ]->[0];
	}
    },
	# window:{get:{refnum:5 / [4,5], id:1234 / [12,34,56], data_level:1, lv:X}}
	# sub:{ex:{lv:X},attr:{id:[...],"not id":[...]},change:{},act:{id:[...],"not id":[...],data_level:...}}
   );

my %nu_m_line = (
    _make_subscription_subs('line'),
    'earliest' => sub {
	my $class = [ 'line', 'earliest' ];
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	my $args = _get_args_from_spec($msg, $class) || return;
	return unless $args->{_view_map_} && %{$args->{_view_map_}};
	my $et = $args->{_view_map_};
	for my $win (Irssi::windows) {
	    my $viewid = $win->view->{_irssi};
	    if (exists $et->{$viewid}) {
		if (defined $et->{$viewid} && looks_like_number($et->{$viewid})) {
		    $client->{earliest_line_time}{$viewid} = $et->{$viewid};
		}
	    }
	}
	return;
    },
    'bookmark' => sub {
	my $class = [ 'line', 'bookmark' ];
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	my $args = _get_args_from_spec($msg, $class);
	return [] unless $args->{_view_map_} && %{$args->{_view_map_}};
	return [] unless $args->{name};
	my $et = $args->{_view_map_};
	my $lv = $args->{lv} // 0;
	my $ret = +{};
	for my $win (Irssi::windows) {
	    my $view = $win->view;
	    my $viewid = $view->{_irssi};
	    if (exists $et->{$viewid}) {
		my $la = $et->{$viewid};
		my $line = $view->get_bookmark($args->{name});
		if (!$line) {
		    $ret->{$viewid} = undef;
		    next;
		}
		my $need_text = $la->{text} // $args->{text} // !!0;
		my $l = nu_line_collect($line, $need_text);
		$l->{previd} = $line->{_irssi};
		my $count = $la->{count} // $args->{count} // 0;
		$l = nu_line_format($l, $lv);
		if ($count) {
		    my $c = 0;
		    ++$c while $line = $line->next;
		    $l->{count} = $c;
		}
		$ret->{$viewid} = $l;
	    }
	}
	return $ret;
    },
    'get' => sub {
	my $class = [ 'line', 'get' ];
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	my $args = _get_args_from_spec($msg, $class);
	return [] unless $args->{_view_map_} && %{$args->{_view_map_}};
	my $et = $args->{_view_map_};
	my $monlevel = $args->{level} ? _level_array_to_bit(@{$args->{level}}) : undef;
	my $mofflevel = $args->{-level} ? _level_array_to_bit(@{$args->{-level}}) : undef;
	my $ret = +{};
	for my $win (Irssi::windows) {
	    my $view = $win->view;
	    my $viewid = $view->{_irssi};
	    if (exists $et->{$viewid}) {
		my $line = $view->{buffer}{cur_line};

		my $la = $et->{$viewid};
		my $count = $la->{count} // $args->{count} // $win->{height};
		my $skip = $la->{skip} // $args->{skip} // 0;
		my $lv = $la->{lv} // $args->{lv} // 2;
		my $onlevel = $la->{level} ? _level_array_to_bit(@{$la->{level}}) : $monlevel;
		my $offlevel = $la->{-level} ? _level_array_to_bit(@{$la->{-level}}) : $mofflevel;
		my $before_line = $la->{before_line};
		my $after_line = $la->{after_line};

		my $need_text = $la->{text} // $args->{text} // !!0;

		my $c = 0;
		my @lines;
		my $start = defined $before_line ? 0 : 1;
		while ($line) {
		    if (!$start) {
			$start = $line->{_irssi} == $before_line;
			next;
		    }
		    if (defined $after_line && $line->{_irssi} == $after_line) {
			last;
		    }
		    if ($skip > 0) {
			--$skip;
			next;
		    }
		    if ($count <= 0) {
			last;
		    }
		    my $l = nu_line_collect($line, $need_text, $onlevel, $offlevel);
		    if ($l) {
			unshift @lines, $l;
			--$count;
		    }
		}
		continue {
		    ++$c;
		    $line = $line->prev;
		}
		$lines[0]{previd} = $line ? $line->{_irssi} : undef
		    if @lines;
		$client->{earliest_line_time}{$viewid} ||= time;
		$ret->{$viewid} = [ map {
		    _update_line_time($client, $viewid, $_->{time});
		    nu_line_format($_, $lv)
		} @lines ]
	    }
	}
	return $ret;
    },
	# line:{get:{<viewid>:{count:...,skip:...,after_line:...,before_line:...,,level:[...]},...,count:...,skip:...,,level:[...]}}
	# line:{earliest:{<viewid>:<timestamp>}}
	# line:{sub:{add:{},alter:{},"*":{view:[...],"not view":[...],level:[...],"not level":[...],text:true/false,lv:X}}}
	# view:{<viewid>:{level:[...],text:true/false,lv:X}}
   );

my %nu_m_nicklist = (
    _make_subscription_subs('nicklist'),
    'get' => sub {
	my $class = [ 'nicklist', 'get' ];
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	my $args = _get_args_from_spec($msg, $class);
	return +{} unless ($args->{item} && @{$args->{item}}) || ($args->{_item_map_} && %{$args->{_item_map_}});
	my $et = $args->{_item_map_};
	my %it;
	if (@{$args->{item} // []}) {
	    @it{@{$args->{item}}}=();
	}
	else {
	    @it{keys %$et}=();
	}
	my $pfx = $args->{prefix};
	my $lv = $args->{lv} // 1;
	my %ret;
	for my $ch (Irssi::channels) {
	    next unless exists $it{$ch->{_irssi}};
	    if (!exists $et->{$ch->{_irssi}}) {
		$ret{ $ch->{_irssi} } = [
		    map { nu_nicklist_nick_info($_, $lv) }
			grep { !defined $pfx
				   || -1 != index $pfx, substr $_->{prefixes}.' ', 0, 1 }
			    $ch->nicks
		   ];
	    }
	    else {
		$ret{ $ch->{_irssi} } = [
		    map { nu_nicklist_nick_info($_, $lv) }
			grep { defined $_
				   && (!defined $pfx
					   || -1 != index $pfx, substr $_->{prefixes}.' ', 0, 1) }
			    map { $ch->nick_find($_) }
				grep { defined } @{$et->{$ch->{_irssi}}//[]}
		   ];
	    }
	}
	return \%ret;
    },
    'find' => sub {
	my $class = [ 'nicklist', 'find' ];
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	my $args = _get_args_from_spec($msg, $class);
	return +{} if !defined $args->{mask} || !defined $args->{item};
	my $lv = $args->{lv} // 0;
	my %ret;
	for my $ch (Irssi::channels) {
	    next unless $ch->{_irssi} == $args->{item};
	    unless ($args->{multiple}) {
		my $nick = $ch->nick_find_mask($args->{mask});
		if ($nick) {
		    $ret{$ch->{_irssi}} = nu_nicklist_nick_info($nick, $lv);
		}
		else {
		    $ret{$ch->{_irssi}} = [];
		}
	    }
	    else {
		$ret{$ch->{_irssi}} = [
		    map { nu_nicklist_nick_info($_, $lv) }
			grep {
			    length $_->{host}
				&& $ch->{server}->masks_match($args->{mask}, $_->{nick}, $_->{host})
			    } $ch->nicks ];
	    }
	}
	return \%ret;
    },
	# nicklist:{get:{item:[98,76]}}
	# nicklist:{get:{item:98,nick:[...]}}
	# nicklist:{get:{nick:{<itemid>:[...],...}}
   );

my %nu_m_server = (
    _make_subscription_subs('server'),
    'get' => sub {
	my $class = [ 'server', 'get' ];
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	my $args = _get_args_from_spec($msg, $class);
	my $lv = $args->{lv} // 3;
	if ($args->{tag}) {
	    return [
		map { nu_server_info($_, $lv) }
		    grep { defined }
			map { Irssi::server_find_tag($_) }
			    grep { defined } @{$args->{tag}} ]
	}
	else {
	    return [
		map { nu_server_info($_, $lv) }
		    Irssi::servers
	       ]
	}
    },
	# server:{get:{tag:[...]}}
   );

my %nu_m_item = (
    _make_subscription_subs('item'),
    'get' => sub {
	my $class = [ 'item', 'get' ];
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	my $args = _get_args_from_spec($msg, $class);
	my $lv = $args->{lv} // 2;
	my @ret;
	my $wins = $args->{window} ? +{ map { $_ => undef } @{ $args->{window} } } : undef;
	my $id = $args->{id} ? +{ map { $_ => undef } @{ $args->{id} } } : undef;
	my $type = $args->{type} ? +{ map { $_ => undef } @{ $args->{type} } } : undef;
	for my $win (Irssi::windows) {
	    next if $wins && !exists $wins->{$win->{_irssi}};
	    for my $it ($win->items) {
		next if $id && !exists $id->{ref $it ? $it->{_irssi} : $it};
		next if $type && !exists $type->{ ref $it ? $it->{type} : '' };
		push @ret, nu_item_info($it, $win, $lv);
	    }
	}
	return \@ret;
    },
    'change' => sub {
	my $key = pop;
	my ($client, $tid) = @_;
	return unless !ref $tid;
	local $client->{nu_sent_change_command} = 1;
	my $awin = Irssi::active_win;
	for my $win (Irssi::windows) {
	    for my $it ($win->items) {
		if (_iid_or_self($it) == $tid) {
		    (ref $it ? $it : (bless +{ _irssi => $it } => 'Irssi::Windowitem'))
			->set_active
			    unless _iid_or_self($win->{active}) == _iid_or_self($it);
		    $win->set_active unless $win->{_irssi} == $awin->{_irssi};
		    return;
		}
	    }
	}
	return;
    },
    'find' => sub {
	my $class = [ 'item', 'find' ];
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	my $args = _get_args_from_spec($msg, $class);

	my $server = defined $args->{server} ? (Irssi::server_find_tag($args->{server})
		|| return []) : undef;

	my $window = defined $args->{window}
	    ? [grep { $_->{_irssi} == $args->{window} } Irssi::windows]
		: undef;
	return [] if $window && !@$window;

	return [] if !defined $args->{name};

	my $lv = $args->{lv} // 0;

	my $it;
	if ($window) {
	    $it = $window->item_find($server, $args->{name});
	    $it = undef if defined $args->{type}
		&& (ref $it ? $it->{type} : '') ne $args->{type};
	}
	elsif (defined $args->{type}) {
	    if ($args->{type} eq 'QUERY') {
		if ($server) {
		    $it = $server->query_find($args->{name});
		}
		else {
		    $it = Irssi::query_find($args->{name});
		}
	    }
	    elsif ($args->{type} eq 'CHANNEL') {
		if ($server) {
		    $it = $server->channel_find($args->{name});
		}
		else {
		    $it = Irssi::channel_find($args->{name});
		}
	    }
	}
	elsif ($server) {
	    $it = $server->window_item_find($args->{name});
	}
	else {
	    $it = Irssi::window_item_find($args->{name});
	}
	if ($it) {
	    return nu_item_info($it, undef, $lv);
	}
	else {
	    return [];
	}
    },
	# item:{get:{window:[12,34,56], id:[98,76], type:.../[...], lv:X}}
	# sub:{ex:{lv:X,type:[...],"not type":[...]},attr:{id:[...],"not id":[...],type:[...],"not type":[...]}...}
   );

sub _make_call_sub_all {
    my ($cb) = @_;
    return sub {
	my $key = pop;
	my ($client, $msg) = @_;
	my %ret;
	for my $otype (sort grep { !/^\./ } keys %nu_events) {
	    my $msgcopy;
	    if ('HASH' eq ref $msg) {
		$msgcopy = {};
		for my $cat (sort keys %$msg) {
		    if ('HASH' eq ref $msg->{$cat}) {
			$msgcopy->{$cat} = {};
			for my $flt (sort keys %{$msg->{$cat}}) {
			    next if looks_like_number($flt);
			    next if $flt eq 'id' || $flt eq 'not id';
			    my $key = $flt eq $otype ? 'id'
				: $flt eq "not $otype" ? 'not id' : $flt;
			    $msgcopy->{$cat}{$key} = ref $msg->{$cat}{$flt} ? dclone $msg->{$cat}{$flt}
				: $msg->{$cat}{$flt};
			}
		    }
		    elsif (!defined $msg->{$cat}) {
			$msgcopy->{$cat} = undef;
		    }
		}
	    }
	    my $r = _make_subscription_sub($otype, $cb)->($client, $msgcopy, 'sub');
	    $ret{$otype} = $r if $r;
	}
	return \%ret if %ret;
	return;
    }
}

my %nu_m_suball = (
    'sub'     => _make_call_sub_all(\&_subscription_set),
    'sub_add' => _make_call_sub_all(\&_subscription_add),
    'sub_rm'  => _make_call_sub_all(\&_subscription_rm),
   );

sub _format_subscription_int {
    my ($d, $o, $p, $q) = @_;
    my $spec = $q // $nu_events{$o}{$p}{'.spec'}{sub};
    my %r;
    for my $k (keys %$d) {
	(my $name = $k) =~ s/^-/not /;
	if (defined $d->{$k} && ($k eq 'level' || $k eq '-level')) {
	    $r{name} = [ split ' ', Irssi::bits2level($d->{$k}) ];
	}
	elsif (!ref $d->{$k}) {
	    if (grep { $_ eq $k } @{$spec->{bool}//[]}) {
		$r{$name} = jbool($d->{$k});
	    }
	    else {
		$r{$name} = $d->{$k};
	    }
	}
	elsif (looks_like_number($k) && 'HASH' eq ref $d->{$k}) {
	    $r{$name} = _format_subscription_int($d->{$k});
	}
	elsif ('HASH' eq ref $d->{$k}) {
	    no warnings qw(numeric void);
	    $r{$name} = [ sort { $a <=> $b || $a cmp $b }
			      map { 0 + $_; $_ } keys %{$d->{$k}} ];
	}
    }
    \%r
}

my %nu_m_subscription = (
    'get' => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	my %ret;
	for my $o (keys %{$client->{sub}//+{}}) {
	    next if %$msg && !$msg->{$o};
	    for my $p (keys %{$client->{sub}{$o}//+{}}) {
		next if %$msg && %{$msg->{$o}//+{}} && !$msg->{$o}{$p};
		$ret{$o}{$p} = _format_subscription_int($client->{sub}{$o}{$p}, $o, $p);
	    }
	}
	return \%ret;
    },

   );

my %nu_m_command = (
    get => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	return [ sort map { $_->{cmd} } Irssi::commands ];
       },
   );

{ my %pl = do { my $i = 1; map { ( $_ => -$i++ ) } reverse
		    qw(sub sub_rm sub_add get) };
  sub _nu_cmd_order_sort {
      ($pl{$a} // 0) <=> ($pl{$b} // 0) || $a cmp $b
  }
}

sub _make_gen_sub {
    my ($tbl, $name) = @_;
    return sub {
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	my %reply;
	for my $cmd (sort _nu_cmd_order_sort keys %$msg) {
	    if (my $r = dispatch_table($tbl, $cmd, "$name/$key/$cmd", $client, $msg->{$cmd})) {
		$reply{$cmd} = $r;
	    }
	}
	return unless %reply;
	return \%reply;
    }
}

my %nu_main = (
    'line'	   => _make_gen_sub(\%nu_m_line, 'main'),
    'window'	   => _make_gen_sub(\%nu_m_window, 'main'),
    'nicklist'	   => _make_gen_sub(\%nu_m_nicklist, 'main'),
    'server'	   => _make_gen_sub(\%nu_m_server, 'main'),
    'item'	   => _make_gen_sub(\%nu_m_item, 'main'),
    '*'		   => _make_gen_sub(\%nu_m_suball, 'main'),
    'subscription' => _make_gen_sub(\%nu_m_subscription, 'main'),
    'commandlist'  => _make_gen_sub(\%nu_m_command, 'main'),
    'disconnect' => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	$client->finish;
	return;
    },
    input => sub {
	my $class = [ '.tl', 'input' ];
	my $key = pop;
	my ($client, $msg) = @_;
	# "input":{"item":...,"server":...,"window":...,"data":...,"command":...,"text":...}
	return unless ref $msg;
	$msg = [ $msg ] if 'HASH' eq ref $msg;
	for my $m (@$msg) {
	    next unless 'HASH' eq ref $m;
	    my $args = _get_args_from_spec($m, $class);
	    handle_nu_input($client, $args, $class);
	}
	return;
    },
    parse => sub {
	my $class = [ '.tl', 'parse' ];
	my $key = pop;
	my ($client, $msg) = @_;
	# "parse":{"item":...,"server":...,"window":...,"data":...}
	return unless 'HASH' eq ref $msg;
	my $args = _get_args_from_spec($msg, $class);
	my ($win, $ser, $it) = nu_find_target($args, $class);
	if ($it) {
	    return [ map { $it->parse_special($_) } @{$args->{data} // []} ];
	}
	elsif ($ser) {
	    return [ map { $ser->parse_special($_) } @{$args->{data} // []} ];
	}
	else {
	    return [ map { Irssi::parse_special($_) } @{$args->{data} // []} ];
	}
    },
    'complete word' => sub {
	my $class = [ '.tl', 'complete word' ];
	my $key = pop;
	my ($client, $msg) = @_;
	return unless 'HASH' eq ref $msg;
	my $args = _get_args_from_spec($msg, $class);
	return +{} unless defined $args->{word} && defined $args->{linestart};
	my ($win, $ser, $it) = nu_find_target($args, $class);
	local $client->{nu_sent_change_command} = 1;
	if ($it) {
	    my $win = $it->window;
	    if (_iid_or_self($win->{active}) != $it->{_irssi}) {
		$it->set_active;
	    }
	}
	my @cl;
	my $ws = 1;
	Irssi::signal_emit('complete word', \@cl, $win, $args->{word}, $args->{linestart}, \$ws);
	return +{ space => jbool($ws), list => \@cl };
    },
    'info store' => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	my $data = Mojo::JSON::j(Irssi::settings_get_str( set 'clientdata' )) // +{};
	return unless 'HASH' eq ref $msg;
	for (keys %$msg) {
	    if (!defined $msg->{$_}) {
		delete $data->{$_};
	    }
	    elsif ('ARRAY' eq ref $msg->{$_} && !@{$msg->{$_}}) {
		delete $data->{$_};
	    }
	    else {
		$data->{$_} = $msg->{$_};
	    }
	}
	Irssi::settings_set_str( set 'clientdata', %$data ? Mojo::JSON::j($data) : '' );
	# "info store":{<clientname>:"info string"}
	return;
    },
    'info fetch' => sub {
	my $key = pop;
	my ($client, $msg) = @_;
	return if ref $msg;
	my $data = Mojo::JSON::j(Irssi::settings_get_str( set 'clientdata' )) // +{};
	return $data->{$msg // ''} // [];
	# "info fetch":<clientname>
    },
   );

sub nu_main_get_commands { \%nu_main }

1;
