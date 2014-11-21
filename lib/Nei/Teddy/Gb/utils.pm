use strict;
use warnings;

sub run_custom_xform {
    local $@;
    eval {
	gb_custom_xform()->()
    };
    if ($@) {
	$@ =~ /^(.*)/;
	print '%_'.(set 'custom_xform').'%_ died (disabling): '.$1;
	gb_custom_xform() = undef;
    }
}

sub remove_uniform {
    my $o = shift;
    $o =~ s/^xmpp:(.*?[%@]).+\.[^.]+$/$1/ or
	$o =~ s#^psyc://.+\.[^.]+/([@~].*)$#$1#;
    if (gb_custom_xform()) {
	run_custom_xform() for $o;
    }
    $o
}

sub remove_uniform_vars {
    my $it = shift;
    no strict 'refs';
    my $name = __PACKAGE__ . '::custom_xform::' . $it->{type}
	if ref $it;
    local ${$name} = 1 if $name;
    remove_uniform(+shift);
}

1;
