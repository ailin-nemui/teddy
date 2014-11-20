package Irssi::Theme;
use strict; use warnings;
use Carp;

my %formats = (
    'fe-common/core' => +{
	'timestamp' => '%H:%M',
       },
   );
sub get_format {
    my $self = shift;
    $formats{$_[0]}{$_[1]} // carp "rq get_format @_ not found";
}
sub format_expand {
    my $self = shift;
    if ($_[0] eq '%H:%M') {
	return $_[0];
    }
    croak join ' / ', map { (defined) ? $_ : '[undef]' } @_
}

1;
