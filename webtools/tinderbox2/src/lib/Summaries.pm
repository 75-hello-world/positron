# -*- Mode: perl; indent-tabs-mode: nil -*-

# Summaries.pm - generate the summary pages which show the current
# state of the tree in various formats.  Few (if any) of these pages
# make use of the popup window because we want the largest audiance
# possible to view them.

# The only external interface to this library is summary_pages() and
# create_global_index() these functions are only called by tinder.cgi.

# $Revision: 1.8 $ 
# $Date: 2001/07/20 19:04:59 $ 
# $Author: kestes%walrus.com $ 
# $Source: /home/hwine/cvs_conversion/cvsroot/mozilla/webtools/tinderbox2/src/lib/Summaries.pm,v $ 
# $Name:  $ 


# The contents of this file are subject to the Mozilla Public
# License Version 1.1 (the "License"); you may not use this file
# except in compliance with the License. You may obtain a copy of
# the License at http://www.mozilla.org/NPL/
#
# Software distributed under the License is distributed on an "AS
# IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
# implied. See the License for the specific language governing
# rights and limitations under the License.
#
# The Original Code is the Tinderbox build tool.
#
# The Initial Developer of the Original Code is Netscape Communications
# Corporation. Portions created by Netscape are
# Copyright (C) 1998 Netscape Communications Corporation. All
# Rights Reserved.
#

# complete rewrite by Ken Estes:
#	 kestes@staff.mail.com Old work.
#	 kestes@reefedge.com New work.
#	 kestes@walrus.com Home.
# Contributor(s): 




package Summaries;

$VERSION = '#tinder_version#';


# generate all the pages which summaries the current state for a given
# tree.  The contents of the pages is passed back to the caller so
# that it can be amalgamated into information about all projects
# status.


sub summary_pages {

# Look! we use 'my' here but we wish to change $summary_ref and pass
# it back to the caller, see the return statement.

  my ($tree, $summary_ref) = @_;

  # Build all the summary pages and save data into the $symmary_ref
  # also take the time to build an index page for this tree pointing
  # to each type of information availible for this tree.

  # Summary pages really do not fit in this framework but this is the best
  # place to put them.


  my ($tree_state);
  my (@index_html);
  
  eval {
    local   $SIG{'__DIE__'} = \&null;

    # put these into global variables since passing arrays is a bit
    # ugly and nearly all of these are used by every summary function.

    @LATEST_STATUS = TinderDB::Build::latest_status($tree);
    @BUILD_NAMES = TinderDB::Build::build_names($tree);

    @HTML_COLORS = BuildStatus::status2html_colors(@LATEST_STATUS);
    @HDML_CHARS = BuildStatus::status2hdml_chars(@LATEST_STATUS);

    $TREE = $tree;
    $TREE_STATE = TinderHeader::gettree_header('TreeState', $tree);
    $HTML_TIME = HTMLPopUp::timeHTML($main::TIME);

  };

  # use symbolic reference in @SUMMARY_FUNCS since we want both: 
  # a) a pointer to the function (so we can call it) and
  # b) the name of the function (so we know the name of the html page.)

  # If there is no build columns in the page or build package
  # installed then only build the index otherwise build all the
  # summary pages.

  # There is no need to make this list configurable as the load for
  # each function is light, so there is no harm in running functions
  # which are never used.  

  # However, we do not wish to run these functions if tinderbox is
  # configured to run without a build module or TreeState.

  if ( (!($@)) && (@LATEST_STATUS) && (@BUILD_NAMES) ) {
    @SUMMARY_FUNCS = (
                      'quickparse',
                      'panel',
                      'express',   
		      'hdml',
                      
# these summary function have not been debugged yet, I just took the
# source from the previous Tinderbox

#                          'flash',
#                          'rdf',

                     );
  }

  my ($index_file) = FileStructure::get_filename($tree,'index');

  push @index_html, (
                     "<html>\n\t<head><title>Tree: $tree</title></head>\n".
                     "Select one of the following formats ".
                     "for viewing tree: $tree <p>\n"
                    );

  foreach $func (sort @SUMMARY_FUNCS) {
    
    my ($header, $body, $footer, $extension) = &$func();

    my ($summary_file) = (FileStructure::get_filename($tree, 'tree_HTML').
                          "/$func.$extension");

    main::overwrite_file($summary_file, $header, $body, $footer);

    # create_summary page for ($func, $tree)
    # and its index entry in $tree/index.html

    push @index_html, ("\t<LI>".
                       HTMLPopUp::Link(
                                       "linktxt"=>$func,
                                       "href"=>"$func.$extension",
                                      ).
                       "\n"
                      );

    # create a list of all different trees summary results.  This
    # makes an interesting overview page.

    $summary_ref->{$func}{'all_bodies'}{$tree} = $body;

    # The headers/footers/extension do not change for different trees.
    # We will ensure we get exactly one set per function.

    $summary_ref->{$func}{'header'} = $header;
    $summary_ref->{$func}{'footer'} = $footer;
    $summary_ref->{$func}{'extension'} = $extension;
    
  } # for $func
  
  push @index_html, (
                     "\t<LI>".
                     HTMLPopUp::Link(
                                     "linktxt"=>"status",
                                     "href"=>"status.html",
                                    ).
                     "\n</UL></TD></TR></TABLE>\n",
                    );

  main::overwrite_file($index_file, @index_html);

  # Pass the updated $summary_ref  back to the caller;

  return $summary_ref;
}



