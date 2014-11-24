use strict;
use warnings;


sub nu_find_target {
    my ($msg, $cl) = @_;
    my ($foundwin, $serobj, $itobj);

    my @wins;
    if (defined $msg->{item}) {
	@wins = Irssi::windows;
    WL: for my $w (@wins) {
	    for my $i ($w->items) {
		if (_iid_or_self($i) == $msg->{item}) {
		    $itobj = ref $i ? $i : (bless +{ _irssi => $i } => 'Irssi::Windowitem');
		    last WL;
		}
	    }
	}
	logmsg("item ".$msg->{item}." not found in main/".(join '/', grep { !/^\./ } @$cl))
	    if $cl && !$itobj;
    }
    if (defined $msg->{window}) {
	@wins = Irssi::windows unless @wins;
	for my $w (@wins) {
	    if ($w->{_irssi} == $msg->{window}) {
		$foundwin = $w;
		last;
	    }
	}
	logmsg("window ".$msg->{window}." not found in main/".(join '/', grep { !/^\./ } @$cl))
	    if $cl && !$foundwin;
    }
    elsif ($msg->{active}) {
	$foundwin = Irssi::active_win;
    }
    if (defined $msg->{server}) {
	$serobj = Irssi::server_find_tag($msg->{server});
    }
    elsif ($msg->{active}) {
	$serobj = Irssi::active_server;
    }
    if ($itobj) {
	$serobj = $itobj->{server} unless $serobj;
	$foundwin = $itobj->window unless $foundwin;
    }
    if ($serobj) {
	$foundwin = $serobj->window_find_closest('', Irssi::level2bits('ALL'))
	    unless $foundwin;
    }
    unless ($foundwin) {
	unless ($serobj) {
	    my $win = Irssi::window_find_closest('', Irssi::level2bits('ALL'));
	    $serobj = $win->{active_server} if $win;
	}
	$foundwin = Irssi::active_win;
    }
    unless ($itobj) {
	if (defined $foundwin->{active}) {
	    $itobj = ref $foundwin->{active} ? $foundwin->{active}
		: (bless +{ _irssi => $foundwin->{active} } => 'Irssi::Windowitem');
	}
    }
    unless ($serobj) {
	if ($foundwin->{active_server}) {
	    $serobj = $foundwin->{active_server};
	}
	elsif ($itobj && $itobj->{server}) {
	    $serobj = $itobj->{server};
	}
    }

    ($foundwin, $serobj, $itobj)
}

## Simple text/command input

sub nu_input_stop_quit {
    Irssi::signal_stop();
    Irssi::command('ipw disconnect');
}

sub handle_nu_input {
    my ($client, $msg, $class) = @_;
    my $cmdchars = Irssi::parse_special('$K');
    local $client->{sent_own_command} = 1;
    my @input = (
	@{ $msg->{data} // [] },
	(map { (substr $cmdchars, 0, 1) . $_ } @{ $msg->{command} // [] }),
	(map { (-1 == index $cmdchars, substr $_, 0, 1) ? $_
		   : (substr $cmdchars, 0, 1) . ' ' . $_ } @{ $msg->{text} // [] })
       );
    return unless @input;
    my $stop_quit = !teddy_get_S()->{enable_quit};
    Irssi::signal_add_first('command quit', 'nu_input_stop_quit')
	    if $stop_quit;
    for (@input) {
	my ($win, $ser, $it) = nu_find_target($msg, $class);
	local $client->{windowinput} = [ $_, $ser, $it ];
	$win->command('ipw proxyinput');
    }
    Irssi::signal_remove('command quit', 'nu_input_stop_quit')
	    if $stop_quit;
    return;
}

1;
