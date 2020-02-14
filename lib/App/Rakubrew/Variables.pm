package App::Rakubrew::Variables;
require Exporter;
our @ISA = qw( Exporter );
our @EXPORT = qw( $brew_name $brew_exec $env_var $local_filename $prefix $versions_dir $shim_dir $git_reference $GIT $GIT_PROTO $PERL5 %git_repos %impls );

use strict;
use warnings;
use 5.010;

use FindBin qw($RealBin);
use File::Spec::Functions qw(catfile catdir updir);
use Cwd qw(abs_path);
use File::HomeDir;
use App::Rakubrew::Config;

our $brew_name = 'rakubrew';
our $brew_exec = catfile($RealBin, $brew_name);
if ($^O =~ /win32/i ) {
    $brew_exec .= ($distro_format eq 'cpan') ? '.bat' : '.exe';
}
our $home_env_var = 'RAKUBREW_HOME';
our $env_var = 'RAKUBREW_VERSION';
our $local_filename = '.raku-version';

our $prefix = $ENV{$home_env_var}
    // catdir(File::HomeDir->my_data,
        $^O =~ /win32/i ? 'rakubrew' :
        # heuristic to determine whether the folder should be hidden:
        # If it's located in a hidden folder already, don't hide.
        # The typical case would be an XDG environment where
        # File::HomeDir->my_data is ~/.local/share
        File::HomeDir->my_data =~ /\/\./ ? 'rakubrew' :
        '.rakubrew');

$prefix = abs_path($prefix) if (-d $prefix);

$prefix .= '/' if $prefix =~ /\/\z/;

our $versions_dir = catdir($prefix, 'versions');
our $shim_dir = catdir($prefix, 'shims');
our $git_reference = catdir($prefix, 'git_reference');

our $GIT       = $ENV{GIT_BINARY} // 'git';
our $GIT_PROTO = $ENV{GIT_PROTOCOL} // 'git';
our $PERL5     = $^X;

sub get_git_url {
    my ($protocol, $host, $user, $project) = @_;
    if ($protocol eq "ssh") {
        return "git\@${host}:${user}/${project}.git";
    } else {
        return "${protocol}://${host}/${user}/${project}.git";
    }
}

our %git_repos = (
    rakudo => get_git_url($GIT_PROTO, 'github.com', 'rakudo', 'rakudo'),
    MoarVM => get_git_url($GIT_PROTO, 'github.com', 'MoarVM', 'MoarVM'),
    nqp    => get_git_url($GIT_PROTO, 'github.com', 'perl6',  'nqp'),
    zef    => get_git_url($GIT_PROTO, 'github.com', 'ugexe',  'zef'),
);

our %impls = (
    jvm => {
        name      => "jvm",
        weight    => 20,
        configure => "$PERL5 Configure.pl --backends=jvm --gen-nqp --make-install",
        need_repo => ['rakudo', 'nqp'],
    },
    moar => {
        name      => "moar",
        weight    => 30,
        configure => "$PERL5 Configure.pl --backends=moar --gen-moar --make-install",
        need_repo => ['rakudo', 'nqp', 'MoarVM'],
    },
    'moar-blead' => {
        name      => "moar-blead",
        weight    => 35,
        configure => "$PERL5 Configure.pl --backends=moar --gen-moar=master --gen-nqp=master --make-install",
        need_repo => ['rakudo', 'nqp', 'MoarVM'],
    },
);

1;

