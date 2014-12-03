use strict;
use warnings;
our %core;

my $daemon;

sub start_server {
    # Mojo likes to spew, this makes irssi mostly unsuable
    app->mode('production');
    app->log->level('fatal');

    if (exists teddy_get_S()->{docroot}) {
	app->static->paths->[0] = teddy_get_S()->{docroot};
    }
    else {
	@{app->static->paths}=();
    }

    my $scheme = teddy_get_S()->{ssl} ? 'https' : 'http';
    my @args = (do { local $@; my $o = eval { Socket::SO_REUSEPORT }; $@ ? () : 'reuse=1' });
    if (teddy_get_S()->{ssl} && -e teddy_get_S()->{cert} && -e teddy_get_S()->{key}) {
	push @args, "cert=".teddy_get_S()->{cert}, "key=".teddy_get_S()->{key};
    }
    my @listen_urls = map { "$scheme://$_:".teddy_get_S()->{port} } split ' ', teddy_get_S()->{host};
    #logmsg("listen on @listen_urls");
    $_ .= '?'.(join '&', @args) for @listen_urls;

    local $@;
    eval {
	$daemon = Mojo::Server::Daemon->new(app => app, listen => \@listen_urls);
	logmsg('');
	$daemon->start;
    };
    if ($@) {
	my $err = $@;
	$daemon = undef;
	$err =~ s/ at .*?\n?$//;
	print $err;
    }
}

sub teddy_server_stop {
    $daemon = undef;
}

sub teddy_server_cmd_stop {
    if ($daemon) {
	teddy_server_stop();
	logmsg('server stopped');
    }
    teddy_get_S()->{stopped} = 1;
}

sub ws_client_disconnect {
    my $client = shift;
    remove_client_signals($client);
    Irssi::timeout_remove(delete $client->{ping})
	    if defined $client->{ping};
    ipw_rawlog_record($client, [_ => 'disconnected', time, $client->tx->remote_address]);
    @{teddy_all_clients()} = grep { defined && $_ != $client } @{teddy_all_clients()};
    Irssi::signal_emit('ipw client disconnected', $client->{rawlog_id} // 0);
    Irssi::printformat(MSGLEVEL_CLIENTCRAP,
		       thm 'client_disconnected', $client->tx->remote_address, $client->{rawlog_id} // 0);
}

sub ws_client_connect {
    my $client = shift;
    bless $client => 'Nei::Mojolicious::ControllerWithRawlogSend';
    $client->tx->with_compression;
    $client->{connect_time} = time;
    $client->{rawlog_on} = \(my $x = teddy_rawlog_on());
    my ($lastid) = sort { $b <=> $a } 0, map { $_->{rawlog_id} } grep { defined } @{teddy_all_clients()};
    $client->{rawlog_id} = ++$lastid;
    Irssi::printformat(MSGLEVEL_CLIENTCRAP,
		      thm 'client_connected', $client->tx->remote_address, $client->{rawlog_id});
    ipw_rawlog_record($client, [_ => 'connected', $client->{connect_time}, $client->tx->remote_address]);
    $client->on(json => sub {
		    &ipw_rawlog_recv;
		    &handle_message;
		});
    $client->on(finish => \&ws_client_disconnect);
    Irssi::signal_emit('ipw client connected', $client->tx->remote_address, $client->{rawlog_id});
    weaken $client;
    push @{teddy_all_clients()}, $client;
}

websocket '/teddy' => \&ws_client_connect;

sub as_uni {
    my $var = shift;
    Encode::_utf8_on($var);
    $var
}

sub as_uni2 {
    my $var = shift;
    use bytes;
    $var =~ s/\cD#\K(....)/pack 'U*', unpack 'C*', $1/ge;
    Encode::decode_utf8($var, sub{pack 'U', +shift});
}

{ my %pl = do { my $i = 1; map { ( $_ => -$i++ ) } reverse
		    qw(login challenge eval bind disconnect command *) };
  sub _teddy_main_cmd_order_sort {
      ($pl{$a} // 0) <=> ($pl{$b} // 0) || $a cmp $b
  }
}

sub handle_message {
    my ($client, $msg) = @_;
    unless ('HASH' eq ref $msg) {
	logmsg("unknown command: ".shortdump($msg));
	return;
    }
    my $id = delete $msg->{id};
    my %reply;
    for my $cmd (sort _teddy_main_cmd_order_sort keys %$msg) {
	if ($client->{authenticated}) {} #ok
	elsif ($cmd eq 'challenge') {} #ok
	elsif (length $client->{s1} && length $client->{s2} && $cmd eq 'login') {} #ok
	else {
	    return;
	}
	#eval {
	if (my $r = dispatch_table($core{commands}, $cmd, $cmd, $client, $msg->{$cmd})) {
	    $reply{$cmd} = $r;
	    if ($cmd eq 'login' && ref $r && $$r == 1) {
		$reply{$_} = $core{info}{$_}->() for keys %{$core{info}};
	    }
	}
	#}; logmsg($@) if $@;
    }
    return unless $client->{authenticated} or $reply{challenge};
    if (%reply) {
	$reply{id} = $id if defined $id;

	$client->send({ json => \%reply });
    }
}

# hook 'before_dispatch' => sub {
#     my $c = shift;
#     return unless $rawlog_on;
#     $c->tx->on(finish => sub {
# 		   my $tx = shift;
# 		   ipw_rawlog_record($c, [_ => 'website', $tx->remote_address, $tx->req->url->to_string]);
# 	       });
# };

1;
