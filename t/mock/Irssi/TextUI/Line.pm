# mock-Irssi by Axel Eirola ( https://github.com/aeirola )
package Irssi::TextUI::Line;
# https://github.com/shabble/irssi-docs/wiki/Line
# https://github.com/shabble/irssi-docs/blob/master/Irssi/TextUI/Line.pod

use strict; use warnings;
use Scalar::Util 'refaddr';
use Irssi::TextUI::LineInfo;

sub new {
	my $class = shift;
	my %args = @_;
	my $info = Irssi::TextUI::LineInfo->new('time' => $args{time});

	my $self = bless {
		info => $info,
		__text => $args{text},
		__next => $args{next},
		__prev => $args{prev},
	    }, $class;
	$self->{_irssi} = refaddr $self;
	return $self;
}


sub get_text {
	return shift->{__text};
}

sub next {
	return shift->{__next};
}

sub prev {
	return shift->{__prev};
}

1;
