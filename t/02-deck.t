# inspired by:
use strict;
use Test::More;
use Test::Exception;
use Path::Tiny;
use Ouch;
use 5.020;
use experimental qw< postderef >;
no warnings qw< experimental::postderef >;

use Ordeal::Model;

my $dir = path(__FILE__)->parent->child('ordeal-data');
my $model = Ordeal::Model->new(base_directory => $dir->absolute);

isa_ok $model, 'Ordeal::Model';

throws_ok { $model->get_deck('mah') } qr{invalid identifier},
   'invalid identifier';
throws_ok { $model->get_deck('inexistent-1-ciao') } qr{not found},
   'inexistent identifier';

my $deck;
lives_ok { $deck = $model->get_deck('group1-02-all') }
   'valid deck is found';

is $deck->name, 'all', 'deck name';
is $deck->id, 'group1-02-all', 'deck id';
is $deck->group, 'group1', 'deck group';
is scalar($deck->cards->@*), 5, 'cards in loaded deck';

is_deeply [ map {$_->id} $deck->cards->@* ],
   [
      qw<
         group1-01-whatevah.png
         group1-02-whateeeevah.jpg
         group1-03-wtf.svg
         public-00-bah.png
         public-01-bleh.png
      >
   ], 'cards in expected order';



done_testing;
