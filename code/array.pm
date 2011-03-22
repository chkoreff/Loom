use strict;

sub shuffle
	{
	my $array = shift;

	my $i;
	for ($i = @$array; --$i;)
		{
		my $j = int rand($i+1);
		next if $i == $j;
		@$array[$i,$j] = @$array[$j,$i];
		}

	return;
	}

sub intersect
	{
	my $list_x = shift;
	my $list_y = shift;

	my $pos_x = 0;
	my $pos_y = 0;

	my $list_z = [];

	while ($pos_x <= $#$list_x && $pos_y <= $#$list_y)
		{
		my $item_x = $list_x->[$pos_x];
		my $item_y = $list_y->[$pos_y];

		my $cmp = lc($item_x) cmp lc($item_y);

		if ($cmp < 0)
			{
			$pos_x++;
			}
		elsif ($cmp == 0)
			{
			push @$list_z, $item_x;
			$pos_x++;
			$pos_y++;
			}
		else
			{
			$pos_y++;
			}
		}

	return $list_z;
	}

# Case-insensitive sort.
sub sort_names
	{
	return sort { lc($a) cmp lc($b) } @_;
	}

return 1;
