use strict;
use warnings;

get '/' => sub { shift->reply->static('index.html') };

1;
