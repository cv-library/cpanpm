package CPAN::HandleConfig;
use strict;
use vars qw(%can %keys $loading $VERSION);
use Carp ();

$VERSION = "5.5001"; # see also CPAN::Config::VERSION at end of file

%can = (
        commit   => "Commit changes to disk",
        defaults => "Reload defaults from disk",
        help     => "Short help about 'o conf' usage",
        init     => "Interactive setting of all options",
);

# Q: where is the "How do I add a new config option" HOWTO?
# A1: svn diff -r 757:758 # where dagolden added test_report [git e997b71de88f1019a1472fc13cb97b1b7f96610f]
# A2: svn diff -r 985:986 # where andk added yaml_module [git 312b6d9b12b1bdec0b6e282d853482145475021f]
# A3: 1. add new config option to %keys below
#     2. add a Pod description in CPAN::FirstTime; it should include a
#        prompt line; see others for examples
#     3. add a "matcher" section in CPAN::FirstTime::init that includes
#        a prompt function; see others for examples
#     4. add config option to documentation section in CPAN.pm

%keys = map { $_ => undef }
    (
     "applypatch",
     "auto_commit",
     "build_cache",
     "build_dir",
     "build_dir_reuse",
     "build_requires_install_policy",
     "bzip2",
     "cache_metadata",
     "check_sigs",
     "colorize_debug",
     "colorize_output",
     "colorize_print",
     "colorize_warn",
     "commandnumber_in_prompt",
     "commands_quote",
     "connect_to_internet_ok",
     "cpan_home",
     "curl",
     "dontload_hash", # deprecated after 1.83_68 (rev. 581)
     "dontload_list",
     "ftp",
     "ftp_passive",
     "ftp_proxy",
     "ftpstats_size",
     "ftpstats_period",
     "getcwd",
     "gpg",
     "gzip",
     "halt_on_failure",
     "histfile",
     "histsize",
     "http_proxy",
     "inactivity_timeout",
     "index_expire",
     "inhibit_startup_message",
     "keep_source_where",
     "load_module_verbosity",
     "lynx",
     "make",
     "make_arg",
     "make_install_arg",
     "make_install_make_command",
     "makepl_arg",
     "mbuild_arg",
     "mbuild_install_arg",
     "mbuild_install_build_command",
     "mbuildpl_arg",
     "ncftp",
     "ncftpget",
     "no_proxy",
     "pager",
     "password",
     "patch",
     "patches_dir",
     "perl5lib_verbosity",
     "prefer_external_tar",
     "prefer_installer",
     "prefs_dir",
     "prerequisites_policy",
     "proxy_pass",
     "proxy_user",
     "randomize_urllist",
     "scan_cache",
     "shell",
     "show_unparsable_versions",
     "show_upload_date",
     "show_zero_versions",
     "tar",
     "tar_verbosity",
     "term_is_latin",
     "term_ornaments",
     "test_report",
     "trust_test_report_history",
     "unzip",
     "urllist",
     "use_sqlite",
     "username",
     "version_timeout",
     "wait_list",
     "wget",
     "yaml_load_code",
     "yaml_module",
    );

my %prefssupport = map { $_ => 1 }
    (
     "build_requires_install_policy",
     "check_sigs",
     "make",
     "make_install_make_command",
     "prefer_installer",
     "test_report",
    );

