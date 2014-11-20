# mock-Irssi by Axel Eirola ( https://github.com/aeirola )
package Irssi::UI::Window;
# https://github.com/shabble/irssi-docs/wiki/Window

use strict; use warnings;
use Scalar::Util qw(refaddr weaken);
use Carp;
use Irssi::Channel;
use Irssi::Query;
use Irssi::Windowitem;
use Irssi::UI::TextDest;
use Irssi::TextUI::TextBufferView;

sub new {
	my $class = shift;
	my %args = @_;
	my $self = bless {
			refnum => $args{refnum},
			name => $args{name},
			height => $args{height},
		}, $class;

	my $type = $args{type};
	if ($args{_items}) {
	    $self->{__items} = $args{_items};
	    $self->{active} = $self->{__items}[0];
	    weaken $self->{active};
	}

	$self->{__view} = Irssi::TextUI::TextBufferView->new('lines' => $args{lines});
	$self->{__dest} = Irssi::UI::TextDest->new('window' => $self);
	$self->{_irssi} = refaddr $self;
	return $self;
}

sub get_active_name {
	my $self = shift;
	return $self->{active}->{name} || $self->{name}
}

sub view {
	return shift->{__view};
}

sub items {
    @{shift->{__items}//[]}
}
sub last_line_insert {
    shift->{__last_line_insert}
}
sub print_after {
    my $self = shift;
    my $buffer = $self->{__view}{buffer};
    my $line = $buffer->{cur_line};
    my $prev_line = $line ? $line->prev : undef;
    while ($prev_line) {
	$line = $prev_line;
	$prev_line = $line->prev;
    }
    if (!defined $_[0]) {
	$prev_line = Irssi::TextUI::Line->new('time' => $_[3] // time, level => $_[1], 'text' => $_[2], 'prev' => undef);
	if (defined $line) {
	    $line->{__prev} = $prev_line;
	    $prev_line->{__next} = $line;
	    weaken $prev_line->{__next};
	}
	else {
	    $buffer->{cur_line} = $prev_line;
	}
	$self->{__last_line_insert} = $prev_line;
	weaken $self->{__last_line_insert};
    }
    else {
	croak join " / ", @_;
    }
}
sub print {
	my ($self, $text) = @_;
	$self->{__view}->{buffer}->_add_line($text);
	Irssi::signal_emit('print text', ($self->{__dest}, $text, $text));
}

1;
