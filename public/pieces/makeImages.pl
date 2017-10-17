#!/usr/bin/perl
#

use strict;
use MIME::Base64;

my $dir = "/home/corey/pieces";
my $size = shift;

opendir(my $dh, $dir);

my @svgs = grep { /\.svg$/ && -f "$dir/$_" } readdir($dh);
closedir $dh;

my $js = '';

{
$/ = undef;
foreach my $svg (@svgs){
	my $png = $svg;
	$png =~ s/svg$/png/;
	system("convert -background none -density 1200 -resize 200x200 $dir/$svg $dir/$png");
	open my $fh, "<", "$dir/$png";
	my $pngData = <$fh>;
	my $png64 = encode_base64($pngData);
	$png64 =~ s/\n//g;
	my $jsName = $png;
	$jsName =~ s/\.png$//;
	$js .= "
	var $jsName = new Image();
	$jsName.src='data:image/png;base64," . $png64 . "';\n\n";
}
}

open my $jsfh, ">", "$dir/pieces.js";
print $jsfh $js;
close $jsfh;
