#!/usr/bin/env perl

use Test::More;

BEGIN { use_ok( 'NNTP::Portal::Util' ); }
require_ok( 'NNTP::Portal::Util' );

my $util = 'NNTP::Portal::Util';

subtest "glob *", sub {
	like( "comp.lang.c"   , $util->wildmat_re("*lang*"));
	like( "comp.lang.perl", $util->wildmat_re("*lang*"));
	like( "lang.perl"     , $util->wildmat_re("*lang*")  , 'different matches for *');

	like( ""    , $util->wildmat_re("*")     , '* matches empty 0');
	like( "lang", $util->wildmat_re("*lang*"), '* matches empty 1');
};

subtest "glob ?", sub {
	like( "bat"      , $util->wildmat_re("?at"), '? matches single 0');
	like( "cat"      , $util->wildmat_re("?at"), '? matches single 1');
	unlike( "acrobat", $util->wildmat_re("?at"), '? only matches single');
};

subtest "anchor", sub {
	unlike( " cat" , $util->wildmat_re("cat"), 'anchor to start');
	unlike( "cat " , $util->wildmat_re("cat"), 'anchor to end');
	unlike( " cat ", $util->wildmat_re("cat"), 'anchor to both');
};

subtest "character class", sub {
	like( "mat"  , $util->wildmat_re("[mr]at") );
	like( "rat"  , $util->wildmat_re("[mr]at") );
	unlike( "bat", $util->wildmat_re("[mr]at") );

	like( "mat"  , $util->wildmat_re("[rm]at") );
	like( "rat"  , $util->wildmat_re("[rm]at") );
	unlike( "bat", $util->wildmat_re("[rm]at") );

	like( "mat"  , $util->wildmat_re("[m-r]at") );
	like( "pat"  , $util->wildmat_re("[m-r]at") );
	like( "rat"  , $util->wildmat_re("[m-r]at") );
	unlike( "-at", $util->wildmat_re("[m-r]at") );
	unlike( "bat", $util->wildmat_re("[m-r]at") );

	like( "mat"  , $util->wildmat_re("[-rm]at") );
	unlike( "pat", $util->wildmat_re("[-rm]at") );
	like( "rat"  , $util->wildmat_re("[-rm]at") );
	like( "-at"  , $util->wildmat_re("[-rm]at") );
	unlike( "bat", $util->wildmat_re("[-rm]at") );
};

subtest "escaping", sub {
	like( "a*b"   , $util->wildmat_re(q{a\*b}), "escape *");
	unlike( "aa*b", $util->wildmat_re(q{a\*b}), "escape *");

	like( "a?b"   , $util->wildmat_re(q{a\?b}), "escape ?");
	unlike( "a?bb", $util->wildmat_re(q{a\?b}), "escape ?");

	like( "a[b]", $util->wildmat_re(q{a\[b\]})   , "escape [ & ]");
	like( "abb" , $util->wildmat_re(q{a[\]b]b})   , "escape [ & ]");
	like( "a]b" , $util->wildmat_re(q{a[\]b\[]b}), "escape [ & ]");
	like( "a[b" , $util->wildmat_re(q{a[\]b\[]b}), "escape [ & ]");

	like(q/\\/, $util->wildmat_re(q{\\\\}), q{escape backslash (\)});
};

subtest "glob * (call w/o class deref)", sub {
	like( "comp.lang.c"   , NNTP::Portal::Util::wildmat_re("*lang*"));
	like( "comp.lang.perl", NNTP::Portal::Util::wildmat_re("*lang*"));
	like( "lang.perl"     , NNTP::Portal::Util::wildmat_re("*lang*")  , 'different matches for *');

	like( ""    , NNTP::Portal::Util::wildmat_re("*")     , '* matches empty 0');
	like( "lang", NNTP::Portal::Util::wildmat_re("*lang*"), '* matches empty 1');
};

done_testing;