# make one $func page for a given tree group,

sub treegroup_func_page    {
  my ($summary_ref, $func, $group_name) = @_;

  my ($body);
  my ($link);

  my (@tree_group) = sort keys %{ $TreeData::VC_TREE_GROUPS{$group_name} };

  foreach $tree (@tree_group) {
    $body .= ( $summary_ref->{$func}{'all_bodies'}{$tree} .
               "\n<p>\n");
  }

  my ($header) = $summary_ref->{$func}{'header'};
  my ($footer) = $summary_ref->{$func}{'footer'};
  my ($extension) = $summary_ref->{$func}{'extension'};

  my ($group_func_summary_page) = $header.$body.$footer;

  if ($group_func_summary_page) {

    # if we do not have a build section then the page may be empty as
    # there is no data for any function

    my ($base_name) = "$groupname.$func.$extension";
    my ($file_name) = "$FileStructure::TINDERBOX_HTML_DIR/$base_name";
    
    main::overwrite_file ($file_name, $group_func_summary_page);
    
    $link .= ("\t\t<LI>".
              HTMLPopUp::Link(
                              "linktxt"=>$func,
                              "href"=>$base_name,
                             ).
              "\n");
  }

  return $link;
}


# Create and index page which has:
# *) links to all the trees 
# *) links to the 'all trees summary' pages,
#	  so that we can see how all the projects are doing 
# *) links to adminpage.


sub create_global_index {
  my ($summary_ref) = @_;

  my ($out);
  my (@trees) = TreeData::get_all_trees();
  my (@tree_admin_links, @tree_dir_links);

  # for each tree we create links to the tree directories and the
  # adminstration pages.

  foreach (@trees) {
    my ($tree_dir) = FileStructure::get_filename($_, 'tree_HTML');
    push @tree_dir_links, (
                           "\t\t<LI>".
                           HTMLPopUp::Link(
                                           "linktxt"=>$_,
                                           "href"=>"./$_/index.html",
                                          ).
                           "</LI>\n"
                          );

    push @tree_admin_links, (
                             "\t\t<LI>".
                             HTMLPopUp::Link(
                                             "linktxt"=>$_,
                                             "href"=> ("$FileStructure::URLS{'admintree'}".
                                                       "\?tree=$_"),
                                            ).
                             "</LI>\n"
                            );
  }

    
  # The headers/footers/extensions do not change for different trees. 
  # We join the set of all bodies together to generate this summary page.

  # We generate a summary pages for arbitrary sets of trees these
  # manager views are defined in TreeData.pm

  foreach $groupname (sort keys %TreeData::VC_TREE_GROUPS) {

    push @func_summary_links, (
                               "Summary Information for $groupname:<br>\n\n",
                               (sort keys 
                                %{ $TreeData::VC_TREE_GROUPS{$groupname} }),
                               "\t<UL>\n\n",
                              );

    # for each summary function create a global summary page for all trees
    # and the links which point to those pages.
    
    foreach $func (sort keys %{ $summary_ref }) {
      
      push @func_summary_links, 
      treegroup_func_page($summary_ref, $func, $groupname);
    }

      push @func_summary_links, "\t</UL>\n\n";
  }

  
  $out .= <<EOF;

<h3>Tinderbox Pages sorted by Project</h3>
Select one of the following trees:

	<UL>
@tree_dir_links
	</UL>

Administer one of the following trees:

	<UL>

@tree_admin_links

	</UL>

EOF

  if ( %{ $summary_ref } ) {
    $out .= <<EOF;

<h3>Project Managements Summary Pages</h3>

@func_summary_links


EOF
  }

  my $global_index_file = (
                           $FileStructure::TINDERBOX_HTML_DIR.
                           "/".$FileStructure::GLOBAL_INDEX_FILE
                          );
  
  main::overwrite_file ($global_index_file, $out);

  return ;
}



