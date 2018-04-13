use strict;
use Test::More;
use Test::Exception;
use Path::Tiny;
use Ouch;
use 5.020;
use experimental qw< postderef >;
no warnings qw< experimental::postderef >;

use Ordeal::Model;
use Ordeal::Model::Backend::PlainFile;
use Ordeal::Model::ChaCha20;
use Ordeal::Model::Shuffler;

my $dir   = path(__FILE__)->parent->child('ordeal-data');
my $model = Ordeal::Model->new(
   backend => Ordeal::Model::Backend::PlainFile->new(
      base_directory => $dir->absolute
   )
);
my $random_source = Ordeal::Model::ChaCha20->new(seed => 19721109);

throws_ok { Ordeal::Model::Shuffler->new->evaluate('whatever') }
qr{model}i, 'no model no party';

throws_ok { Ordeal::Model::Shuffler->new->parse('inv-*alid') }
qr{unknown sequence}, 'invalid expression for parsing';

my $shuffler;
lives_ok {
   $shuffler = Ordeal::Model::Shuffler->new(
      model         => $model,
      random_source => $random_source,
   );
} ## end lives_ok
'constructor of a new shuffler';

isa_ok $shuffler, 'Ordeal::Model::Shuffler';

my $ast;
lives_ok {
   $ast = $shuffler->parse('3 * (blah + bleh@)![0..{1..{5..9,11}}] x 2');
}
'parse into abstract syntax tree';

my $expected_ast = [
   'replicate',
   [
      'repeat',
      [
         'slice',
         [
            'sort',
            ['sum', ['resolve', 'blah'], ['shuffle', ['resolve', 'bleh']]]
         ],
         [
            'range', '0',
            [
               'random',
               ['range', '1', ['random', ['range', '5', '9'], '11']]
            ]
         ]
      ],
      '3'
   ],
   '2'
];
is_deeply $ast, $expected_ast, 'parsed as expected';

throws_ok { $shuffler->evaluate($ast) } qr{not found},
  'cannot resolve deck';

lives_ok {
   $ast = $shuffler->parse('
      "group2-01-all"![0] + "group1-02-all"@[0] + "group1-01-public"![0]
   ');
}
'other parsing';

$expected_ast = [
   'sum',
   [
      'sum',
      ['slice', ['sort',    ['resolve', 'group2-01-all']], '0'],
      ['slice', ['shuffle', ['resolve', 'group1-02-all']], '0']
   ],
   ['slice', ['sort', ['resolve', 'group1-01-public']], '0']
];
is_deeply $ast, $expected_ast, 'parsed as expected';

my $shuffle;
lives_ok { $shuffle = $shuffler->evaluate($ast) } 'evaluation succeeded';
isa_ok $shuffle, 'Ordeal::Model::Shuffle';

my @cards = $shuffle->draw;    # takes 'em all
is scalar(@cards), 3, 'expecting 3 cards';
isa_ok $cards[0], 'Ordeal::Model::Card';

@cards = map { $_->id } @cards;
is_deeply \@cards,
  [qw< group2-05-bongo.jpg group1-03-wtf.svg public-00-bah.png >],
  'cards as expected';

done_testing();
