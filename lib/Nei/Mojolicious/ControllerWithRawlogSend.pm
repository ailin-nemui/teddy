package Nei::Mojolicious::ControllerWithRawlogSend;
use strict;
use warnings;
no warnings 'redefine';
our @ISA = 'Mojolicious::Controller';
sub send {
    my $self = shift;
    if ($self->{rawlog_on} && ${$self->{rawlog_on}}
	    && (my $rawlog = caller->can('ipw_rawlog_send')) && $_[0]{json}) {
	$self->$rawlog($_[0]{json});
    }
    return $self->SUPER::send(@_);
}
1;
