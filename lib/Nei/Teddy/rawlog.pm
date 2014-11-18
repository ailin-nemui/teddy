use strict;
use warnings;

my $rawlog_on;
sub teddy_rawlog_on : lvalue { $rawlog_on }

sub ipw_rawlog_record {
    my ($client, $data, $in) = @_;
    return unless $rawlog_on;

    my $cmd = defined $in ? $in ? 'input' : 'output' : 'redirect';
    my $id = $client->{rawlog_id} || 0;
    my $sd = shortdump($data);
    if ('{}' eq $sd) {
	# ignore
	return;
    }

    $rawlog_on->$cmd("$id:$sd");
}

sub ipw_rawlog_send { ipw_rawlog_record(@_[0..1], 0) }
sub ipw_rawlog_recv { ipw_rawlog_record(@_[0..1], 1) }

sub teddy_rawlog_stop {
    $rawlog_on->destroy if $rawlog_on;
    $rawlog_on = undef;
}

1;
