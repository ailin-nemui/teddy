use strict;
use warnings;

sub nu_ignore_event { Irssi::signal_stop; }

sub nu_render_timestamp {
    my $win = Irssi::active_win;
    my $view = $win->view;
    my $ts_format = teddy_get_S()->{timestamp_fmt}; #Irssi::settings_get_str('timestamp_format');
    my $render_str = Irssi::current_theme->format_expand(teddy_get_S()->{timestamp_theme});
    #$render_str =~ s/%%/%%%%/g; # this breaks time stamps in the format
    (my $ts_escaped = $ts_format) =~ s/([%\$])/$1$1/g;
    $render_str =~ s/(?|\$(.)(?!\w)|\$\{(\w+)\})/$1 eq 'Z' ? $ts_escaped : $1/ge;
    Irssi::signal_add_first({
	'gui print text after finished' => 'nu_ignore_event',
	'gui textbuffer line removed'	=> 'nu_ignore_event',
       });
    $win->print_after(undef, MSGLEVEL_NEVER, "$render_str*");
    my $lp = $win->last_line_insert;
    my $rendered = $lp->get_text(1);
    $rendered =~ s/\*$//;
    $view->remove_line($lp);
    Irssi::signal_remove('gui print text after finished' => 'nu_ignore_event');
    Irssi::signal_remove('gui textbuffer line removed'	 => 'nu_ignore_event');
    return $rendered;
}

## Setup/config handlers

sub nu_update_formats {
    my $was_theme = teddy_get_S()->{timestamp_theme} // '';
    teddy_get_S()->{timestamp_theme} = Irssi::current_theme->get_format('fe-common/core', 'timestamp');
    if ($was_theme ne teddy_get_S()->{timestamp_theme} && exists teddy_get_S()->{timestamp_fmt}) {
	teddy_get_S()->{timestamp_render} = nu_render_timestamp();
    }
}

sub nu_setup_changed {
    my $old_S = shift;

    if (($old_S->{timestamp_fmt}//'') ne teddy_get_S()->{timestamp_fmt}) {
	teddy_get_S()->{timestamp_render} = nu_render_timestamp();
    }
}

sub nu_init {
    Irssi::settings_add_str( setc, set 'clientdata' => '' );
    Irssi::signal_add({
	'channel joined'    => 'nu_channel_nicklist_tracker',
	'channel destroyed' => 'nu_channel_nicklist_tracker_stop',
    });
    nu_channel_nicklist_tracker($_) for grep { $_->{names_got} } Irssi::channels;

    Irssi::signal_add_last({
	## Extension specific
	'theme changed'  => 'nu_update_formats',
	'command format' => 'nu_update_formats',
    });
}
1;
