use strict;
use warnings;

sub _iid_or_self {
    my ($obj) = @_;
    ref $obj ? $obj->{_irssi} : $obj
}

## Data structure helpers

sub jbool { $_[0] ? \1 : \0 }

sub kvslice {
    my ($o, @keys, %r) = @_;
    @r{@keys} = @{$o}{@keys};
    %r
}
sub kvslice_bool {
    my ($o, @keys, %r) = @_;
    @r{@keys} = map { jbool($_) } @{$o}{@keys};
    %r
}
sub kvslice_uni2 {
    my ($o, @keys, %r) = @_;
    @r{@keys} = map { as_uni2($_) } @{$o}{@keys};
    %r
}
sub lfilter {
    my $b = shift;
    $b ? @_ : ()
}
sub lfilter_sub {
    my ($b, $s) = @_;
    $b ? $s->() : ()
}

1;
