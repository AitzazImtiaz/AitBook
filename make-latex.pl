#!/usr/bin/perl -w

#    This file is part of SCIgen.
#
#    SCIgen is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    SCIgen is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with SCIgen; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA


use strict;
use scigen;
use IO::File;
use Getopt::Long;
use IO::Socket;
use JSON;
use WWW::Curl::Easy;


use File::Temp qw/ tempfile tempdir /;


my $class_files = "IEEEtran.cls IEEE.bst";
my @authors;
my $seed;
my $remote = 0;
my $picwank = 0; 
my $title;
my $nsec = ((int rand 50)+4);


sub usage {
    select(STDERR);
    print <<EOUsage;
    
$0 [options]
  Options:
    --help                    Display this help message
    --author <quoted_name>    An author of the paper (can be specified 
                              multiple times)
    --seed <seed>             Seed the prng with this
    --file <file>             Save the postscript in this file
    --tar  <file>             Tar all the files up
    --savedir <dir>           Save the files in a directory; do not latex 
                              or dvips.  Must specify full path
    --remote                  Use a daemon to resolve symbols
    --picwank                 Allow interspersed exciting pics from the 
                              supplied directories 
    --talk                    Make a talk, instead of a paper
    --title <title>           Set the title (useful for talks)
    --sysname <name>          Set the system name
    --save                    Do not automatically delete
    --nsec <nsec>             Number of sections
EOUsage

    exit(1);

}

# Get the user-defined parameters.
# First parse options
my %options;
&GetOptions( \%options, "help|?", "author=s@", "seed=s", "tar=s", "file=s", 
	     "savedir=s", "remote", "picwank", "talk", "title=s", "sysname=s", "save", "nsec=s") or &usage;
if( $options{"help"} ) {
    &usage();
}
if( defined $options{"author"} ) {
    @authors = @{$options{"author"}};
}
if( defined $options{"remote"} ) {
    $remote = 1;
}
if( defined $options{"picwank"} ) {
    $picwank = 1;
}
if( defined $options{"title"} ) {
    $title = $options{"title"};
}
if( defined $options{"nsec"} ) {
    $nsec = $options{"nsec"};
}
if( defined $options{"seed"} ) {
    $seed = $options{"seed"};
} else {
    $seed = int rand 0xffffffff;
}
srand($seed);

my $name_dat = {};
my $name_RE = undef;
my $tex_dat = {};
my $tex_RE = undef;



my $sysname;
if( defined $options{"sysname"} ) {
    $sysname = $options{"sysname"};
} else {
    $sysname = &get_system_name();
}


my $template = "zmakelatexXXXX";
my $tmp_dir = tempdir( ); 
my ($fhtex, $tex_file) = tempfile($template, DIR => $tmp_dir);


sub get_url_contents{
    my $url = $_[0];    
    my $crl = WWW::Curl::Easy->new;
    
    $crl -> setopt(CURLOPT_USERAGENT,'Mozilla/4.0 (compatible; MSIE 7.0; Windows NT 6.1; WOW64; SLCC2; .NET CLR 2.0.50727; .NET CLR 3.5.30729; .NET CLR 3.0.30729; Media Center PC 6.0; MS-RTC LM 8; .NET4.0C; .NET4.0E; InfoPath.3)');
    $crl -> setopt(CURLOPT_URL,$url);
    #$crl -> setopt(CURLOPT_RETURNTRANSFER,1);
    $crl -> setopt(CURLOPT_CONNECTTIMEOUT,5);

    my $ret = $crl->perform;

    return $ret;
}


sub get_images{
    
    #my $json = get_url_contents('http://ajax.googleapis.com/ajax/services/search/images?v=1.0&q=sausages');
    my $json = get_url_contents('https://www.googleapis.com/customsearch/v1');
    
    my $data = decode_json($json);

}

#expand the length arbitrarily by repeating the sections by 'nit' iterations.
my $section; 
my $selector;
my $partbool = 0;
my $bbool = 0;
my $vbool = 0;
my $nit = ($nsec-2)/1.5;
my $sectol = ((int rand 3)*(10) + 1 );
my $btol = ((int rand 2)*(50) + 50 );
my $vtol = (700 + (int rand 20)*(5) );
my $text_tr = "SCIPAPER_LATEX { ";
my $citpen = " 
XXX+50 .
SCI_BY_WHO_SOMETIMES+10 
LATEX_DIAGRAM_MAYBE+3 
LATEX_FIGURE_MAYBE+3 
GANT_MAYBE+10 
PIE_MAYBE+10 
LATEX_DIAGRAM 
LATEX_FIGURE 
";

