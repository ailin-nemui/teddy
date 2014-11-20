# mock-Irssi by Axel Eirola ( https://github.com/aeirola )
package Irssi::Query;
use strict; use warnings;
use parent 'Irssi::Windowitem';

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	my %args = @_;
	$self->{type} = 'QUERY';
	return $self;
}

1;
