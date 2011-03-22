use strict;

use loom_qty;

my $g_trace_test_float = 0;

sub test_format
	{
	my $value = shift;
	my $scale = shift;
	my $min_precision = shift;
	my $expect = shift;

	my $result = ones_complement_float($value,$scale,$min_precision);
	if ($expect ne $result)
		{
		print STDERR <<EOM;
ERROR: test_format
  value $value
  scale $scale
  min_precision $min_precision
  expect $expect
  result $result
EOM
		die;
		}

	return;
	}

sub test_format_all
	{
	test_format("-170141183460469231731687303715884105728","2","0",
		"-1701411834604692317316873037158841057.27");

	test_format("170141183460469231731687303715884105727","2","0",
		"1701411834604692317316873037158841057.27");

	test_format("-1","4","3", "-0.000");
	test_format("-1234501","4","3", "-123.450");
	test_format("-1234501","4","0", "-123.45");
	test_format("1234500","4","3", "123.450");
	test_format("1234500","4","0", "123.45");

	return;
	}

sub test_mul
	{
	my $str_val = shift;
	my $float_factor = shift;
	my $expect = shift;

	my $str_result = multiply_float($str_val,$float_factor);
	my $ok = !defined $expect || $str_result eq $expect;

	my $trace = $g_trace_test_float;
	$trace = 1 if !$ok;

	print <<EOM if $trace;
function             test_mul
str_val              $str_val
float_factor         $float_factor
str_result           $str_result

EOM

	if (!$ok)
	{
	print <<EOM;
expect               $expect

EOM

	my @caller = caller(0);
	die "Bad test result at line $caller[2] in $caller[0]\n";
	}

	return;
	}

