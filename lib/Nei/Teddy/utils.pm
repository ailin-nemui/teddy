use strict;
use warnings;
our %IRSSI;

# common prefixes
sub setc () { $IRSSI{name} }
sub set ($) { 'ipw_' . $_[0] }
sub thm ($) { setc . '_' . $_[0] }

sub logmsg {
  my $msg = shift;
  Irssi::printformat(MSGLEVEL_CLIENTCRAP, setc(), $msg);
  #print STDERR "\r\e[1mteddy\e[22m $msg\r\n";
}

sub shortdump {
    use Data::Dumper;
    local $Data::Dumper::Indent = 0;
    local $Data::Dumper::Quotekeys = 0;
    local $Data::Dumper::Sortkeys = 1;
    local $Data::Dumper::Useqq = 1;
    local $Data::Dumper::Terse = 1;
    local $Data::Dumper::Varname = '';
    local $Data::Dumper::Pair = ':';
    Dumper(+shift)
}

sub dispatch_table {
    my ($table, $cmd, $error, @args) = @_;
    my $r;
    if (exists $table->{$cmd}) {
	$r = $table->{$cmd}->(@args, $cmd);
    }
    else {
	logmsg("unknown command: $error ".shortdump($args[1]));
    }
    return $r;
}

sub mojo_reload {
    for (grep /^M?ojo/, sort keys %INC) {
	s,/,::,g;
	s,\.pm\z,,;
	eval "use again $_"
    }
}


1;
