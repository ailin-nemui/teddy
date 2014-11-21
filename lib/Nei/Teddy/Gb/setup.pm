use strict;
use warnings;

sub gb_setup_changed_pre {
    my ($S, $old_S, $need_restart) = @_;
    $S->{docroot}   = Irssi::settings_get_str( set 'docroot');
    $S->{dehilight} = Irssi::settings_get_bool(set 'dehilight');
    $S->{xform}	    = Irssi::settings_get_str( set 'custom_xform');
    push @$need_restart, 'docroot';
    return;
}

sub gb_setup_changed {
    my $old_S = shift;
    if (($old_S->{xform}//'') ne teddy_get_S()->{xform}) {
	if (teddy_get_S()->{xform} !~ /\S/) {
	    gb_custom_xform() = undef;
	}
	else {
	    my $script_pkg = __PACKAGE__ . '::custom_xform';
	    local $@;
	    my $xform = teddy_get_S()->{xform};
	    gb_custom_xform() = eval qq{
package $script_pkg;
use strict;
no warnings;
our (\$QUERY, \$CHANNEL, \$TAG);
return sub {
# line 1 @{[ set 'custom_xform' ]}\n$xform}};
	    if ($@) {
		$@ =~ /^(.*)/;
		print '%_'.(set 'custom_xform').'%_ did not compile: '.$1;
	    }
	}
    }
    return;
}

sub gb_init {
    Irssi::settings_add_str( setc, set 'docroot'
     => File::Spec->catdir(dirname(abs_path(+ScriptFile)),
                           'client'));
    Irssi::settings_add_bool(setc, set 'dehilight'    => 1);
    Irssi::settings_add_str( setc, set 'custom_xform' => '');
}

1;
