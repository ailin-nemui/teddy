# mock-Irssi by Axel Eirola ( https://github.com/aeirola )
package Irssi::UI::TextDest;
# https://github.com/shabble/irssi-docs/wiki/TextDest

use strict; use warnings;
use Scalar::Util 'refaddr';

sub new {
	my $class = shift;
	my %args = @_;
	my $self = bless {
			window => $args{window}
		}, $class;
	$self->{_irssi} = refaddr $self;
	return $self;
}

1;