#-----------------------------------------------------------------------------




# These summary formats are all various ways of displaying:
# 	@LATEST_STATUS and @BUILD_NAMES

# they all return three strings: $header, $body, $footer 

# the $header, $footer are tree independent.

# the $body's from different trees can be jammed together (with a
# header on top and a footer on the bottom) to get an overview of the
# state of all the trees.


sub express {
  my ($header, $body, $footer, $extension) = ();

  my ($colspan) = $#BUILD_NAMES + 1;

  $header = <<EOF;
<html>
<head>
	<META HTTP-EQUIV=\"Refresh: $REFRESH_TIME\" CONTENT=\"300\">
	<title>Summary Express for Tree: $TREE</title>
</head>
<body>
EOF


  $body .= "\t<table border=1 cellpadding=1 cellspacing=1>\n";
  $body .= "\t\t<tr><th align=left colspan=$colspan>";
  
  $body .= HTMLPopUp::Link(
                           "linktxt"=> ("$TREE is $TREE_STATE".
                                        " as of $HTML_TIME"),
                           "href"=> (FileStructure::get_filename($TREE, 
                                                                 'tree_URL').
                                     "/$FileStructure::DEFAULT_HTML_PAGE"),
                          );
  
  $body .= "\t\t</th></tr><tr>\n\n";
  
  for ($i=0; $i <= $#BUILD_NAMES; $i++) {
    my ($buildname) = $BUILD_NAMES[$i];
    my ($color) = $HTML_COLORS[$i];
    $body .= "\t\t<td bgcolor='$color'>$buildname</td>\n";
  }
  $body .= "\t</tr></table>\n";

  $footer = "</body>\n</html>\n";
  $extension = 'html';

  return ($header, $body, $footer, $extension);
}


sub panel {
  my ($header, $body, $footer, $extension) = ();

  $header = qq{
<html>
<head>
	<META HTTP-EQUIV="Refresh: $REFRESH_TIME" CONTENT="300">
	<style>
	body, td { 
		font-family: Verdana, Sans-Serif;
		font-size: 8pt;
	}
	</style>
	<title>Summary Panel for Tree: $TREE</title>
</head>
<body BGCOLOR="white" TEXT="black" LINK="#0000EE" 
      VLINK="#551A8B" ALINK="red">
  };

  $body .= HTMLPopUp::Link(
                           "linktxt"=> ("$TREE is $TREE_STATE".
                                        " as of $HTML_TIME"),
                           "href"=>(FileStructure::get_filename($TREE, 
                                                                 'tree_URL').
                                     "/$FileStructure::DEFAULT_HTML_PAGE"),
                     );

  $body .= "\n\t<table border=0 cellpadding=1 cellspacing=1>\n";
  for ($i=0; $i <= $#BUILD_NAMES; $i++) {
    my ($buildname) = $BUILD_NAMES[$i];
    my ($color) = $HTML_COLORS[$i];
    $body .= "\t\t<tr><td bgcolor='$color'>$buildname</td></tr>\n";
  }

  $body .= "\t</table>\n";

  $footer = "</body>\n</html>\n";
  $extension = 'html';

  return ($header, $body, $footer, $extension);
}


sub quickparse {
  my ($header, $body, $footer, $extension) = ();

  $header = "<pre>\n";

  $body .= "State|$TREE|$TREE|$TREE_STATE\n";
  
    for ($i=0; $i <= $#BUILD_NAMES; $i++) {
      my ($buildname) = $BUILD_NAMES[$i];
      my ($status) = $LATEST_STATUS[$i];
      $body .= "Build|$TREE|$buildname|$status\n";
    }

  $footer = "\n";
  $extension = 'html';
  
  return ($header, $body, $footer, $extension);
}



# The summary function ( 'flash', 'rdf', 'hdml',) have not been
# debugged yet, I just took the source from the previous Tinderbox and
# made it look like what I am doing in this code.