if($nsec > $vtol ) {
 $text_tr = $text_tr . " WIDE_LATEX_HEADER WIDE_ABSTRACT SCI_TOC SCI_VOL ";
 $vbool = 1;

if($nsec > $btol * (int rand 2) + 100) {
 $text_tr = $text_tr . " SCI_BOOK ";
 $bbool = 1;
 }

 } else { 
     
if($nsec > $btol * (int rand 2) + 100) {
 $text_tr = $text_tr . " WIDE_LATEX_HEADER WIDE_ABSTRACT SCI_TOC SCI_BOOK ";
 $bbool = 1;
 } else { 
     $text_tr = $text_tr . " LATEX_HEADER SCI_ABSTRACT ";
   }

}


if($nit > $sectol * ((int rand 5) + 1) ){

    if($bbool == 0) {
	$text_tr = $text_tr . " SCI_TOC ";
    }

 $text_tr = $text_tr . " SCI_PART ";
 $partbool = 1;
}

if($nit > $sectol && $partbool == 0) {
#can still have a table of contents, even without parts. 
 $text_tr = $text_tr . " SCI_TOC ";
}
$text_tr = $text_tr . " SCI_INTRO ";


my $counter = 1;
my $bc = 1;
my $vc = 1;
for( my $i = 1; $i <= $nit; $i++ ) {
    $selector = int rand 100; 

#Add volumes for ultra long ones.
    $vc++;
	if(($vc > $vtol/2) && ($vbool == 1)){
	    $text_tr = $text_tr . " SCI_VOL ";
	    $vc = 0;
    }


#Add books for really long ones.
    $bc++;
	if(($bc > ($btol * ((int(rand(2))) + 1))) && ($bbool == 1)){
	    $text_tr = $text_tr . " SCI_BOOK ";
	    $bc = 0;
    }


#Add parts if it gets too long. 
    $counter++;
	if(($counter > ($sectol * ((int(rand(5))) + 1))) && ($partbool == 1)){
	    $text_tr = $text_tr . " SCI_PART ";
	    $counter = 0;
    }

    if($selector >= 0 && $selector < 10) {
	$section = " SCI_MODEL ";
    } elsif ($selector >= 10 && $selector < 30) {
	$section = " SCI_IMPL ";
    } elsif ($selector >= 30 && $selector < 50) {
	$section = " SCI_EVAL ";
    } elsif ($selector >= 50 && $selector < 60) {
	$section = " SCI_RELWORK ";
    } elsif ($selector >= 60 && $selector < 85) {
	$section = " SCI_MATH ";
    } elsif ($selector >= 85 && $selector < 100) {
	$section = " SCI_CORP ";
    }
    $text_tr = $text_tr . $section;
}
$text_tr = $text_tr . " SCI_CONCL LATEX_FOOTER }
";

my $cthresh=50;
if($nsec > $cthresh) {

    my $every=0;
    for (my $cp = $cthresh; $cp < $nsec; $cp++) {
	$every=$every+1;
	if($every == 20) {
	    $text_tr = $text_tr . $citpen;
	    $every=0;
	}	
    }
}

open(TOPFILE,">","scitoprule.in") or die "Could not open file scitoprule.in";
if( $picwank ) {
my $ci="CORP_IMAGE_MAYBE+2 CORP_IMAGE
";
my $li="LAB_IMAGE_MAYBE+2 LAB_IMAGE
";
my $si="SCI_IMAGE_MAYBE+2 SCI_IMAGE
";
     $text_tr = $text_tr.$ci.$li.$si;
	    }
print TOPFILE $text_tr;



open(GFILE,"<","graphviz.in") or die "Could not open file graphviz.in";
open(GTFILE,">","graphtot.in") or die "Could not open file graphtot.in";
while (my $gline = <GFILE>) {
    print GTFILE $gline;
}

