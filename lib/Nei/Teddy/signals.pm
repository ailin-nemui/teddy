use strict;
use warnings;

my %signals;

sub generic_signal {
    my ($sig, @args) = @_;
    return unless exists $signals{$sig};
    (my $signame = $sig) =~ s/\s|\W/_/g;
    for my $client (@{$signals{$sig}{clients}}) {
	next unless $client;
	next unless $client->{authenticated};
	next if $client->{SIGNAL_IN_PROGRESS};
	local $client->{SIGNAL_IN_PROGRESS} = 1;
	if ('CODE' eq ref $client->{signal}{$sig}) {
	    if (my $r = $client->{signal}{$sig}->($client, $signame, @{dclone \@args})) {
		$client->send({ json => {
		    $sig => $r
		   } });
	    }
	    next;
	}
    }
}

sub add_signal_binds {
    my ($client, $binds) = @_;
    weaken $client;
    for my $sig (sort keys %$binds) {
	unless ($binds->{$sig}) { # uninstall
	    remove_signal_bind($client, $sig);
	    next;
	}

	unless (exists $signals{$sig}) {
	    my $fun = "gen_handle_$sig";
	    $fun =~ s/\s|\W/_/g;
	    {
		no strict 'refs';
		*$fun = sub {
		    generic_signal($sig, @_)
		};
	    }
	    if ($sig eq 'window created' || $sig eq 'gui print text finished') {
		Irssi::signal_add_last($sig, $fun);
	    }
	    else {
		Irssi::signal_add($sig, $fun);
	    }
	    $signals{$sig}{fun} = $fun;
	}
	push @{$signals{$sig}{clients}}, $client
	    unless grep {
		defined && $_ == $client
	    } @{$signals{$sig}{clients}};
	my $code = $binds->{$sig};
	if (!ref $code) {
	    $code = eval "sub { $code }";
	}
	elsif ('CODE' ne ref $code) {
	    $code = sub {
		$_[0]->send({ json => { $_[1] => $code } })
	    };
	}
	$client->{signal}{$sig} = $code;
    }
    return;
}

sub remove_client_signals {
    my ($client) = @_;
    remove_signal_bind($client, $_) for sort keys %signals;
}

sub remove_signal_bind {
    my ($client, $sig) = @_;
    delete $client->{signal}{$sig};
    return unless exists $signals{$sig};

    @{$signals{$sig}{clients}} = grep {
	defined && $_ != $client
    } @{$signals{$sig}{clients}};

    unless (@{$signals{$sig}{clients}}) {
	my $fun = $signals{$sig}{fun};
	Irssi::signal_remove($sig, $fun);
	delete $signals{$sig};
	no strict 'refs';
	undef &$fun;
    }
}

1;