# returns true on successful action
sub edit {
    my($self,@args) = @_;
    return unless @args;
    CPAN->debug("self[$self]args[".join(" | ",@args)."]");
    my($o,$str,$func,$args,$key_exists);
    $o = shift @args;
    if($can{$o}) {
        my $success = $self->$o(args => \@args); # o conf init => sub init => sub load
        unless ($success) {
            die "Panic: could not configure CPAN.pm for args [@args]. Giving up.";
        }
    } else {
        CPAN->debug("o[$o]") if $CPAN::DEBUG;
        unless (exists $keys{$o}) {
            $CPAN::Frontend->mywarn("Warning: unknown configuration variable '$o'\n");
        }
        my $changed;


        # one day I used randomize_urllist for a boolean, so we must
        # list them explicitly --ak
        if (0) {
        } elsif ($o =~ /^(wait_list|urllist|dontload_list)$/) {

            #
            # ARRAYS
            #

            $func = shift @args;
            $func ||= "";
            CPAN->debug("func[$func]args[@args]") if $CPAN::DEBUG;
            # Let's avoid eval, it's easier to comprehend without.
            if ($func eq "push") {
                push @{$CPAN::Config->{$o}}, @args;
                $changed = 1;
            } elsif ($func eq "pop") {
                pop @{$CPAN::Config->{$o}};
                $changed = 1;
            } elsif ($func eq "shift") {
                shift @{$CPAN::Config->{$o}};
                $changed = 1;
            } elsif ($func eq "unshift") {
                unshift @{$CPAN::Config->{$o}}, @args;
                $changed = 1;
            } elsif ($func eq "splice") {
                my $offset = shift @args || 0;
                my $length = shift @args || 0;
                splice @{$CPAN::Config->{$o}}, $offset, $length, @args; # may warn
                $changed = 1;
            } elsif ($func) {
                $CPAN::Config->{$o} = [$func, @args];
                $changed = 1;
            } else {
                $self->prettyprint($o);
            }
            if ($changed) {
                if ($o eq "urllist") {
                    # reset the cached values
                    undef $CPAN::FTP::Thesite;
                    undef $CPAN::FTP::Themethod;
                    $CPAN::Index::LAST_TIME = 0;
                } elsif ($o eq "dontload_list") {
                    # empty it, it will be built up again
                    $CPAN::META->{dontload_hash} = {};
                }
            }
        } elsif ($o =~ /_hash$/) {

            #
            # HASHES
            #

            if (@args==1 && $args[0] eq "") {
                @args = ();
            } elsif (@args % 2) {
                push @args, "";
            }
            $CPAN::Config->{$o} = { @args };
            $changed = 1;
        } else {

            #
            # SCALARS
            #

            if (defined $args[0]) {
                $CPAN::CONFIG_DIRTY = 1;
                $CPAN::Config->{$o} = $args[0];
                $changed = 1;
            }
            $self->prettyprint($o)
                if exists $keys{$o} or defined $CPAN::Config->{$o};
        }
        if ($changed) {
            if ($CPAN::Config->{auto_commit}) {
                $self->commit;
            } else {
                $CPAN::CONFIG_DIRTY = 1;
                $CPAN::Frontend->myprint("Please use 'o conf commit' to ".
                                         "make the config permanent!\n\n");
            }
        }
    }
}

sub prettyprint {
    my($self,$k) = @_;
    my $v = $CPAN::Config->{$k};
    if (ref $v) {
        my(@report);
        if (ref $v eq "ARRAY") {
            @report = map {"\t$_ \[$v->[$_]]\n"} 0..$#$v;
        } else {
            @report = map
                {
                    sprintf "\t%-18s => %s\n",
                               "[$_]",
                                        defined $v->{$_} ? "[$v->{$_}]" : "undef"
                } keys %$v;
        }
        $CPAN::Frontend->myprint(
                                 join(
                                      "",
                                      sprintf(
                                              "    %-18s\n",
                                              $k
                                             ),
                                      @report
                                     )
                                );
    } elsif (defined $v) {
        $CPAN::Frontend->myprint(sprintf "    %-18s [%s]\n", $k, $v);
    } else {
        $CPAN::Frontend->myprint(sprintf "    %-18s undef\n", $k);
    }
}

