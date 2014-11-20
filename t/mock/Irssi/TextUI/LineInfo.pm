# mock-Irssi by Axel Eirola ( https://github.com/aeirola )
package Irssi::TextUI::LineInfo;
# https://github.com/shabble/irssi-docs/wiki/LineInfo
# https://github.com/shabble/irssi-docs/blob/master/Irssi/TextUI/LineInfo.pod

use strict; use warnings;
use Scalar::Util 'refaddr';

sub new {
	my $class = shift;
	my %args = @_;

	my $self = bless {
		time => $args{time} || 1
	       }, $class;
	$self->{_irssi} = refaddr $self;
	return $self;
}

1;