open(FHFILE,"<","corprules.in") or die "Could not open file corprules.in";
while (my $line = <FHFILE>) {
    print TOPFILE $line;
    print GTFILE $line;
}
open(SFILE,"<","system_names.in") or die "Could not open file system_names.in";
while (my $linesys = <SFILE>) {
    print TOPFILE $linesys;
    print GTFILE $linesys;
}


close(GTFILE);
close(GFILE);
close(SFILE);
close(FHFILE);
close(TOPFILE);

my $tex_fh; 
my $start_rule;
if( defined $options{"talk"} ) {
    $tex_fh = new IO::File ("<talkrules.in");
    $start_rule = "SCITALK_LATEX";
} else {
    $tex_fh = new IO::File ("<scitoprule.in");
    $start_rule = "SCIPAPER_LATEX"
}


my @a = ($sysname);
$tex_dat->{"SYSNAME"} = \@a;
# add in authors
$tex_dat->{"AUTHOR_NAME"} = \@authors;
my $s = "";
for( my $i = 0; $i <= $#authors; $i++ ) {
    $s .= "AUTHOR_NAME";
    if( $i < $#authors-1 ) {
	$s .= ", ";
    } elsif( $i == $#authors-1 ) {
	$s .= " and ";
    }
}
my @b = ($s);
$tex_dat->{"SCIAUTHORS"} = \@b;

scigen::read_rules ($tex_fh, $tex_dat, \$tex_RE, 0);
if( defined $title ) {
    my @a = ($title);
    $tex_dat->{"SCI_TITLE"} = \@a;
}
my $tex = scigen::generate ($tex_dat, $start_rule, $tex_RE, 0, 1); 
open( TEX, ">$tex_file.tex" ) or die( "Couldn't open $tex_file for writing" );
print TEX $tex;
close( TEX );


# for every figure you find in the file, generate a figure
open( TEX, "<$tex_file.tex" ) or die( "Couldn't read $tex_file" );
my @figures = ();
while( <TEX> ) {

    my $line = $_;

    if( /[=\{](myfigure[^\,\}]*)[\,\}]/ ) {
	my $figfile = substr("$tmp_dir/$1",0,-4);
	my $figeps = $figfile.".eps";
      	my $done = 0;
	while( !$done ) {
	    my $newseed = int rand 0xffffffff;
	    my $color = "";
	    if( defined $options{"talk"} ) {
		$color = "--color"
	    }
	    system( "perl make-graph.pl --file $figeps --seed $newseed --color $color; epstopdf $figeps" ) 
		or $done=1;
	    print "made graph: $1\n";
	}
	push @figures, $figfile;
    }

    if( /[=\{](diag[^\,\}]*)[\,\}]/ ) {
	my $figfile = substr("$tmp_dir/$1",0,-4);
	my $figeps = $figfile.".eps";
	my $done = 0;
	while( !$done ) {
	    my $newseed = int rand 0xffffffff;
	    if( `which neato` ) {
		(system( "./make-diagram.pl --sys \"$sysname\" " . 
			 "--file $figeps --seed $newseed; epstopdf $figeps; rm -f $figeps" ) or 
		 !(-f "$tmp_dir/$1")) 
		    or $done=1;
		print "made diagram: $1\n";
	    } else {
		system( "./make-graph.pl --file $figeps --seed $newseed; epstopdf $figeps" ) 
		    or $done=1;
            print "made graph: $1\n";
	    }
	}
	push @figures, $figfile;
    }


    if( /[=\{]([^\{]*)-(talkfig[^\,\}]*)[\,\}]/) {
	my $figfile = "$tmp_dir/$1-$2";
	my $type = $1;
	my $done = 0;
	while( !$done ) {
	    my $newseed = int rand 0xffffffff;
	    system( "./make-talk-figure.pl --file $figfile --seed $newseed --type $type; epstopdf $figfile" ) 
		or $done=1;
	}
	push @figures, $figfile;
    }


    if( /[=\{](corpimage[^\,\}]*)[\,\}]/ ) {
	my $figfile = "$tmp_dir/$1";
	my $type = substr($figfile,-4);
	my $nfiles = `ls corpimages | wc -l`;
	my $randy = (int rand $nfiles-1)+1;
	my $done = 0;
	while( !$done ) {
	    system( "cp corpimages/c$randy$type $figfile" )
		or $done=1;
	    print "copied image: $1\n";
	}
    }

    if( /[=\{](labimage[^\,\}]*)[\,\}]/ ) {
	my $figfile = "$tmp_dir/$1";
	my $type = substr($figfile,-4);
	my $nfiles = `ls labimages | wc -l`;
	my $randy = (int rand $nfiles-1)+1;
	my $done = 0;
	while( !$done ) {
	    system( "cp labimages/l$randy$type $figfile" )
		or $done=1;
	    print "copied image: $1\n";
	}
    }

    if( /[=\{](sciimage[^\,\}]*)[\,\}]/ ) {
	my $figfile = "$tmp_dir/$1";
	my $type = substr($figfile,-4);
	my $nfiles = `ls sciimages | wc -l`;
	my $randy = (int rand $nfiles-1)+1;
	my $done = 0;
	while( !$done ) {
	    system( "cp sciimages/s$randy$type $figfile" )
		or $done=1;
	    print "copied image: $1\n";
	}

}
close( TEX );


