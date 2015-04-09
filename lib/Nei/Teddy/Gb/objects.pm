use strict;
use warnings;

my $irssi_mumbo2 = qr/\cD[`-i]|\cD[&-@\xff].|\c_|\cV|\cD#..../;

sub wee_nicklist_nick_format {
    my $ch = shift;
    for ($_[0]) {
	if (!defined $_->{type}) {
	    #logmsg("weird nick:".$ch->{name}."/".shortdump($_));
	    return;
	}
	return +{
	    pointers => [ $ch->{_irssi},  delete $_->{_irssi} ],
	    name => as_uni2(delete $_->{nick}),
	    prefix => (substr $_->{prefixes}.($_->{other}>32 ? chr $_->{other} : '').($_->{op}?'@':'').($_->{halfop}?'%':'').($_->{voice}?'+':'').' ', 0, 1),
	    type => lc delete $_->{type},
	    #(%$_),
	    group => 0,
	    visible => 1,
	}
    }
}

sub wee_nicklist_group_format {
    my ($ch, $name) = @_;
    +{
	pointers => [ $ch->{_irssi} ],
	group => 1,
	visible => 0,
	name => $name,
    }
}

sub wee_nicklist_prefix_groups {
    my $ch = shift;
    my %bp = (qw(& 0 @ 5 % 10 + 15), ' ' => 20);
    my $prefixes = '&@%+';
    if ($ch->{server}->can('isupport')) {
	my $isp = $ch->{server}->isupport('prefix');
	if ($isp =~ s/^\(.*\)//) {
	    $prefixes = $isp;
	}
	else {
	    $prefixes = '@+';
	}
    }
    $prefixes .= ' ';
    my %p;
    my $i = 0;
    for my $p (split //, $prefixes) {
	if (exists $bp{$p} && $i < $bp{$p}) {
	    $i = $bp{$p};
	}
	$p{$p} = sprintf '%03d|%3s', $i++, $p;
    }
    \%p
}

sub wee_gui_buffers_server {
    my $server = shift;
    my $win = $server->window_find_closest('', Irssi::level2bits('ALL'));
    my $name = as_uni2($server->{tag});
    if (gb_custom_xform()) {
	no strict 'refs';
	local ${ __PACKAGE__ . '::custom_xform::TAG' } = 1;
	run_custom_xform() for $name;
    }
    my $full_name = join '.', (lc $server->{chat_type}), $server->{tag};
    +{
	pointers => [ $server->{_irssi}, $win->{_irssi} ],
	number => $win->{refnum},
	full_name => $full_name,
	short_name => $name,
	title => as_uni2($server->{nick}).' @ '.$server->{tag}.
	    ' ('.($server->{real_address}||$server->{address}).')',
	#notify => ...,
	local_variables => +{ type => lc $server->{type} },
    }
}

sub wee_gui_buffers_empty {
    my $win = shift;
    my $name = remove_uniform_vars(undef, as_uni2($win->get_active_name // ''));
    my $full_name = (join '.', 'empty', $win->{refnum});
    +{
	pointers => [ $win->{_irssi}, $win->{_irssi} ],
	number => $win->{refnum},
	full_name => $full_name,
	short_name => $name,
	title => $win->{level} ? gb_version_info() : $name,
	#notify => ...,
	local_variables => +{},
    }
}

sub wee_gui_buffers_item {
    my $it = shift;
    my $win = $it->window;
    my $name = remove_uniform_vars($it, as_uni2($it->{visible_name} || $it->{name}));
    my $full_name =
	(join '.', (lc $it->{chat_type}//'core'), ($it->{server}{tag}//$it->{server_tag}), as_uni2($it->{name}));
    my %lv;
    $lv{type} = $it->{type} eq 'QUERY' ? 'private' : lc $it->{type};
    $lv{name} = $it->{name};
    $lv{visible_name} = $it->{visible_name};
    +{
	pointers => [ $it->{_irssi}, $win->{_irssi} ],
	number => $win->{refnum},
	#item_number => $ii++,
	full_name => $full_name,
	short_name => $name,
	title => as_uni2($it->parse_special('$topic')),
	#notify => ...,
	local_variables => \%lv,
    }
}

sub wee_line_collect {
    my $line = shift;
    my $time = $line->{info}{time};
    my $lv = $line->{info}{level};
    if ($time > 2*time) {
	# logmsg("weird line time:".Irssi::bits2level($line->{info}{level})." "
	# 	   .shortdump($line).$line->get_text(0));
	$time = 0;
	$lv = MSGLEVEL_NEVER;
    }
    return +{
	ref => $line->{_irssi},
	text => as_uni2($line->get_text(1)),
	time => $time,
	level => $lv,
    }
}
sub wee_line_format {
    my $winid = shift;
    for ($_[0]) {
	my $text = $_->{text};
	my $prefix = '';
	my $time = '';
	my $fromnick = \0;
	my $level = $_->{level};
	$text =~ s/((?:$irssi_mumbo2)+)(\cDe)/$2$1/g;
	#if ($S{strip_time}) {
	    my $sf = as_uni2(strftime(teddy_get_S()->{timestamp_render}, localtime $_->{time}));
	    $sf =~ s/((?:$irssi_mumbo2)+)(\cDe)/$2$1/g;
	    if ($text =~ s/^(\Q$sf\E)// or ($sf =~ s/^(\Q$text\E)// && ($text = $sf))) {
		$time = $1;
	    }
	#}
	if ($text =~ s/(.*)\cDe//) {
	    $prefix = $1;
	    # XXX hack
	    my $tmp = $prefix;
	    $tmp =~ s/$irssi_mumbo2//g;
	    if ($tmp =~ /^\s*<?\.*[ &@%+]?([^>]+)>\s*$/) {
		$fromnick = $1;
	    }
	}
	my @tags;
	push @tags, 'notify_message' if $level & MSGLEVEL_PUBLIC;
	push @tags, 'notify_private' if $level & (MSGLEVEL_MSGS|MSGLEVEL_DCCMSGS);
	push @tags, 'notify_none' if $level & MSGLEVEL_NO_ACT;
	push @tags, "lv_\L$_" for split ' ', Irssi::bits2level($level);
	return +{
	    date => strftime('%Y-%m-%dT%H:%M:%SZ', gmtime $_->{time}),
	    strtime => $time,
	    prefix => $prefix,
	    fromnick => $fromnick,
	    message => $text,
	    highlight => 0+!!($level & MSGLEVEL_HILIGHT),
	    buffer => $winid,
	    pointers => [ $_->{ref} ],
	    displayed => 1,
	    tags_array => \@tags,
	   }
    }
}

1;
