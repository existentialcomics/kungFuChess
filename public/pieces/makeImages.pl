#!/usr/bin/perl
#

use strict;
use MIME::Base64;

my $dir = shift;

opendir(my $dh, $dir);
my @svgs = grep { /\.svg$/ && -f "$dir/$_" } readdir($dh);
closedir $dh;


{
    $/ = undef;
    foreach my $svg (@svgs){
        my $png = $svg;
        $png =~ s/svg$/png/;
        system("convert -background none -density 1200 -resize 200x200 $dir/$svg $dir/$png");
    }
}

my $js = '';
opendir(my $dh, $dir);
my @pngs = grep { /\.png$/ && -f "$dir/$_" } readdir($dh);
closedir $dh;

{
    $/ = undef;
    foreach my $png (@pngs){
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
