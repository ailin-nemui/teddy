package Irssi::Server;
use strict; use warnings;

sub new {
    my ($class, %args) = @_;
    bless {
	tag => $args{tag},
       } => $class;
}

sub channel_find {
    my $self = shift;
    for my $w (Irssi::windows) {
	for my $i ($w->items) {
	    return $i if $i->{type} eq 'CHANNEL' && $i->{name} eq $_[0];
	}
    }
    return;
}

1;
