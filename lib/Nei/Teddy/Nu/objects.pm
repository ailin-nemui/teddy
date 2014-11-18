use strict;
use warnings;
use Irssi;

my $irssi_mumbo2 = qr/\cD[`-i]|\cD[&-@\xff].|\c_|\cV|\cD#..../;

## Format of data structures and detail levels

sub nu_server_info {
    my ($s, $lv) = @_;
    +{
	tag => $s->{tag},
	kvslice($s,
		lfilter($lv > 0, qw(real_address chat_type)),
		lfilter($lv > 1, qw(connect_time chatnet address port)),
		lfilter($lv > 2, qw(lag userhost))),
	kvslice_uni2($s,
		lfilter($lv > 0, qw(away_reason nick)),
		lfilter($lv > 1, qw(realname username version last_invite)),
		lfilter($lv > 2, qw(wanted_nick))),
	kvslice_bool($s,
		     lfilter($lv > 0, qw(usermode_away)),
		     lfilter($lv > 2, qw(connected reconnection server_operator))),
    }
}

sub nu_window_info {
    my ($w, $v, $awin, $lv) = @_;
    $v ||= $w->view;
    +{
	id   => $w->{_irssi},
	view => $v->{_irssi},
	($awin ?
	     (active_win => jbool($awin->{refnum} == $w->{refnum})) : ()),
	kvslice($w,
		lfilter($lv > 0, qw(refnum data_level hilight_color)),
		lfilter($lv > 1, qw(last_timestamp last_line))),
	kvslice_uni2($w,
		lfilter($lv > 0, qw(name))),
	kvslice($v->{buffer}, lfilter($lv > 1, qw(lines_count))),
	kvslice_bool($w,
		    lfilter($lv > 1, qw(immortal sticky_refnum))),
	lfilter_sub($lv > 0, sub { (
	    cur_line => ($v->{buffer}{cur_line}||+{})->{_irssi},
	    ($w->{active_server} ? (active_server => $w->{active_server}{tag}) : ()),
	    (defined $w->{active} ? (active => _iid_or_self($w->{active})) : ()),
	   ) }),
	lfilter_sub($lv > 1, sub { (
	    level => [ split ' ', Irssi::bits2level($w->{level}) ],
	    first_line => ($v->{buffer}{cur_line}||+{})->{_irssi},
	   ) }),
    }
}

sub nu_item_info {
    my ($i, $w, $lv) = @_;
    if (!ref $i) {
	return +{
	    id => $i,
	   };
    }
    $w ||= $i->window;
    my $ch = $i->isa('Irssi::Channel');
    my $qu = $i->isa('Irssi::Query');
    +{
	id     => $i->{_irssi},
	window => $w->{_irssi},
	type   => $i->{type},
	kvslice($i,
		lfilter($lv > 0, qw(chat_type)),
		lfilter($lv > 1 && $ch, qw(topic_time)),
		lfilter($lv > 1 && $qu, qw(address server_tag last_unread_msg))),
	kvslice_uni2($i,
		lfilter($lv > 0, qw(name visible_name)),
		lfilter($lv > 1 && $ch, qw(topic_by))),
	kvslice_bool($i, lfilter($lv > 1 && $ch, qw(chanop))),
	kvslice_bool($i, lfilter($lv > 1 && $qu, qw(unwanted))),
	lfilter_sub($lv > 0, sub { (
	    topic => as_uni2($i->parse_special('$topic')),
	    ($i->{server} ? (server => $i->{server}{tag}) : ()),
	   ) }),
	lfilter_sub($lv > 1 && $ch, sub { ($i->{ownnick} ? (ownnick => as_uni2($i->{ownnick}{nick})) : ()) }),
    }
}

sub nu_line_format {
    my ($l, $lv) = @_;
    my $text = $l->{text};
    my $sflen;
    if (defined $text) {
	my $sf = as_uni2(strftime(teddy_get_S()->{timestamp_render}, localtime $l->{time}));
	s/((?:$irssi_mumbo2)+)(\cDe)/$2$1/g for $text, $sf;
	$sflen = length $sf;
	$sflen = undef unless $sf eq substr $text, 0, $sflen;
    }
    my $fromnick = $Irssi::LineMeta{ $l->{ref} } ? $Irssi::LineMeta{ $l->{ref} }{nick} : undef;
    +{
	id => $l->{ref},
	hilight => jbool($l->{level} & MSGLEVEL_HILIGHT),
	kvslice($l, lfilter($lv > 0, qw(time))),
	lfilter_sub($lv > 0, sub { (
	    public => jbool($l->{level} & MSGLEVEL_PUBLIC),
	    private => jbool($l->{level} & (MSGLEVEL_MSGS|MSGLEVEL_DCCMSGS)),
	    no_act => jbool($l->{level} & MSGLEVEL_NO_ACT),
	    (defined $fromnick ? (fromnick => as_uni2($fromnick)) : ()),
	   ) }),
	lfilter_sub($lv > 1, sub { (
	    level => [ split ' ', Irssi::bits2level($l->{level}) ],
	    ($sflen ? (timelen => $sflen) : ()),
	   ) }),
	(defined $l->{text} ? (text => $text) : ()),
	(exists $l->{previd} ? (prevline => $l->{previd}) : ()),
    }
}

sub nu_nicklist_nick_info {
    my ($n, $lv) = @_;
    if (!defined $n->{type}) {
	#logmsg("weird nick:".$ch->{name}."/".shortdump($_));
	return;
    }
    +{
	kvslice($n, qw(prefixes),
		lfilter($lv > 0, qw(host hops last_check))),
	kvslice_uni2($n, qw(nick),
		lfilter($lv > 0, qw(realname))),
	kvslice_bool($n, lfilter($lv > 0, qw(gone serverop))),
    }
}

sub nu_line_collect {
    my ($line, $need_text, $onlevel, $offlevel) = @_;
    my $time = $line->{info}{time};
    my $lv = $line->{info}{level};
    if ($time > 2*time) {
	# logmsg("weird line time:".Irssi::bits2level($line->{info}{level})." "
	# 	   .shortdump($line).$line->get_text(0));
	$time = 0;
	$lv = MSGLEVEL_NEVER;
    }
    return if defined $onlevel && !($lv & $onlevel);
    return if defined $offlevel && ($lv & $offlevel);
    +{
	ref => $line->{_irssi},
	lfilter_sub($need_text, sub { (text => as_uni2($line->get_text(1))) }),
	time => $time,
	level => $lv,
    }
}

1;
