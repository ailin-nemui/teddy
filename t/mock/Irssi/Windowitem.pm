# mock-Irssi by Axel Eirola ( https://github.com/aeirola )
package Irssi::Windowitem;
# https://github.com/shabble/irssi-docs/wiki/Windowitem
# https://github.com/shabble/irssi-docs/blob/master/Irssi/Windowitem.pod

use strict; use warnings;
use Scalar::Util 'refaddr';

sub new {
	my $class = shift;
	my %args = @_;
	my $self = bless {
		name => $args{name}
		}, $class;
	$self->{type} = undef;
	$self->{__commands} = [];
	$self->{_irssi} = refaddr $self;
	return $self;
}

sub command {
	my ($self, $command) = @_;
	push(@{$self->{__commands}}, $command);
}

1;
