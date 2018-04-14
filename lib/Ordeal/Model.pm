package Ordeal::Model;

# vim: ts=3 sts=3 sw=3 et ai :

use 5.020;
use strict;
use warnings;
{ our $VERSION = '0.001'; }

use English qw< -no_match_vars >;
use Ouch;
use Mo qw< default >;
use Path::Tiny;
use Scalar::Util qw< blessed >;
use Module::Runtime qw< use_module require_module is_module_name >;

use Ordeal::Model::Shuffler;

use experimental qw< signatures postderef >;
no warnings qw< experimental::signatures experimental::postderef >;

has 'backend';

sub _backend_factory ($package, $name, @args) {
   $name = $package->resolve_backend_name($name);
   return use_module($name)->new(@args);
}

sub _default_backend ($package) {
   require Ordeal::Model::Backend::PlainFile;
   return Ordeal::Model::Backend::PlainFile->new;
}

sub get_card ($self, $id) { return $self->backend->card($id) }
sub get_deck ($self, $id) { return $self->backend->deck($id) }

sub get_shuffled_cards ($self, %args) {
   my $random_source = $args{random_source}
      // do {
         require Ordeal::Model::ChaCha20;
         Ordeal::Model::ChaCha20->new(seed => $args{seed});
      };
   $random_source->restore($args{random_source_state})
      if exists $args{random_source_state};

   my $shuffle = Ordeal::Model::Shuffler->new(
      random_source => $random_source,
      model => $self,
   )->evaluate($args{expression});
   return $shuffle->draw if wantarray;
   return $shuffle;
}

sub new ($package, @rest) {
   my %args = (@_ && ref($_[0])) ? %{$rest[0]} : @rest;
   my $backend;
   if (defined(my $b = $args{backend})) {
      $backend = blessed($b)   ? $args{backend}
        : (ref($b) eq 'ARRAY') ? $package->_backend_factory(@$b)
        :                        ouch 400, 'invalid backend';
   }
   elsif (scalar(keys %args) == 0) {
      $backend = $package->_default_backend;
   }
   elsif (scalar(keys %args) == 1) {
      my ($name, $as) = %args;
      my @args = ref($as) eq 'ARRAY' ? @$as : %$as;
      $backend = $package->_backend_factory($name, @args);
   }
   else {
      ouch 400, 'too many arguments to initialize Model';
   }

   return $package->SUPER::new(backend => $backend);
}

sub resolve_backend_name ($package, $name) {
   $package = ref($package) || $package;
   my $invalid_error = "invalid name '$name' for module resolution";

   # if it has "::" *inside* but does not start with them, use directly
   if (($name =~ s{\A - }{}mxs) || ($name =~ m{\A [^:]+ ::})) {
      is_module_name($name) or ouch 400, $invalid_error;
      return $name;
   }

   # otherwise, remove any leading "::"
   $name =~ s{\A ::}{}mxs;
   is_module_name($name) or ouch 400, $invalid_error;

   # look for classes inside "backend" kind
   my %flag;
   for my $base ($package, __PACKAGE__) {
      next if $flag{$base}++;
      my $class = $base . '::Backend::' . $name;
      eval { require_module($class) } and return $class;
   }

   ouch 400, "cannot resolve '$name' to a backend module package";
}

1;
