<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <meta content="text/html; charset=UTF-8" http-equiv="content-type" />
    <title>FusionInventory-Agent</title>
    <link rel="stylesheet" href="site.css" type="text/css" />
</head>
<body>

<img src="/logo.png" alt="FusionInventory" />
<br />
This is FusionInventory Agent {$version}<br />
The current status is {$status}<br />

{
    if ($trust) {
        $OUT .= '<a href="/now">Force an Inventory</a>';
    } else {
        '';
    }
}

<br />
{
    if (@controllers) {
        $OUT .=  "Next server contact planned for:\n";
        $OUT .=  "<ul>\n";
        foreach my $controller (@controllers) {
           $OUT .= "<li>$controller->{name}: $controller->{date}</li>\n";
        }
        $OUT .=  "</ul>\n";
    } else {
        '';
    }
}

</body>
</html>
