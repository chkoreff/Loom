package page_wallet;
use strict;
use context;
use dttm;
use grid;
use history;
use html;
use http;
use loom_qty;
use page;
use page_folder;

sub handle_history
	{
	if (http::get("set_recording") ne "")
		{
		my $set_recording = http::get("set_recording") ? 1 : "";

		page_folder::put("recording",$set_recording);
		page_folder::save();

		return;
		}

	if (http::get("delete_history_items") ne "")
		{
		for my $name (http::names())
			{
			next unless $name =~ /^choose_(.+)$/;
			my $h_id = $1;
			history::delete_item($h_id);
			}

		page_folder::save();
		return;
		}

	if (http::get("save_history_items") ne "")
		{
		for my $name (http::names())
			{
			next unless $name =~ /^choose_(.+)$/;
			my $h_id = $1;
			history::save_item($h_id,http::get("memo_$h_id"));
			}

		page_folder::save();
		return;
		}

	if (http::get("cancel_history_items") ne "")
		{
		# Do nothing.
		return;
		}

	return;
	}

sub page_folder_main
	{
	my $display = {};
	$display->{flavor} = "move_dialog";

	my $hidden = html::hidden_fields(
		http::slice(qw(function h_pi h_pn h_only session)));

	page::emit(<<EOM
<form method=post action="" autocomplete=off>
$hidden
EOM
);

	page::emit(page_folder::value_table($display)) if !http::get("h_only");

	history::show();

	page::emit(<<EOM
</form>
EOM
);

	return;
	}

sub handle_move_assets
	{
	my $out = page_folder::current_result();

	context::put($out,"status","");
	context::put($out,"error_move","");

	return if http::get("give") eq "" && http::get("take") eq "";

	# Give wins over take.  This can happen if the user just took some assets
	# and then immediately pays something out.  The "take" flag is still set
	# in the query parameters, but the "give" flag is set in the POST.  Our
	# new HTTP parser pays attention to both query parameters *and* body
	# parameters, even in the case of POST.

	http::put("take","") if http::get("give") ne "";

	# Clear the history scroll/edit status.
	http::put("h_pi","");
	http::put("h_pn","");

	my $qty = http::get("qty");
	$qty = html::trimblanks($qty);
	http::put("qty",$qty);

	if ($qty eq "")
		{
		context::put($out,"status","fail");
		context::put($out,"error_move","missing_qty");
		return;
		}

	# We allow a negative quantity in a Pay operation.  Sometimes a user
	# wants to move only a portion of the assets away from a contact point,
	# instead of clicking to take the whole thing.

	my $is_negative_qty = ($qty =~ /^-/);

	my $type_name = http::get("type");
	my $loc_name = http::get("loc");

	my $type = page_folder::map_nickname_to_id("type",$type_name);
	my $loc = page_folder::map_nickname_to_id("loc",$loc_name);

	my $scale = page_folder::get("type_scale.$type");

	$qty = loom_qty::float_to_int($qty,$scale);

	if ($type eq "")
		{
		# This catches when you enter a valid quantity but don't choose an
		# asset type.  Maybe later we can clean this up a bit.

		context::put($out,"status","fail");
		context::put($out,"error_move","Please choose an asset.");
		return;
		}

	if ($qty eq "")
		{
		context::put($out,"status","fail");
		context::put($out,"error_move","invalid_qty");
		return;
		}

	if (http::get("take") ne "")
		{
		$qty = "-$qty";
		$qty = "0" if $qty eq "-0";
		}

	my $loc_folder = page_folder::current_location();

	my $move = grid::move($type,$qty,$loc_folder,$loc);

	if (context::get($move,"status") eq "fail")
		{
		# Move might have failed because one of the locations was vacant
		# (not bought).  Buy the offending location(s) automatically and
		# try the move again.

		my $try_again = 0;

		# LATER could make a little routine out of this
		if (context::get($move,"value_orig") eq "")
			{
			my $buy = grid::buy($type,$loc_folder,$loc_folder);

			if (context::get($buy,"status") eq "fail")
				{
				# Not enough usage tokens in main stash, so try to buy it
				# with usage tokens at the destination.

				grid::buy($type,$loc_folder,$loc);
				}

			$try_again = 1;
			}

		if (context::get($move,"value_dest") eq "")
			{
			my $buy = grid::buy($type,$loc,$loc_folder);

			if (context::get($buy,"status") eq "fail")
				{
				# Not enough usage tokens in main stash, so try to buy it
				# with usage tokens at the destination.

				grid::buy($type,$loc,$loc);
				}

			$try_again = 1;
			}

		if ($try_again)
			{
			$move = grid::move($type,$qty,$loc_folder,$loc);
			}
		}

	my $status = context::get($move,"status");
	context::put($out,"status",$status);

	if ($status eq "fail")
		{
		if (context::get($out,"error_move") eq "")
			{
			my $error_type = context::get($move,"error_type");
			if ($error_type eq "")
				{
				}
			elsif ($error_type eq "not_valid_id")
				{
				context::put($out,"error_move","Please choose an asset.");
				}
			}

		if (context::get($out,"error_move") eq "")
			{
			my $error_qty = context::get($move,"error_qty");
			if ($error_qty eq "")
				{
				}
			elsif ($error_qty eq "not_valid_int")
				{
				if ($qty eq "")
					{
					context::put($out,"error_move","Please enter a quantity.");
					}
				else
					{
					context::put($out,"error_move","Not a valid quantity");
					}
				}
			elsif ($error_qty eq "insufficient")
				{
				if (http::get("give") ne "")
					{
					if ($is_negative_qty)
						{
						context::put($out,"error_move",
						"You cannot take more assets from the contact point "
						."than are actually there.");
						}
					else
						{
						context::put($out,"error_move",
						"You cannot pay more assets to the contact point "
						."than you actually have.");
						}
					}
				else
					{
					http::put("qty","");
					context::put($out,"error_move",
					"Some assets have been taken from the contact point "
					."since you last refreshed your Wallet display.");
					}
				}
			}

		if (context::get($out,"error_move") eq "")
			{
			my $error_dest = context::get($move,"error_dest");
			if ($error_dest eq "")
				{
				}
			elsif ($error_dest eq "not_valid_id")
				{
				context::put($out,"error_move","Please choose a contact.");
				}
			}
		}

	if ($status eq "success")
		{
		# LATER we don't use these colors anymore -- red is too alarming.
		my $orig_color = "green";  # green-ish
		my $dest_color = "red";  # red-ish

		if (http::get("give") ne "")
			{
			# swap colors
			($orig_color,$dest_color) = ($dest_color,$orig_color);
			}

		context::put($out,"color.$type.$loc_folder",$orig_color);
		context::put($out,"color.$type.$loc",$dest_color);

		if (page_folder::get("recording"))
			{
			history::add_item($qty,$type,$loc);
			page_folder::save();
			}

		if (http::get("give") ne "")
			{
			if (!$is_negative_qty)
				{
				# Clear the qty field to avoid paying again if user presses
				# Enter.
				http::put("qty","");
				}
			else
				{
				# On a negative Pay, flip the quantity to positive so it's
				# easy to pay it right back out.
				http::put("qty",substr(http::get("qty"),1));
				}
			}
		}
	}

