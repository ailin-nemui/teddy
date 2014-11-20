# mock-Irssi by Axel Eirola ( https://github.com/aeirola )
package Irssi::Channel;
use strict; use warnings;
use parent 'Irssi::Windowitem';

use Irssi::Nick;

sub new {
	my $class = shift;
	my $self = $class->SUPER::new(@_);

	my %args = @_;
	$self->{type} = 'CHANNEL';
	$self->{topic} = $args{topic};

	my @nicknames = map { Irssi::Nick->new('nick' => $_) } @{$args{nicks}};
	$self->{__nicknames} = \@nicknames;

	return $self;
}

sub nicks {
	return @{shift->{__nicknames}};
}

sub nick_find {
    my $self = shift;
    my ($nick) = grep { $_->{nick} eq $_[0] } @{$self->{__nicknames}};
    $nick
}

1;
