package App::Rakudobrew::Build;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw();

use strict;
use warnings;
use 5.010;
use File::Spec::Functions qw(catdir updir);
use Cwd qw(cwd);
use App::Rakudobrew::Variables;
use App::Rakudobrew::Tools;
use App::Rakudobrew::VersionHandling;

sub available_rakudos {
    my @output = qx|$GIT ls-remote --tags $git_repos{rakudo}|;
    my @tags = grep(m{refs/tags/([^\^]+)\^\{\}}, @output);
    @tags = map(m{tags/([^\^]+)\^}, @tags);
    @tags = grep(/^\d/, @tags);
    return sort(@tags), 'master';
}

sub build_impl {
    my ($impl, $ver, $configure_opts) = @_;

    my $name = "$impl-$ver";
    $name = $impl if $impl eq 'moar-blead' && $ver eq 'master';

    chdir $versions_dir;
    unless (-d $name) {
        for(@{$impls{$impl}{need_repo}}) {
            update_git_reference($_);
        }
        run "$GIT clone --reference \"$git_reference/rakudo\" $git_repos{rakudo} $name";
    }
    chdir $name;
    run "$GIT fetch";
    # when people say 'build somebranch', they usually mean 'build origin/somebranch'
    my $ver_to_checkout = $ver;
    eval {
        run "$GIT rev-parse -q --verify origin/$ver";
        $ver_to_checkout = "origin/$ver";
    };
    run "$GIT checkout $ver_to_checkout";

    run $impls{$impl}{configure} . " $configure_opts";
}

sub determine_make {
    my $makefile = shift;
    $makefile = slurp($makefile);

    if($makefile =~ /^MAKE\s*=\s*(\w+)\s*$/m) {
        return $1;
    }
    else {
        say STDERR "Couldn't determine correct make program. Aborting.";
        exit 1;
    }
}

sub build_triple {
    my ($rakudo_ver, $nqp_ver, $moar_ver) = @_;
    my $impl = "moar";
    $rakudo_ver //= 'HEAD';
    $nqp_ver //= 'HEAD';
    $moar_ver //= 'HEAD';
    chdir $versions_dir;
    my $name = "$impl-$rakudo_ver-$nqp_ver-$moar_ver";
    unless (-d $name) {
        update_git_reference('rakudo');
        run "$GIT clone --reference \"$git_reference/rakudo\" $git_repos{rakudo} $name";
    }
    chdir $name;
    run "$GIT pull";
    run "$GIT checkout $rakudo_ver";
    if (-e 'Makefile') {
        run(determine_make('Makefile'), 'install');
    }

    unless (-d "nqp") {
        update_git_reference('nqp');
        run "$GIT clone --reference \"$git_reference/nqp\" $git_repos{nqp}";
    }
    chdir "nqp";
    run "$GIT pull";
    run "$GIT checkout $nqp_ver";

    unless (-d "MoarVM") {
        update_git_reference('MoarVM');
        run "$GIT clone --reference \"$git_reference/MoarVM\" $git_repos{MoarVM}";
    }
    chdir "MoarVM";
    run "$GIT pull";
    run "$GIT checkout $moar_ver";
    run "$PERL5 Configure.pl --prefix=" . catdir(updir(), updir(), 'install') . ' --make-install';

    chdir updir();
    run "$PERL5 Configure.pl --backend=moar --prefix=" . catdir(updir(), 'install') . ' --make-install';

    chdir updir();
    run "$PERL5 Configure.pl --backend=moar --make-install";

    if (-d 'zef') {
        say "Updating zef as well";
        build_zef($name);
    }

    return $name;
}

sub build_zef {
    my $version = shift;
    chdir catdir($versions_dir, $version);
    unless (-d 'zef') {
        run "$GIT clone $git_repos{zef}";
    }
    chdir 'zef';
    run "$GIT pull -q";
    run "$GIT checkout";
    run which('perl6', $version) . " -Ilib bin/zef test .";
    run which('perl6', $version) . " -Ilib bin/zef --/test --force install .";
}

sub update_git_reference {
    my $repo = shift;
    my $back = cwd();
    print "Update git reference: $repo\n";
    chdir $git_reference;
    unless (-d $repo) {
        run "$GIT clone $git_repos{$repo} $repo";
    }
    chdir $repo;
    run "$GIT pull";
    chdir $back;
}

sub available_backends {
    map {$_->{name}} sort {$a->{weight} <=> $b->{weight}} values %impls;
}


1;

