requires 'perl', '5.020000';

requires 'Log::Any',   '1.705';
requires 'Ouch',       '0.0500';
requires 'Mo',         '0.40';
requires 'Path::Tiny', '0.084';

on test => sub {
   requires 'Path::Tiny',      '0.084';
   requires 'Test::Exception', '0.43';
   requires 'Try::Tiny',       '0.24';
};

on develop => sub {
   requires 'Path::Tiny',      '0.084';
   requires 'Template::Perlish',   '1.52';
};
