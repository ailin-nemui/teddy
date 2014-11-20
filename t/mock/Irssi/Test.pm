package Irssi::Test;
use strict; use warnings;
$ENV{MOJO_REACTOR} = 'Mojo::Reactor::Poll';
my %settings_reg;
my %theme_db;
my %expandos;
my %signals;
my %timers;
my @windows;
my $active_win;

use Irssi;
use Irssi::Windowitem;
use Irssi::Query;
use Irssi::Channel;
use Irssi::Server;
use Irssi::UI::Window;
use Irssi::Theme;
use Irssi::Rawlog;

sub add_window {
    push @windows, $active_win = $_[0];
}

my $starttime = 1000*time;

package Irssi;
use strict; use warnings;
use Carp;
use Storable 'dclone';
use constant +{
MSGLEVEL_HILIGHT     => 0x200000,
MSGLEVEL_NO_ACT	     => 0x2000000,
MSGLEVEL_CLIENTERROR => 0x100000,
MSGLEVEL_CLIENTCRAP  => 0x80000,
MSGLEVEL_NEVER	     => 0x4000000,
MSGLEVEL_PUBLIC	     => 0x4,
MSGLEVEL_QUITS	     => 0x200,
MSGLEVEL_NICKS	     => 0x8000,
MSGLEVEL_LASTLOG     => 0x8000000,
MSGLEVEL_NOTICES     => 0x8,
MSGLEVEL_DCCMSGS     => 0x20000,
MSGLEVEL_ACTIONS     => 0x40,
MSGLEVEL_MSGS	     => 0x2,
   };

sub _settings_add {
    my (undef, $name, $default) = @_;
    $settings_reg{$name}{default} = $default;
    1
}
sub settings_add_str { goto &_settings_add; }
sub settings_add_time { goto &_settings_add; }
sub settings_add_int { goto &_settings_add; }
sub settings_add_bool { goto &_settings_add; }
sub _check_setting {
    unless (exists $settings_reg{$_[0]}) {
	carp "Setting $_[0] not registered";
	return 0;
    }
    1;
}
sub settings_get_time {
    return 0 unless &_check_setting;
    my $name = shift;
    my $time = $settings_reg{$name}{value} // $settings_reg{$name}{default};
    my $num = $time+0;
    return $num if $time =~ /\dms/;
    return $num * 1000 if $time =~ /\ds/;
    return $num * 1000 * 60 if $time =~ /\dm/;
    return $num * 1000 * 60 * 60 if $time =~ /\dh/;
    return $num * 1000 * 60 * 60 * 24 if $time =~ /\dd/;
    return $num
}
sub settings_get_str {
    return '' unless &_check_setting;
    my $name = shift;
    $settings_reg{$name}{value} // $settings_reg{$name}{default};
}
sub settings_get_int {
    return 0 unless &_check_setting;
    my $name = shift;
    0+($settings_reg{$name}{value} // $settings_reg{$name}{default});
}
sub settings_get_bool {
    return !!0 unless &_check_setting;
    my $name = shift;
    !!($settings_reg{$name}{value} // $settings_reg{$name}{default});
}
sub get_irssi_dir {
    "$ENV{HOME}/.irssi-mock-dir"
}
sub expando_create {
    my ($name, $cb, $signals) = @_;
    $expandos{$name} = $cb;
    1
}
sub signal_add {
    my $script = caller;
    my %s;
    if (ref $_[0] ne 'HASH') {
	%s = @_[0..1];
    }
    else {
	%s = %{$_[0]};
    }
    for my $sig (keys %s) {
	push @{$signals{$script}{$sig}}, $s{$sig};
    }
}
sub signal_remove {
    my $script = caller;
    my %s;
    if (ref $_[0] ne 'HASH') {
	%s = @_[0..1];
    }
    else {
	%s = %{$_[0]};
    }
    for my $sig (keys %s) {
	@{$signals{$script}{$sig}} = grep { ref $_ && ref $s{$sig} ?
						$_ == $s{$sig} : $_ eq $s{$sig} }
	    @{$signals{$script}{$sig}};
    }
}
sub signal_add_last { goto &signal_add; }
sub signal_add_first { goto &signal_add; }
sub command { print "running irssi command: @_\n" }
sub command_bind {
    my $script = caller;
    my %s;
    if (ref $_[0] ne 'HASH') {
	%s = @_[0..1];
    }
    else {
	%s = %{$_[0]};
    }
    for my $sig (keys %s) {
	push @{$signals{$script}{"command $sig"}}, $s{$sig};
    }
}

sub signal_emit {
    my ($sig, @args) = @_;
    for my $ns (keys %signals) {
	if (exists $signals{$ns}{$sig}) {
	    my $cbs = $signals{$ns}{$sig};
	    for my $fun (@$cbs) {
		my @dargs = @{dclone \@args};
		local $@;
		eval "
package $ns;
\$fun = \\&{\$fun} unless ref \$fun;
\$fun->(\@dargs)
";
		carp $@ if $@;
	    }
	}
    }
}
sub _expando_get {
    my $name = shift;
    ($expandos{$name} // sub { carp "no such expando: $name" })->();
}
sub printformat {
    my ($level, $theme, @args) = @_;
    my $i = 0;
    print(( join "; ", (( $theme_db{$theme}
			     // ((warn "unknown theme $theme"), '???')),
		       map { '$'.$i++.'='. ((defined) ? $_ : '???') } @args)), "\n");
}
sub print(@) {
    print "@_\n";
}

sub theme_register {
    %theme_db = (%theme_db, @{$_[0]});
    return;
}
sub current_theme {
    bless +{} => 'Irssi::Theme';
}

sub timeout_add_once {
    my ($delay, $cb, $args) = @_;
    my $script = caller;
    push @{$timers{((1000*time-$starttime)+$delay)}}, [$script,$cb,$args];
    Mojo::IOLoop->timer($delay/1000, sub {
			    my $rcb = $cb; my $rargs = $args;
			    my $loop = shift;
			    local $@;
			    eval "package $script; no strict 'refs'; &\$rcb(\$rargs)";
			    die $@ if $@;
			});
    return;
}
sub timeout_add {
    my ($delay, $cb, $args) = @_;
    my $script = caller;
    push @{$timers{((1000*time-$starttime)+$delay)}}, [$script,$cb,$args];
    Mojo::IOLoop->recurring($delay/1000, sub {
				my $rcb = $cb; my $rargs = $args;
				my $loop = shift;
				local $@;
				eval "package $script; no strict 'refs'; &\$rcb(\$rargs)";
				die $@ if $@;
			    });
}
sub timeout_remove {
    Mojo::IOLoop->remove($_[0])
}
sub parse_special {
    my ($str) = @_;
    if ($str eq '$J') { 'mock-0.1' }
    else {
	croak "parse_special: $str";
    }
}
sub windows {
    @windows;
}
sub channels {
    my @ret;
    for my $w (Irssi::windows) {
	for my $i ($w->items) {
	    push @ret, $i if $i->{type} eq 'CHANNEL';
	}
    }
    return @ret;
}
sub rawlog_create {
    bless +{} => 'Irssi::Rawlog';
}
sub active_win {
    $active_win // croak "no window";
}
sub bits2level {
    if (!$_[0]) {
	return 'NONE';
    }
    croak "unknown bits2level: $_[0]"
}

package Irssi::Test;
use strict; use warnings;
1