sub help_wallet
	{
	page::printer_friendly() if http::get("print");

	page::emit(<<EOM
<h1> How the wallet display is organized </h1>
Your wallet display consists of four sections:

<ul>
<li> A dialog box for making payments
<li> The assets in your wallet
<li> Any assets in transit between you and your contacts
<li> Your personal transaction history
</ul>

<h1> Paying an asset to a contact </h1>
<ul>
<li> Enter the quantity into the text box labeled "Quantity".
<li> Choose the asset in the drop-down menu.
<li> Choose the contact in the drop-down menu.
<li> Press <b>Pay</b>
</ul>
<p>
You will see the asset move out of your wallet and down to the designated
contact point.  The asset will remain at that contact point until the other
party takes them, or you take them back, whichever comes first.

<h1> Taking an asset from a contact </h1>

When a contact pays <em>you</em> something, you will see the assets sitting at
the contact point.  You will need to <em>take</em> the assets away from the
contact point and into your wallet.  Only then do those assets become fully
your property.  If you don't take them, the contact could take them back.

<p>
To take the asset, click the asset name at the contact point.  You will see the
asset move away from the contact point and into your wallet.

<h1> Making a payment in a shopping cart </h1>

We recommend that you create a contact point for each of your favorite
merchants.  When you shop at a merchant's web site and go to the checkout
form, it will tell you the total amount required.  It will also display a
field where you can paste in a Loom <b>ID</b> which has the required amount.

<p>
So, in a separate window, login into your Loom wallet and pay the required
amount to that merchant's contact point.  Then, to get the <b>ID</b> number,
click the contact name in the gray bar.  Copy the <b>ID</b> number, using
either Ctrl-C or Right-click/Copy, and then Paste it into the merchant's
web form.  Then press the merchant's Pay button, and the merchant site
will debit the required amount from the <b>ID</b> you pasted in.

<p>
Quite simply, the <b>ID</b> of the merchant contact point acts like a
"debit card" with that particular merchant.  You "fund" the debit card in your
Loom wallet, and then copy and paste the debit card number into the merchant's
web form.  It is very much like using a normal debit or credit card in a
traditional shopping cart, except that a Loom <b>ID</b> can be funded with
<em>exactly</em> the amount you intend to pay, and there is no possibility of
overcharging or identity theft like you might have with a credit card.


<h1> Using history </h1>
<p>
You may enable or disable history as you wish.  Note that <em>only you</em>
can see your history records, and you can delete records any time you like.
<p>
If you enable history, the system will record your transactions and display
them in reverse chronological order, with the most recent entries at the top
of the list.  Each transaction record will show the date, time, quantity,
asset, and contact.  When you take an asset for yourself, the quantity will
be positive and colored green.  When you pay an asset to a contact, the
quantity will be negative and colored red.
<p>
If you hover over a date-time stamp in your history, you will notice that it
shows up as a link.  If you click that link, you can add a memo to the
transaction to help you remember what it was about.  You can even add long
multi-line memos, for example you could enter the entire details of an order
including a customer's full shipping address.  Again, <em>only you</em>
can see this memo.  You can edit the memo later if you like, for example to
add a tracking number for shipping.  You can even delete the entire memo by
simply clearing it out.  Later, you can delete the entire transaction from your
history altogether.  This will save space and refund valuable usage tokens
to you!
<p>
If you disable history, the history display is hidden and no records are kept
as you move assets around.  All your old records are still there, but the
system does not display them or add any new records while history is disabled.
You can easily enable history again with a single click.
EOM
);
	return;
	}

sub respond
	{
	if (http::get("help"))
		{
		help_wallet();
		return;
		}

	handle_move_assets();
	handle_history();
	page_folder_main();

	return;
	}

return 1;
