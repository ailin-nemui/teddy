package Irssi::Rawlog;
use strict; use warnings;

sub redirect {
    shift;
    print "<-> @_\n";
}
sub input {
    shift;
    print "<<< @_\n";
}
sub output {
    shift;
    print ">>> @_\n";
}
sub destroy {}

1;
