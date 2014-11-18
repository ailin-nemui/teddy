use strict;
use warnings;
use IrssiX::include;

include 'Nei::Teddy::Nu::setup';
include 'Nei::Teddy::Nu::utils';
include 'Nei::Teddy::Nu::objects';
include 'Nei::Teddy::Nu::input';
include 'Nei::Teddy::Nu::core';
include 'Nei::Teddy::Nu::signal_handlers';

teddy_register_extension(nu => {
    setup_changed  => \&nu_setup_changed,
    update_formats => \&nu_update_formats,
    main_commands  => \&nu_main_get_commands,
    init	   => \&nu_init,
   });

1;