if( !defined $options{"savedir"} ) {

    my $land = "";
    if( defined $options{"talk"} ) {
	$land = "-t landscape";
    }

    system( "cp $class_files $tmp_dir; cd $tmp_dir; pdflatex $tex_file; pdflatex $tex_file; pdflatex $tex_file; rm $class_files;") and die( "Couldn't latex nothing." );

    system( "acroread $tex_file.pdf" ) and die( "Couldn't acroread $tex_file.pdf" );


}

my $seedstring = "seed=$seed ";
foreach my $author (@authors) {
    $seedstring .= "author=$author ";
}

if( defined $options{"tar"} or defined $options{"savedir"} ) {
    my $f = $options{"tar"};
    my $tartmp = "$tmp_dir/tartmp.$$";
    my $all_files = "$tex_file.* @figures";
    system( "mkdir $tartmp; cp $all_files $tartmp/; cd $tmp_dir;" ) and 
	die( "Couldn't mkdir $tartmp" );
    #$all_files =~ s/$tmp_dir\///g;
    #system( "echo $seedstring > $tartmp/seed.txt" ) and 
#	die( "Couldn't cat to $tartmp/seed.txt" );
#    $all_files .= " seed.txt";

    if( defined $options{"tar"} ) {
	system( "tar -czf $$.tgz $tartmp.$$; " . 
		"cp $tartmp/$$.tgz $f; rm -rf $tartmp" ) and 
		    die( "Couldn't tar to $f" );
    } else {
	# saving everything untarred
	my $dir = $options{"savedir"};
	# WARNING: we delete this directory if it exists
	if( -d $dir ) {
	    system( "rm -rf $dir" ) and die( "Couldn't rm existing $dir" );
	}
	system( "mv $tartmp $dir" ) and die( "Couldn't move $tartmp to $dir" );
    }

} else {
    print "$seedstring\n";
}

if( !defined $options{"save"} ) {
    system("rm -rf $tmp_dir");}



sub get_system_name {

    if( $remote ) {
	return &get_system_name_remote();
    }

    if( !defined $name_RE ) {
	my $fh = new IO::File ("<system_names.in");
        scigen::read_rules ($fh, $name_dat, \$name_RE, 0);
    }

    my $name = scigen::generate ($name_dat, "SYSTEM_NAME", $name_RE, 0, 0);
    chomp($name);

    # how about some effects?
    my $rand = rand;
    if( $rand < .1 ) {
	$name = "{\\em $name}";
    } elsif( length($name) <= 6 and $rand < .4 ) {
	$name = uc($name);
    }

    return $name;
}

sub get_system_name_remote {

    my $sock = IO::Socket::INET->new( PeerAddr => "localhost", 
				      PeerPort => $scigen::SCIGEND_PORT,
				      Proto => 'tcp' );
    
    my $name;
    if( defined $sock ) {
	$sock->autoflush;
	$sock->print( "SYSTEM_NAME\n" );
	
	while( <$sock> ) { 
	    $name = $_;
	}
	$sock->close();
	undef $sock;
	
    } else {
	print STDERR "socket didn't work\n";
    }

    chomp($name);
    return $name;
}
