use strict;
use warnings;
use IrssiX::include;

include 'Nei::Teddy::Gb::setup';
include 'Nei::Teddy::Gb::utils';
include 'Nei::Teddy::Gb::objects';
include 'Nei::Teddy::Gb::input';
include 'Nei::Teddy::Gb::server';
include 'Nei::Teddy::Gb::core';
include 'Nei::Teddy::Gb::signal_handlers';

teddy_register_extension(gb => {
    setup_changed_pre => \&gb_setup_changed_pre,
    setup_changed     => \&gb_setup_changed,
    main_commands     => \&gb_main_get_commands,
    init	      => \&gb_init,
   });

1;
