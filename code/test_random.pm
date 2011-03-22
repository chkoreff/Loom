use strict;
use random_stream;

=pod

=head1 NAME

Test the random number generator using all zeroes as an entropy source.

=cut

my $g_test_random;
my $g_trace_test_random = 0;

sub test_random_run
	{
	print "Test_random numbers.\n" if $g_trace_test_random;

	$g_test_random = random_new("/dev/zero");

	my $result = "";

	for (1 .. 64)
		{
		my $rand = random_get($g_test_random);

		die if $rand eq "";
		$result .= unpack("H*",$rand)."\n";
		print unpack("H*",$rand)."\n" if $g_trace_test_random;
		}

	my $expected = <<EOM;
66e94bd4ef8a2c3b884cfa59ca342b2e
f795bd4a52e29ed713d313fa20e98dbc
a10cf66d0fddf3405370b4bf8df5bfb3
47c78395e0d8ae2194da0a90abc9888a
94ee48f6c78fcd518a941c3896102cb1
14f84f5e0315a24ca4c05f6e92dbdd25
a7087ae94735e1f83c081c5920fb9817
35428e2b267fb599f74df415cf6fd12e
a2062626acdce7cf4768240efa404483
07e1f45d5347a0fec06e4ef89d9863b8
2c27fa3ad540dadbe6c3e4fb8553fb78
5dbd8f4c1a049c8885ec3c56461a6ef5
2572c5fd84764ce9986d3582c36b6424
bfa9c4aa3abeab8e3d59248dd6b5634b
2d4e7695a8457382d0b0ce402a75ca1a
3d9cbdd2343af3bd8938fcd40047b92f
fa95304e9158b6ea8b21bbafa3e554cf
2075686ddb2ab2762cd81e9985452f00
670dde42da8a38c3efd75775a0654bf4
4b5212fc9b81eaa62c26c1bb32578c72
77640a8856a2eebe299a560aec9b429c
90f8bdb523243f49ef31c634eba9860a
0750f6ef79e5fd21cf34ef8f466e75cd
f8c3f41f28304ca9219c56863e6520f2
f914901c174c3d98dac40c0aae2fa31b
ea797b45cc128eabe99eb55197a20f7c
a83bf4ef15cd89c0ba38aa7ad738a933
6ffe9215bdf060a9e8f998e053619a11
b2ac86295e34ab2e0bb99bf1ba638ad5
d25912b67b2bed3525d43f7487e14a34
fbf7da0bf398e150a28b2a2c2cc28354
076ab6e0950b2bb3d6d35d4fcc2faf6a
0564c73d265894ee126ba2a80957b5e2
98ce09a66ee8d02d643ec9087b9b0441
a0a42f44f85d9214509770c5a1ce947b
4e3b2537d293280e4dba7409b77065e9
3e7ff816d299c3141190bafe4cb1b468
36d0af0781b8e98e2a4984dec9648102
dbb4c84aa92169f86a494d0b734c7e30
859b7dba7d0270d284da1fa67b2c8c05
d3db4c06c55a1cd55eaba9cf43190f97
7cf9a9444b347c75dcbb4240ca067cbf
5b791165baed4cf7be85151d9b76e8e7
16139922d816d3452561e78f589bc677
74803a6ea2a06c27604655fc8218137f
fab4f5f58e70d8aca7d4d14354499024
f7c735b722c92e4c896f7545685c5547
2f48ac2068d02a84a216deeb3ede0561
db3d0e14fefd6ca32381b344df53df2e
d07eb0e34b0755c98fe41931c957665c
9344d597b22f00496633f801d95adae3
a99287630dbb0b9a9b8702fef1edbd77
c8abdb6db8b3af2098bb6199a8bd83ec
b9bef6ae393277708032c52868ed46fe
6fe37486ff8cf37ceef9748574edf651
7da527afc6a71e904c66b9e7a44e1023
4f7bb1efcc3532aaa4b6dc752d8d84bb
03188c9d5810d952f7193f2d3185d1b7
8fdaa48cbf605f7af052e51e53c5c1c2
7637f086ebbb8fd8916f0a02f813325f
e3db8f9e086029e8179a971d6bd9b482
888cca7f776b570bb46628962e35c2b1
115a7e59a524c9501e035218b6989130
447622fca55cc806b43edcf75c01df32
EOM

	if ($result ne $expected)
		{
		print STDERR "!!! Random number test failed!\n";
		die;
		}

	print "Random number test succeeded.\n" if $g_trace_test_random;

	# LATER perhaps clean up after some other tests as well.
	$g_test_random = undef;

	return;
	}

return 1;
