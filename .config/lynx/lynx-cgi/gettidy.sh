
#! /bin/sh

#### gettidy.sh ####

# This script can be used within lynx, in a CGI-like environment,
# to run the "tidy" program on a given URL document and display
# the tidied-up HTML.  Or, instead of "tidy", it could be used with
# any other filter that reads HTML text from stdin and produces
# HTML text on stdout.
#
# A child lynx process is used to retrieve the HTML document (one
# could use wget or libwww-perl instead).  No temporary files needed.
#
# Use this hack at your own risk, no guarantees for anything.
# (Really. This is especially unfit for anonymous accounts.  No
# checking for special shell characters is done.)
# Changes:
#  0.1  Klaus Weide <address@hidden>            1998-12-13
# Initial version
#  0.2                  kweide                  1998-12-14
# Added </dev/null to lynx call, require HTTP status line to be
# first line from -mime_header

# Required:
# o Lynx on a Unix system, configured and compiled with LYNCGI_LINKS
#   support.  (This script could be modified to work as a real CGI
#   script run by an HTTP server.)
# o Bourne shell for this script.  Actually, it's only tested with
#   bash on linux.
# o A working binary of the "tidy" filter (or whatever else you want
#   to use).
# o sed.
#
# Optional:
# o Perl.
#
# Instructions for use with "tidy":
# o Get "tidy" from <URL: http://www.w3.org/People/Raggett/tidy/>.
#   (Read the web page!).  Compile it by running make.  (Note:
#   You may have to convert the Makefile to Unix line-ends first.)
#   Put location of "tidy" binary on the line below that starts
#   with TIDY=.
# o Change other paths and flags in configuration section below
#   as needed.
# o Make sure Lynx is compiled with LYNXCGI support.  Make THIS script
#   executable with chmod.  Put it in a location where your lynx.cfg
#   allows lynxcgi scripts.  (Read the relevant comments in lynx.cfg
#   if you are not sure, search for CGI.)
# o Test whether you can access the following URL with Lynx:
#   <lynxcgi://localhost/home/mackeryd/.config/lynx/lynx-cgi/gettidy.sh?/xxhttp://lynx.browser.org>
#   Of course, change PATH/TO, to wherever you put this script.
# o Define the following environment variables *outside of lynx*,
#   before starting lynx.  Putting them in lynx.cfg *does not work*.
#      xhttp_proxy='lynxcgi://localhost/PATH/TO/gettidy.sh?/'
#      xxhttp_proxy='lynxcgi://localhost/PATH/TO/gettidy.sh?/'
#      export xhttp_proxy xxhttp_proxy
#   or, if you use a C-shell:
#      setenv xhttp_proxy 'lynxcgi://localhost/PATH/TO/gettidy.sh?/'
#      setenv xxhttp_proxy 'lynxcgi://localhost/PATH/TO/gettidy.sh?/'
#   Note the extra ?/ at the end.
#   Add equivalent variables xftp_proxy, xxftp_proxy etc. if you want,
#   or even xfile_proxy, xxfile_proxy for local files.
#
# Usage:
# o When you view a Page in lynx that you want to run through "tidy",
#   - press 'G' (note capital) to start editing current document's URL
#   - prefix URL with an x, so that "http:" becomes "xhttp:", and
#     press ENTER.
#   In other words, the 4 key sequence 'G', Ctrl-A, 'x', ENTER.
#   Note that you may get an empty page if "tidy" fails to produce
#   anything but error messages.
# o When you also want to see the messages from "tidy" together with
#   the rendered document, use xx instead of one x.  In other words,
#   the five keys 'G', Ctrl-A, 'x', 'x', ENTER.
#   Note that messages are intermixed with the tidied-up document,
#   so the combination fed to lynx see is most likely invalid HTML;
#   lynx may complain about it or produce strange rendering sometimes.
# o If enabled below with ALLOW_TIDY_PARAM_FLAGS, additional flags can
#   be passed to "tidy" by appending ";tidy=<some_flags>" to the x-URL.
#   Use '+' characters for spaces, for example
#   For example "xhttp://some.server/something.html;tidy=-e+-utf8";.
#
# Tips for lynx.cfg:
# o Settings for no_proxy (from lynx.cfg or environment) still apply
#   for our fake lynxcgi proxy, so beware.  For example xfile_proxy
#   will not work for xfile://localhost/ if localhost is listed in
#   no_proxy.
# o If you use a (real) proxy, you should export the relevant variables
#   to this script, i.e. add LYNXCGI_ENVIRONMENT:http_proxy etc.
# o You may want to create a separate lynx.cfg file for the child lynx
#   process (see LYNX_FLAGS below) and take out unnecessary options.
#   Setting GLOBAL_MAILCAP and PERSONAL_MAILCAP to /dev/null should
#   make the child lynx start up faster, especially if you have lots
#   of tests in the mailcap files.
#

# ***
# *** CONFIGURATION
# ***
# *** Any non-empty value means YES for boolean settings.

