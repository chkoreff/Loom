package page_faq;
use strict;
use api;
use context;
use html;
use http;
use loom_config;
use page;
use page_help;

sub links
	{
	page::top_link(page::highlight_link(html::top_url(),"Home"));
	return;
	}

sub respond
	{
	page::set_title("Help");
	links();

	page::emit(<<EOM
<h1> What is Loom? </h1>
<p>
Loom is a system that enables people to transfer ownership of any kind of
asset privately and at will.

<p>
For example, a reputable individual can store gold in a vault and create a
brand new digital asset redeemable for that physical gold.  People who know and
trust that digital asset can add it to their Loom wallets and pay it around
however they like.

<p>
Gold is just one example.  Imagine digital assets directly redeemable for cash,
silver, coffee, oil, copper, electricity, lumber, hours of professional
service, rewards &mdash; the possibilities are endless!

<h1> How do I sign up? </h1>
<p>
First, you should know that using the Loom system is not free.  To use Loom,
you must have an asset called <em>usage tokens</em>.  Loom charges usage tokens
when you store information, and refunds usage tokens when you delete
information.

<p>
So before you can sign up and create a Loom wallet, you need to get an
<em>invitation code</em>, which is a location that contains enough usage
tokens for you to get started.

<h1> Where do I get an invitation? </h1>
<p>
If you know someone who already uses Loom, you can ask them for an invitation.
EOM
);

	return;
	}

return 1;
