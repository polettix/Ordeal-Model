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

throws_ok { $model->get_shuffled_deck('mah') } qr{invalid identifier},
   'invalid identifier';
throws_ok { $model->get_shuffled_deck('inexistent-1-ciao') } qr{not found},
   'inexistent identifier';

my $shuffled;
lives_ok { $shuffled = $model->get_shuffled_deck('group1-02-all', seed => 9111972) }
   'valid deck is found and shuffled';
isa_ok $shuffled, 'CODE';

my @got;
while (my $card = $shuffled->()) {
   push @got, $card;
}
is scalar(@got), 5, 'cards in shuffled deck';

my @shuffled = $model->get_shuffled_deck('group1-02-all', seed => 9111972);
is scalar(@shuffled), 5, 'same number of cards in list invocation';

@got = map {$_->id} @got;
@shuffled = map {$_->id} @shuffled;
is_deeply \@shuffled, \@got, 'same result with same seed';

is_deeply \@got,
   [
      qw<
         group1-02-whateeeevah.jpg
         public-00-bah.png
         public-01-bleh.png
         group1-01-whatevah.png
         group1-03-wtf.svg
      >
   ], 'cards in expected order';

done_testing;