# Should we use perl?
USE_PERL=YES

# Preserve HTTP headers, needs perl, ignored if USE_PERL is unset.
USE_MIME_HEADER=YES

# Paths for programs used.  You may have to fully specify them.
LYNX=/usr/local/src/lynx2-8-1-cs/lynx
TIDY=/usr/src/tidy/tidy
PERL=perl
SED=sed

# Additional flags that should always be used.
# LYNX_FLAGS="-cfg=/path/to/your/lynx.cfg" might be a good idea.
LYNX_FLAGS=
TIDY_FLAGS=

ALLOW_TIDY_PARAM_FLAGS=YES    # look for tidy options in URL param

DEBUG=  # Set this to get a lot of debugging info instead of rendered doc
straceprefix='/usr/bin/strace -o strace.log' # if you have strace, for DEBUG
traceflags='-trace -tlog'       # for the child lynx process, with DEBUG

# ***
# *** end of configuration
# ***

if [ "$DEBUG" ]; then
        echo "content-type: text/plain"
        echo
        set -vx
#       /usr/sbin/lsof -p $$    # if you have it...
        debugflags="$traceflags"
        prefix="$straceprefix"
fi

if [ ! -x "$LYNX" -o ! -x "$TIDY" ]; then
   echo "content-type: text/plain"
   echo
   echo "$LYNX or $TIDY not found, or cannot be executed."
   exit
fi

if [ "$USE_MIME_HEADER" ]; then
   if [ "${QUERY_STRING#/xhttp}" = "$QUERY_STRING" -a \
        "${QUERY_STRING#/xxhttp}" = "$QUERY_STRING" ]; then
      USE_MIME_HEADER=""        # -mime_header works only for http URLs
   fi
fi

# It's finally time to look at the URL...
if [ "${QUERY_STRING#/xx}" = "$QUERY_STRING" ]; then
   IGNORE_STDERR=YES    # if QUERY_STRING does not start with "/xx"
   real_url="${QUERY_STRING#/x}"
else
   IGNORE_STDERR=""     # QUERY_STRING should start with "/xx"
   real_url="${QUERY_STRING#/xx}"
fi

if [ "$ALLOW_TIDY_PARAM_FLAGS" ]; then
   if [ "${QUERY_STRING%;tidy=*}" != "$QUERY_STRING" ]; then
        TIDY_PARAM_FLAGS="${QUERY_STRING##*;tidy=}"
        TIDY_PARAM_FLAGS="${TIDY_PARAM_FLAGS//+/ }"
        real_url="${real_url%;tidy=*}"
   fi
fi

if [ "$USE_MIME_HEADER" ]; then
   lynxmainflag="-mime_header"
else
   echo "content-type: text/html"
   echo
   lynxmainflag="-source"
fi

TIDYCOMMAND="$TIDY $TIDY_FLAGS $TIDY_PARAM_FLAGS"

if [ "$USE_PERL" ]; then
    if [ "$USE_MIME_HEADER" ];then
      PERL_COMMANDS='$|=1;
         while (<>) {
            if (($. ==  1 && (/^HTTP/))../^\s*$/) {print $_;next;}
            if (!$first++) {
               open(P,"|'$TIDYCOMMAND'") || die "could not start tidy";
               select P;$|=1;
            }
         print P;
         }
         close P or die "could not close pipe"'
   else         # USE_PERL but not MIME_HEDER, not very useful
      PERL_COMMANDS='$|=1;
         while (<>) {
            if (!$first++) {
               open(P,"|'$TIDYCOMMAND'") || die "could not start tidy";
               select P;$|=1;
            }
         print P;
         }
         close P or die "could not close pipe"'
   fi
fi

LYNXCOMMAND="$prefix $LYNX $real_url $LYNX_FLAGS $lynxmainflag $debugflags"

if [ "$USE_PERL" ]; then
   if [ "$IGNORE_STDERR" ]; then
      $LYNXCOMMAND </dev/null \
      | $PERL -e "$PERL_COMMANDS" 2>/dev/null
   else         # intermix stderr with output
      $LYNXCOMMAND </dev/null \
      | $PERL -e "$PERL_COMMANDS" 3>&2 2>&1 1>&3 \
      | $SED -e 's/\&/\&amp;/g' \
             -e 's/</\&lt;/g' \
             -e 's/^\(.*\)$/<PRE>tidy: <EM>\1\
<\/EM><\/PRE>/'
   fi
else            # not USE_PERL
   if [ "$IGNORE_STDERR" ]; then
      $LYNXCOMMAND \
      | $TIDYCOMMAND 2>/dev/null
   else         # intermix stderr with output
      $LYNXCOMMAND \
      | $TIDYCOMMAND 3>&2 2>&1 1>&3 \
      | $SED -e 's/\&/\&amp;/g' \
             -e 's/</\&lt;/g' \
             -e 's/^\(.*\)$/<PRE>tidy: <EM>\1\
<\/EM><\/PRE>/'
   fi
fi
