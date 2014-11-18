use strict;
use warnings;

my %Extension;

sub teddy_extensions { \%Extension }

sub teddy_register_extension {
    $Extension{$_[0]} = $_[1];
    return;
}

1;