sub test_mul_all
	{
	# Test with fairly big positive quantity.
	if (1)
	{
	my $test_val = "123456789012345678901234567890";

	# Negative factor is set to 0.
	test_mul(
		$test_val,
		-0.05,
		"0",
		);

	test_mul(
		$test_val,
		0,
		"0",
		);

	# Factor is 0.817072806887547
	# Truncates to 0.817072806
	test_mul(
		$test_val,
		0.98 ** 10,
		"100873185018067252501806725250",
		);

	# Factor is 1.68e-09.  Truncates to 1e-9.
	test_mul(
		$test_val,
		0.98 ** 1000,
		"123456789012345678901",
		);

	# Factor is exactly 1e-9.
	test_mul(
		$test_val,
		1e-9,
		"123456789012345678901",
		);

	# The factor is 2.83e-18.
	test_mul(
		$test_val,
		0.98 ** 2000,
		"0",
		);

	# The factor is inf, so we truncate to 2e+9.
	test_mul(
		$test_val,
		2.8 ** 1000,
		"170141183460469231731687303715884105727",
		);

	# The factor is about 5.19e+44, so we truncate to 2e+9.
	test_mul(
		$test_val,
		2.8 ** 100,
		"170141183460469231731687303715884105727",
		);

	# Factor is 1174313.450700279
	# Annual growth of 15% compounded for 100 years.
	test_mul(
		$test_val,
		1.15 ** 100,
		"144976967917463943535877394353442762",
		);

	# The factor is 1379012080495.6, so we truncate to 2e+9.
	# Annual growth of 15% compounded for 200 years.  This overflows.
	test_mul(
		$test_val,
		1.15 ** 200,
		"170141183460469231731687303715884105727",
		);

	# Factor is 1272553509.603488683
	# Annual growth of 15% compounded for 150 years.
	test_mul(
		$test_val,
		1.15 ** 150,
		"157105370142037923509049744350747869064",
		);

	# Truncate to 9 decimal places of accuracy.
	test_mul(
		$test_val,
		20.00123456789012345,
		"2469288195924554182592455418256",
		);
	}

	# Test with fairly low negative quantity.
	if (1)
	{
	my $test_val = "-123456789012345678901234567890";

	# Negative factor is set to 0.
	test_mul(
		$test_val,
		-0.05,
		"0",
		);

	test_mul(
		$test_val,
		0,
		"0",
		);

	# Factor is 0.817072806887547
	# Truncates to 0.817072806
	test_mul(
		$test_val,
		0.98 ** 10,
		"-100873185018067252501806725250",
		);

	# Factor is 1.68e-09.  Truncates to 1e-9.
	test_mul(
		$test_val,
		0.98 ** 1000,
		"-123456789012345678901",
		);

	# Factor is exactly 1e-9.
	test_mul(
		$test_val,
		1e-9,
		"-123456789012345678901",
		);

	# The factor is 2.83e-18.
	test_mul(
		$test_val,
		0.98 ** 2000,
		"0",
		);

	# The factor is inf, so we truncate to 2e+9.
	test_mul(
		$test_val,
		2.8 ** 1000,
		"-170141183460469231731687303715884105728",
		);

	# The factor is about 5.19e+44, so we truncate to 2e+9.
	test_mul(
		$test_val,
		2.8 ** 100,
		"-170141183460469231731687303715884105728",
		);

	# Factor is 1174313.450700279
	# Annual growth of 15% compounded for 100 years.
	test_mul(
		$test_val,
		1.15 ** 100,
		"-144976967917463943535877394353442762",
		);

	# The factor is 1379012080495.6, so we truncate to 2e+9.
	# Annual growth of 15% compounded for 200 years.  This overflows.
	test_mul(
		$test_val,
		1.15 ** 200,
		"-170141183460469231731687303715884105728",
		);

	# Factor is 1272553509.603488683
	# Annual growth of 15% compounded for 150 years.
	test_mul(
		$test_val,
		1.15 ** 150,
		"-157105370142037923509049744350747869064",
		);

	# Truncate to 9 decimal places of accuracy.
	test_mul(
		$test_val,
		20.00123456789012345,
		"-2469288195924554182592455418256",
		);
	}

	# Test with zero quantity.
	if (1)
	{
	my $test_val = "0";

	# Negative factor is set to 0.
	test_mul(
		$test_val,
		-0.05,
		"0",
		);

	test_mul(
		$test_val,
		0,
		"0",
		);

	# Factor is 0.817072806887547
	# Truncates to 0.817072806
	test_mul(
		$test_val,
		0.98 ** 10,
		"0",
		);

	# Factor is 1.68e-09.  Truncates to 1e-9.
	test_mul(
		$test_val,
		0.98 ** 1000,
		"0",
		);

	# Factor is exactly 1e-9.
	test_mul(
		$test_val,
		1e-9,
		"0",
		);

	# The factor is 2.83e-18.
	test_mul(
		$test_val,
		0.98 ** 2000,
		"0",
		);

	# The factor is inf, so we truncate to 2e+9.
	test_mul(
		$test_val,
		2.8 ** 1000,
		"0",
		);

	# The factor is about 5.19e+44, so we truncate to 2e+9.
	test_mul(
		$test_val,
		2.8 ** 100,
		"0",
		);

	# Factor is 1174313.450700279
	# Annual growth of 15% compounded for 100 years.
	test_mul(
		$test_val,
		1.15 ** 100,
		"0",
		);

	# The factor is 1379012080495.6, so we truncate to 2e+9.
	# Annual growth of 15% compounded for 200 years.  This overflows.
	test_mul(
		$test_val,
		1.15 ** 200,
		"0",
		);

	# Factor is 1272553509.603488683
	# Annual growth of 15% compounded for 150 years.
	test_mul(
		$test_val,
		1.15 ** 150,
		"0",
		);

	# Truncate to 9 decimal places of accuracy.
	test_mul(
		$test_val,
		20.00123456789012345,
		"0",
		);
	}

	# Test with lowest possible negative quantity.
	if (1)
	{
	my $test_val = "-170141183460469231731687303715884105728";

	# Negative factor is set to 0.
	test_mul(
		$test_val,
		-0.05,
		"0",
		);

	test_mul(
		$test_val,
		0,
		"0",
		);

	# Factor is 0.817072806887547
	# Truncates to 0.817072806
	test_mul(
		$test_val,
		0.98 ** 10,
		"-139017734186206385247673984361711653037",
		);

	# Factor is 1.68e-09.  Truncates to 1e-9.
	test_mul(
		$test_val,
		0.98 ** 1000,
		"-170141183460469231731687303715",
		);

	# Factor is exactly 1e-9.
	test_mul(
		$test_val,
		1e-9,
		"-170141183460469231731687303715",
		);

	# The factor is 2.83e-18.
	test_mul(
		$test_val,
		0.98 ** 2000,
		"0",
		);

	# The factor is inf, so we truncate to 2e+9.
	test_mul(
		$test_val,
		2.8 ** 1000,
		"-170141183460469231731687303715884105728",
		);

	# The factor is about 5.19e+44, so we truncate to 2e+9.
	test_mul(
		$test_val,
		2.8 ** 100,
		"-170141183460469231731687303715884105728",
		);

	# Factor is 1174313.450700279
	# Annual growth of 15% compounded for 100 years.
	test_mul(
		$test_val,
		1.15 ** 100,
		"-170141183460469231731687303715884105728",
		);

	# The factor is 1379012080495.6, so we truncate to 2e+9.
	# Annual growth of 15% compounded for 200 years.  This overflows.
	test_mul(
		$test_val,
		1.15 ** 200,
		"-170141183460469231731687303715884105728",
		);

	# Factor is 1272553509.603488683
	# Annual growth of 15% compounded for 150 years.
	test_mul(
		$test_val,
		1.15 ** 150,
		"-170141183460469231731687303715884105728",
		);

	# Truncate to 9 decimal places of accuracy.
	test_mul(
		$test_val,
		20.00123456789012345,
		"-170141183460469231731687303715884105728",
		);
	}

	# Test with highest possible positive quantity.
	if (1)
	{
	my $test_val = "170141183460469231731687303715884105727";

	# Negative factor is set to 0.
	test_mul(
		$test_val,
		-0.05,
		"0",
		);

	test_mul(
		$test_val,
		0,
		"0",
		);

	# Factor is 0.817072806887547
	# Truncates to 0.817072806
	test_mul(
		$test_val,
		0.98 ** 10,
		"139017734186206385247673984361711653037",
		);

	# Factor is 1.68e-09.  Truncates to 1e-9.
	test_mul(
		$test_val,
		0.98 ** 1000,
		"170141183460469231731687303715",
		);

	# Factor is exactly 1e-9.
	test_mul(
		$test_val,
		1e-9,
		"170141183460469231731687303715",
		);

	# The factor is 2.83e-18.
	test_mul(
		$test_val,
		0.98 ** 2000,
		"0",
		);

	# The factor is inf, so we truncate to 2e+9.
	test_mul(
		$test_val,
		2.8 ** 1000,
		"170141183460469231731687303715884105727",
		);

	# The factor is about 5.19e+44, so we truncate to 2e+9.
	test_mul(
		$test_val,
		2.8 ** 100,
		"170141183460469231731687303715884105727",
		);

	# Factor is 1174313.450700279
	# Annual growth of 15% compounded for 100 years.
	test_mul(
		$test_val,
		1.15 ** 100,
		"170141183460469231731687303715884105727",
		);

	# The factor is 1379012080495.6, so we truncate to 2e+9.
	# Annual growth of 15% compounded for 200 years.  This overflows.
	test_mul(
		$test_val,
		1.15 ** 200,
		"170141183460469231731687303715884105727",
		);

	# Factor is 1272553509.603488683
	# Annual growth of 15% compounded for 150 years.
	test_mul(
		$test_val,
		1.15 ** 150,
		"170141183460469231731687303715884105727",
		);

	# Truncate to 9 decimal places of accuracy.
	test_mul(
		$test_val,
		20.00123456789012345,
		"170141183460469231731687303715884105727",
		);
	}

	# Test with an even smaller normal quantity.
	if (1)
	{
	my $test_val = "1234567890";

	# Negative factor is set to 0.
	test_mul(
		$test_val,
		-0.05,
		"0",
		);

	test_mul(
		$test_val,
		0,
		"0",
		);

	# Factor is 0.817072806887547
	# Truncates to 0.817072806
	test_mul(
		$test_val,
		0.98 ** 10,
		"1008731850",
		);

	# Factor is 1.68e-09.  Truncates to 1e-9.
	test_mul(
		$test_val,
		0.98 ** 1000,
		"1",
		);

	# Factor is exactly 1e-9.
	test_mul(
		$test_val,
		1e-9,
		"1",
		);

	# The factor is 2.83e-18.
	test_mul(
		$test_val,
		0.98 ** 2000,
		"0",
		);

	# The factor is inf, so we truncate to 1e12.
	test_mul(
		$test_val,
		2.8 ** 1000,
		"1234567890000000000000"
		);

	# The factor is about 5.19e+44, so we truncate to 1e12.
	test_mul(
		$test_val,
		2.8 ** 100,
		"1234567890000000000000",
		);

	# Factor is 1174313.450700279
	# Annual growth of 15% compounded for 100 years.
	test_mul(
		$test_val,
		1.15 ** 100,
		"1449769679029662",
		);

	# The factor is 1379012080495.6, so we truncate to 1e12.
	# Annual growth of 15% compounded for 200 years.  This overflows.
	test_mul(
		$test_val,
		1.15 ** 200,
		"1234567890000000000000",
		);

	# Factor is 1272553509.603488683
	# Annual growth of 15% compounded for 150 years.
	test_mul(
		$test_val,
		1.15 ** 150,
		"1571053701263273864",
		);

	# Truncate to 9 decimal places of accuracy.
	test_mul(
		$test_val,
		20.00123456789012345,
		"24692881956",
		);
	}

	return;
	}

sub test_float_all
	{
	test_format_all();
	test_mul_all();
	return;
	}

return 1;
