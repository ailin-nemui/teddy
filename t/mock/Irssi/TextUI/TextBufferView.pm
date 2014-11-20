# mock-Irssi by Axel Eirola ( https://github.com/aeirola )
package Irssi::TextUI::TextBufferView;
# https://github.com/shabble/irssi-docs/wiki/TextBufferView
# https://github.com/shabble/irssi-docs/blob/master/Irssi/TextUI/TextBufferView.pod

use strict; use warnings;
use Scalar::Util qw(weaken refaddr);
use Irssi::TextUI::TextBuffer;

sub remove_line {
    my $self = shift;
    my $buffer = $self->{buffer};
    my $line = $buffer->{cur_line};
    while ($line) {
	if ($line == $_[0]) {
	    my $prev_line = $line->prev;
	    my $next_line = $line->next;
	    if (defined $prev_line) {
		$prev_line->{__next} = $next_line;
		weaken $prev_line->{__next};
	    }
	    if (defined $next_line) {
		$next_line->{__prev} = $prev_line;
	    }
	    if ($buffer->{cur_line} == $line) {
		$buffer->{cur_line} = $next_line // $prev_line;
	    }
	    last;
	}
	$line = $line->prev;
    }
}

sub new {
	my $class = shift;
	my %args = @_;
	my $buffer = Irssi::TextUI::TextBuffer->new('lines' => $args{lines});
	my $self = bless {
		buffer => $buffer
	       }, $class;
	$self->{_irssi} = refaddr $self;
	return $self;
}

1;