sub flash {
  my ($header, $body, $footer, $extension) = ();

  print "Content-type: text/rdf\n\n" unless $form{static};

  my (%build, %times);

  my ($mac,$unix,$win) = (0,0,0);

  while (my ($name, $status) = each %build) {
    next if $status eq 'success';
    $mac = 1, next if $name =~ /Mac/;
    $win = 1, next if $name =~ /Win/;
    $unix = 1;
  }

  my $busted = $mac + $unix + $win;
  if ($busted) {

    # Construct a legible sentence; e.g., "Mac, Unix, and Windows
    # are busted", "Windows is busted", etc. This is hideous. If
    # you can think of something better, please fix it.

    my $text;
    if ($mac) {
      $text .= 'Mac' . ($busted > 2 ? ', ' : ($busted > 1 ? ' and ' : ''));
    }
    if ($unix) {
      $text .= 'Unix' . ($busted > 2 ? ', and ' : ($win ? ' and ' : ''));
    }
    if ($win) {
      $text .= 'Windows';
    }
    $text .= ($busted > 1 ? ' are ' : ' is ') . 'busted';

    # The Flash spec says we need to give ctime.  This is called
    # localtime in Perl.

    my $flash_time = $main::LOCALTIME;
    $flash_time =~ s/^...\s//;   # Strip day of week
    $flash_time =~ s/:\d\d\s/ /; # Strip seconds
    chomp $flash_time;
  
    $header = q{
    <RDF:RDF xmlns:RDF='http://www.w3.org/1999/02/22-rdf-syntax-ns#' 
             xmlns:NC='http://home.netscape.com/NC-rdf#'>
    <RDF:Description about='NC:FlashRoot'>
      <NC:child>
        <RDF:Description ID='flash'>
          <NC:type resource='http://www.mozilla.org/RDF#TinderboxFlash' />
        };

    $body = qq{
          <NC:source>$tree</NC:source>
          <NC:description>$text</NC:description>
          <NC:timestamp>$flash_time</NC:timestamp>
    };

    $footer = q{
        </RDF:Description>
      </NC:child>
    </RDF:Description>
    </RDF:RDF>
  };
  };
    
    $extension = 'flash';

    return ($header, $body, $footer, $extension);
}


sub rdf {
  my ($header, $body, $footer, $extension) = ();

  my $mainurl = "http://$ENV{SERVER_NAME}$ENV{SCRIPT_NAME}?tree=$tree";
  my $dirurl = $mainurl;

  $dirurl =~ s@/[^/]*$@@;

  my $image = "channelok.gif";
  my $imagetitle = "OK";
  foreach my $buildname (sort keys %build) {
    if ($build{$buildname} eq 'busted') {
      $image = "channelflames.gif";
      $imagetitle = "Bad";
      last;
    }
  }

  $header = qq{<?xml version="1.0"?>
    <rdf:RDF 
         xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns="http://my.netscape.com/rdf/simple/0.9/">
    <channel>
      <title>Tinderbox - $tree</title>
      <description>Build bustages for $tree</description>
      <link>$mainurl</link>
    </channel>
    <image>
      <title>$imagetitle</title>
      <url>$dirurl/$image</url>
      <link>$mainurl</link>
    </image>
  };    
    
  $body .= ("\t<item><title>The tree is currently $TREE_STATE</title>".
            "<link>$mainurl</link></item>\n");

  for ($i=0; $i <= $#build_names; $i++) {
    my ($buildname) = $build_names[$i];
    my ($status) = $latest_status[$i];
    if ($status eq 'busted') {
      $body .= (
                "\t<item>".
                "<title>$buildname is in flames</title>".
                "<link>$mainurl</link>".
                "</item>\n"
               );
    }
  }

  $footer = "</rdf:RDF>\n";
  $extension = 'rdf';

  return ($header, $body, $footer, $extension);
}


# This is format is designed for wireless devices like Sprint phones

sub hdml {
  my ($header, $body, $footer, $extension) = ();

  $header = q{<hdml public=true version=2.0 ttl=0>
<display title=Tinderbox>
	<action type=help task=go dest=#help>
  };

  $body .= "\t<LINE>$TREE is $TREE_STATE<br>\n";

  for ($i=0; $i <= $#BUILD_NAMES; $i++) {
    my ($buildname) = $BUILD_NAMES[$i];
    my ($hdml_char) = $HDML_CHARS[$i];
    $body .= "\t<LINE>$hdml_char $buildname\n";
  }

  $body .= "</display>\n";

  $footer .= (
              "\n".
              TinderDB::Build::hdml_legend().
              "</HDML>\n"
             );

  $extension = 'hdml';

  return ($header, $body, $footer, $extension);
}


1;
