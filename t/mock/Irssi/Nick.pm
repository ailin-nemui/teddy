# mock-Irssi by Axel Eirola ( https://github.com/aeirola )
package Irssi::Nick;
# https://github.com/shabble/irssi-docs/wiki/Nick
# https://github.com/shabble/irssi-docs/blob/master/Irssi/Nick.pod

use strict; use warnings;
use Scalar::Util 'refaddr';

sub new {
	my $class = shift;
	my %args = @_;
	my $self = bless {
			type => 'NICK',
			nick => $args{nick}
		       }, $class;
	$self->{_irssi} = refaddr $self;
	return $self;
}

1;
