#package main;
package Irssi;
use Carp;
use strict; use warnings;
our $VERSION = 20141224;
sub INPUT_READ;
sub INPUT_WRITE;
sub version ();
sub signal_stop;
sub signal_add { croak "wrong number of arguments" unless @_ == 2 or @_ == 1 && $_[0] =~ /HASH/;
		 if (@_ == 2) { carp "adding signal $_[0] => $_[1]" }
		 else {
		   for my $k (keys %{$_[0]}) {
		     carp "adding signal $k => $_[0]{$k}";
		   }
		 } }
sub command_bind { croak "wrong number of arguments" unless @_ == 2 or @_ == 1 && $_[0] =~ /HASH/;
		 if (@_ == 2) { carp "adding command $_[0] => $_[1]" }
		 else {
		   for my $k (keys %{$_[0]}) {
		     carp "adding command $k => $_[0]{$k}";
		   }
		 } }
sub settings_add_str { croak "wrong number of arguments" unless @_ == 3; carp "adding str. setting $_[1] \[ $_[2] \]" }
sub settings_add_int { croak "wrong number of arguments" unless @_ == 3; carp "adding int. setting $_[1] \[ $_[2] \]" }
sub settings_add_bool { croak "wrong number of arguments" unless @_ == 3; carp "adding bool. setting $_[1] \[ $_[2] \]" }
sub active_win;
sub active_server;
sub windows;
sub command_bind;
sub command { carp "calling Irssi command $_[0]" };
sub commands;
sub servers { my @none = () }
sub channels;
sub theme_register { croak "invalid argument type" unless @_ == 1 and $_[0] =~ /ARRAY/;
		     while (my ($fmt, $arg) = splice @{$_[0]}, 0, 2) {
		       carp "registering theme $fmt => $arg";
		     } }
sub print (@);
sub EXPAND_FLAG_IGNORE_EMPTY;
sub EXPAND_FLAG_IGNORE_REPLACES;
sub get_irssi_dir;
sub MSGLEVEL_HILIGHT ();
sub MSGLEVEL_CRAP ();
sub MSGLEVEL_NO_ACT ();
sub MSGLEVEL_CLIENTERROR ();
sub MSGLEVEL_CLIENTCRAP ();
sub MSGLEVEL_NEVER ();
sub MSGLEVEL_PUBLIC ();
sub MSGLEVEL_QUITS ();
sub MSGLEVEL_NICKS ();
sub MSGLEVEL_LASTLOG ();
sub MSGLEVEL_NOTICES ();
sub MSGLEVEL_DCCMSGS ();
sub MSGLEVEL_ACTIONS ();
sub MSGLEVEL_MSGS ();
sub import {
    no warnings;
    my $pkg = caller;
    my $P = __PACKAGE__;
    eval "package $pkg;
open CLIENTCRAP, '>&', \*STDIN;
*INPUT_READ = \\&${P}::INPUT_READ;
*INPUT_WRITE = \\&${P}::INPUT_WRITE;
*MSGLEVEL_HILIGHT = \\&${P}::MSGLEVEL_HILIGHT;
*MSGLEVEL_NO_ACT = \\&${P}::MSGLEVEL_NO_ACT;
*MSGLEVEL_CLIENTERROR = \\&${P}::MSGLEVEL_CLIENTERROR;
*MSGLEVEL_CRAP = \\&${P}::MSGLEVEL_CRAP;
*MSGLEVEL_CLIENTCRAP = \\&${P}::MSGLEVEL_CLIENTCRAP;
*MSGLEVEL_NEVER = \\&${P}::MSGLEVEL_NEVER;
*MSGLEVEL_PUBLIC = \\&${P}::MSGLEVEL_PUBLIC;
*MSGLEVEL_QUITS = \\&${P}::MSGLEVEL_QUITS;
*MSGLEVEL_NICKS = \\&${P}::MSGLEVEL_NICKS;
*MSGLEVEL_LASTLOG = \\&${P}::MSGLEVEL_LASTLOG;
*MSGLEVEL_NOTICES = \\&${P}::MSGLEVEL_NOTICES;
*MSGLEVEL_DCCMSGS = \\&${P}::MSGLEVEL_DCCMSGS;
*MSGLEVEL_ACTIONS = \\&${P}::MSGLEVEL_ACTIONS;
*MSGLEVEL_MSGS = \\&${P}::MSGLEVEL_MSGS;
1" || die $@;
1
}
1