sub commit {
    my($self,@args) = @_;
    CPAN->debug("args[@args]") if $CPAN::DEBUG;
    if ($CPAN::RUN_DEGRADED) {
                             $CPAN::Frontend->mydie(
                                                    "'o conf commit' disabled in ".
                                                    "degraded mode. Maybe try\n".
                                                    " !undef \$CPAN::RUN_DEGRADED\n"
                                                   );
    }
    my $configpm;
    # XXX does anything do this? can it be simplified? -- dagolden, 2011-01-19
    if (@args) {
      if ($args[0] eq "args") {
        # we have not signed that contract
      } else {
        $configpm = $args[0];
      }
    }
    unless (defined $configpm) {
        $configpm ||= $INC{"CPAN/MyConfig.pm"};
        $configpm ||= $INC{"CPAN/Config.pm"};
        $configpm || Carp::confess(q{
CPAN::Config::commit called without an argument.
Please specify a filename where to save the configuration or try
"o conf init" to have an interactive course through configing.
});
    }
    my($mode);
    if (-f $configpm) {
        $mode = (stat $configpm)[2];
        if ($mode && ! -w _) {
            Carp::confess("$configpm is not writable");
        }
    }

    my $msg;
    my $home = home();
    $msg = <<EOF unless $configpm =~ /MyConfig/;

# This is CPAN.pm's systemwide configuration file. This file provides
# defaults for users, and the values can be changed in a per-user
# configuration file. The user-config file is being looked for as
# $home/.cpan/CPAN/MyConfig.pm.

EOF
    $msg ||= "\n";
    my($fh) = FileHandle->new;
    rename $configpm, "$configpm~" if -f $configpm;
    open $fh, ">$configpm" or
        $CPAN::Frontend->mydie("Couldn't open >$configpm: $!");
    $fh->print(qq[$msg\$CPAN::Config = \{\n]);
    foreach (sort keys %$CPAN::Config) {
        unless (exists $keys{$_}) {
            # do not drop them: forward compatibility!
            $CPAN::Frontend->mywarn("Unknown config variable '$_'\n");
            next;
        }
        $fh->print(
            "  '$_' => ",
            $self->neatvalue($CPAN::Config->{$_}),
            ",\n"
        );
    }

    $fh->print("};\n1;\n__END__\n");
    close $fh;

    #$mode = 0444 | ( $mode & 0111 ? 0111 : 0 );
    #chmod $mode, $configpm;
###why was that so?    $self->defaults;
    $CPAN::Frontend->myprint("commit: wrote '$configpm'\n");
    $CPAN::CONFIG_DIRTY = 0;
    1;
}

# stolen from MakeMaker; not taking the original because it is buggy;
# bugreport will have to say: keys of hashes remain unquoted and can
# produce syntax errors
sub neatvalue {
    my($self, $v) = @_;
    return "undef" unless defined $v;
    my($t) = ref $v;
    unless ($t) {
        $v =~ s/\\/\\\\/g;
        return "q[$v]";
    }
    if ($t eq 'ARRAY') {
        my(@m, @neat);
        push @m, "[";
        foreach my $elem (@$v) {
            push @neat, "q[$elem]";
        }
        push @m, join ", ", @neat;
        push @m, "]";
        return join "", @m;
    }
    return "$v" unless $t eq 'HASH';
    my(@m, $key, $val);
    while (($key,$val) = each %$v) {
        last unless defined $key; # cautious programming in case (undef,undef) is true
        push(@m,"q[$key]=>".$self->neatvalue($val)) ;
    }
    return "{ ".join(', ',@m)." }";
}

sub defaults {
    my($self) = @_;
    if ($CPAN::RUN_DEGRADED) {
                             $CPAN::Frontend->mydie(
                                                    "'o conf defaults' disabled in ".
                                                    "degraded mode. Maybe try\n".
                                                    " !undef \$CPAN::RUN_DEGRADED\n"
                                                   );
    }
    my $done;
    for my $config (qw(CPAN/MyConfig.pm CPAN/Config.pm)) {
        if ($INC{$config}) {
            CPAN->debug("INC{'$config'}[$INC{$config}]") if $CPAN::DEBUG;
            CPAN::Shell->_reload_this($config,{reloforce => 1});
            $CPAN::Frontend->myprint("'$INC{$config}' reread\n");
            last;
        }
    }
    $CPAN::CONFIG_DIRTY = 0;
    1;
}

=head2 C<< CLASS->safe_quote ITEM >>

Quotes an item to become safe against spaces
in shell interpolation. An item is enclosed
in double quotes if:

  - the item contains spaces in the middle
  - the item does not start with a quote

This happens to avoid shell interpolation
problems when whitespace is present in
directory names.

This method uses C<commands_quote> to determine
the correct quote. If C<commands_quote> is
a space, no quoting will take place.


if it starts and ends with the same quote character: leave it as it is

if it contains no whitespace: leave it as it is

if it contains whitespace, then

if it contains quotes: better leave it as it is

else: quote it with the correct quote type for the box we're on

=cut

{
    # Instead of patching the guess, set commands_quote
    # to the right value
    my ($quotes,$use_quote)
        = $^O eq 'MSWin32'
            ? ('"', '"')
                : (q{"'}, "'")
                    ;

    sub safe_quote {
        my ($self, $command) = @_;
        # Set up quote/default quote
        my $quote = $CPAN::Config->{commands_quote} || $quotes;

        if ($quote ne ' '
            and defined($command )
            and $command =~ /\s/
            and $command !~ /[$quote]/) {
            return qq<$use_quote$command$use_quote>
        }
        return $command;
    }
}

sub init {
    my($self,@args) = @_;
    CPAN->debug("self[$self]args[".join(",",@args)."]");
    $self->load(do_init => 1, @args);
    1;
}

# This is a piece of repeated code that is abstracted here for
# maintainability.  RMB
#
# This test whether a given config directory and file could
# actually be created.  If the file doesn't exist, it will
# be created as a stub.
sub _configpmtest {
    my($configpmdir, $configpmtest) = @_;
    if (-w $configpmtest) {
        return $configpmtest;
    } elsif (-w $configpmdir) {
        #_#_# following code dumped core on me with 5.003_11, a.k.
        my $configpm_bak = "$configpmtest.bak";
        unlink $configpm_bak if -f $configpm_bak;
        if( -f $configpmtest ) {
            if( rename $configpmtest, $configpm_bak ) {
                $CPAN::Frontend->mywarn(<<END);
Old configuration file $configpmtest
    moved to $configpm_bak
END
            }
        }
        my $fh = FileHandle->new;
        if ($fh->open(">$configpmtest")) {
            $fh->print("1;\n");
            return $configpmtest;
        } else {
            # Should never happen
            Carp::confess("Cannot open >$configpmtest");
        }
    } else { return }
}

# Loads CPAN::MyConfig or fall-back to CPAN::Config. Will not reload a file
# if already loaded. Returns the path to the file %INC or else the empty string
#
# Note -- if CPAN::Config were loaded and CPAN::MyConfig subsequently
# created, calling this again will leave *both* in %INC

sub require_myconfig_or_config () {
    if (   $INC{"CPAN/MyConfig.pm"}
        || _try_loading("CPAN::MyConfig", cpan_config_dir_candidates())
    ) {
        return $INC{"CPAN/MyConfig.pm"};
    }
    elsif ( $INC{"CPAN/Config.pm"} || _try_loading("CPAN::Config") ) {
        return $INC{"CPAN/Config.pm"};
    }
    else {
        return q{};
    }
}

# Load a module, but ignore "can't locate..." errors
# Optionally take a list of directories to add to @INC for the load
sub _try_loading {
    my ($module, @dirs) = @_;
    (my $file = $module) =~ s{::}{/}g;
    $file .= ".pm";

    local @INC = @INC;
    for my $dir ( @dirs ) {
        if ( -f File::Spec->catfile($dir, $file) ) {
            unshift @INC, $dir;
            last;
        }
    }

    eval { require $file };
    my $err_myconfig = $@;
    if ($err_myconfig and $err_myconfig !~ m#locate \Q$file\E#) {
        die "Error while requiring ${module}:\n$err_myconfig";
    }
    return $INC{$file};
}

sub home () {
    my $home;
    # Suppress load messages until we load the config and know whether
    # load messages are desired.  Otherwise, it's unexpected and odd 
    # why one load message pops up even when verbosity is turned off.
    # This means File::HomeDir load messages are never seen, but I
    # think that's probably OK -- DAGOLDEN
    
    # 5.6.2 seemed to segfault localizing a value in a hashref 
    # so do it manually instead
    my $old_v = $CPAN::Config->{load_module_verbosity};
    $CPAN::Config->{load_module_verbosity} = q[none];
    if ($CPAN::META->has_usable("File::HomeDir")) {
        if ($^O eq 'darwin') {
            $home = File::HomeDir->my_home; # my_data is ~/Library/Application Support on darwin,
                                            # which causes issues in the toolchain.
        }
        else {
            $home = File::HomeDir->my_data || File::HomeDir->my_home;
       }
    }
    unless (defined $home) {
        $home = $ENV{HOME};
    }
    $CPAN::Config->{load_module_verbosity} = $old_v;
    $home;
}

# prioritized list of possible places for finding "CPAN/MyConfig.pm"
sub cpan_config_dir_candidates {
    my @dirs;
    my $old_v = $CPAN::Config->{load_module_verbosity};
    $CPAN::Config->{load_module_verbosity} = q[none];
    if ($CPAN::META->has_usable('File::HomeDir')) {
        if ($^O ne 'darwin') {
            push @dirs, File::HomeDir->my_data;
            # my_data is ~/Library/Application Support on darwin,
            # which causes issues in the toolchain.
        }
        push @dirs, File::HomeDir->my_home;
    }
    push @dirs, $ENV{HOME};
    $CPAN::Config->{load_module_verbosity} = $old_v;
    @dirs = map { "$_/.cpan" } @dirs;
    return wantarray ? @dirs : $dirs[0];
}

sub load {
    my($self, %args) = @_;
    $CPAN::Be_Silent+=0; # protect against 'used only once'
    $CPAN::Be_Silent++ if $args{be_silent}; # do not use; planned to be removed in 2011
    my $do_init = delete $args{do_init} || 0;
    $loading = 0 unless defined $loading;

    my $configpm = require_myconfig_or_config;
    my @miss = $self->missing_config_data;
    CPAN->debug("do_init[$do_init]loading[$loading]miss[@miss]") if $CPAN::DEBUG;
    return unless $do_init || @miss;

    # I'm not how we'd ever wind up in a recursive loop, but I'm leaving
    # this here for safety's sake -- dagolden, 2011-01-19
    return if $loading;
    local $loading = ($loading||0) + 1;

    # Warn if we have a config file, but things were found missing
    if ($configpm && @miss && !$do_init) {
        $args{args} = \@miss;
        $CPAN::Frontend->myprint(<<END);
Sorry, we have to rerun the configuration dialog for CPAN.pm due to
some missing parameters...  Will write to
 <<$configpm>>

END
    }

    require CPAN::FirstTime;
    return CPAN::FirstTime::init($configpm || _new_config_file(), %args);
}

sub _new_config_file {
    my $cpan_config_home = cpan_config_dir_candidates(); # take the first
    my $configpmdir = File::Spec->catdir($cpan_config_home,"CPAN");
    File::Path::mkpath($configpmdir);
    my $configpmtest = File::Spec->catfile($configpmdir,"MyConfig.pm");
    my $configpm = _configpmtest($configpmdir,$configpmtest);
    unless ($configpm) {
        $CPAN::Frontend->mydie(<<"END");
WARNING: CPAN.pm is unable to write a configuration file.  You need write
access to your default perl library directories or you must be able to
create and write to '$configpmtest'.

Aborting configuration.
END
    }
    return $configpm;
}

# returns mandatory but missing entries in the Config
sub missing_config_data {
    my(@miss);
    for (
         "auto_commit",
         "build_cache",
         "build_dir",
         "cache_metadata",
         "cpan_home",
         "ftp_proxy",
         #"gzip",
         "http_proxy",
         "index_expire",
         #"inhibit_startup_message",
         "keep_source_where",
         #"make",
         "make_arg",
         "make_install_arg",
         "makepl_arg",
         "mbuild_arg",
         "mbuild_install_arg",
         ($^O eq "MSWin32" ? "" : "mbuild_install_build_command"),
         "mbuildpl_arg",
         "no_proxy",
         #"pager",
         "prerequisites_policy",
         "scan_cache",
         #"tar",
         #"unzip",
         "urllist",
        ) {
        next unless exists $keys{$_};
        push @miss, $_ unless defined $CPAN::Config->{$_};
    }
    return @miss;
}

sub help {
    $CPAN::Frontend->myprint(q[
Known options:
  commit    commit session changes to disk
  defaults  reload default config values from disk
  help      this help
  init      enter a dialog to set all or a set of parameters

Edit key values as in the following (the "o" is a literal letter o):
  o conf build_cache 15
  o conf build_dir "/foo/bar"
  o conf urllist shift
  o conf urllist unshift ftp://ftp.foo.bar/
  o conf inhibit_startup_message 1

]);
    1; #don't reprint CPAN::Config
}

sub cpl {
    my($word,$line,$pos) = @_;
    $word ||= "";
    CPAN->debug("word[$word] line[$line] pos[$pos]") if $CPAN::DEBUG;
    my(@words) = split " ", substr($line,0,$pos+1);
    if (
        defined($words[2])
        and
        $words[2] =~ /list$/
        and
        (
        @words == 3
        ||
        @words == 4 && length($word)
        )
       ) {
        return grep /^\Q$word\E/, qw(splice shift unshift pop push);
    } elsif (defined($words[2])
             and
             $words[2] eq "init"
             and
            (
             @words == 3
             ||
             @words >= 4 && length($word)
            )) {
        return sort grep /^\Q$word\E/, keys %keys;
    } elsif (@words >= 4) {
        return ();
    }
    my %seen;
    my(@o_conf) =  sort grep { !$seen{$_}++ }
        keys %can,
            keys %$CPAN::Config,
                keys %keys;
    return grep /^\Q$word\E/, @o_conf;
}

sub prefs_lookup {
    my($self,$distro,$what) = @_;

    if ($prefssupport{$what}) {
        return $CPAN::Config->{$what} unless
            $distro
                and $distro->prefs
                    and $distro->prefs->{cpanconfig}
                        and defined $distro->prefs->{cpanconfig}{$what};
        return $distro->prefs->{cpanconfig}{$what};
    } else {
        $CPAN::Frontend->mywarn("Warning: $what not yet officially ".
                                "supported for distroprefs, doing a normal lookup");
        return $CPAN::Config->{$what};
    }
}


{
    package
        CPAN::Config; ####::###### #hide from indexer
    # note: J. Nick Koston wrote me that they are using
    # CPAN::Config->commit although undocumented. I suggested
    # CPAN::Shell->o("conf","commit") even when ugly it is at least
    # documented

    # that's why I added the CPAN::Config class with autoload and
    # deprecated warning

    use strict;
    use vars qw($AUTOLOAD $VERSION);
    $VERSION = "5.5001";

    # formerly CPAN::HandleConfig was known as CPAN::Config
    sub AUTOLOAD { ## no critic
        my $class = shift; # e.g. in dh-make-perl: CPAN::Config
        my($l) = $AUTOLOAD;
        $CPAN::Frontend->mywarn("Dispatching deprecated method '$l' to CPAN::HandleConfig\n");
        $l =~ s/.*:://;
        CPAN::HandleConfig->$l(@_);
    }
}

1;

__END__

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

# Local Variables:
# mode: cperl
# cperl-indent-level: 4
# End:
# vim: ts=4 sts=4 sw=4:
