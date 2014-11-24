package IrssiX::include;
use strict;
use warnings;
use Carp;

sub import {
    no strict 'refs';
    no warnings 'uninitialized';
    *{caller().'::include'} = \&include;
}

sub include (@) {
    @_ == 0 and croak 'Not enough arguments for include';
    @_ >  1 and croak 'Too many arguments for include';
    my $module = shift;
    (my $file = "$module.pm") =~ s[::][/]g;
    delete $INC{$file};
    my $pkg = caller (my $i = 0);
    my $own = __PACKAGE__;
    $pkg = caller ++$i while "::$pkg" =~ /::$own$/;
    eval "package $pkg; require \$file; 1" || die $@;
}

1;
