package Carton::Builder;
use strict;
use Class::Tiny {
    mirror => undef,
    cascade => sub { 1 },
    without => sub { [] },
    cpanfile => undef,
    snapshot => undef,
};

sub effective_mirrors {
    my $self = shift;

    # push default CPAN mirror always, as a fallback
    # TODO don't pass fallback if --cached is set?

    my @mirrors = ($self->mirror);
    push @mirrors, Carton::Mirror->default if $self->custom_mirror;
    push @mirrors, Carton::Mirror->new('http://backpan.perl.org/');

    @mirrors;
}

sub custom_mirror {
    my $self = shift;
    ! $self->mirror->is_default;
}

sub bundle {
    my($self, $path, $cache_path, $snapshot) = @_;

    for my $dist ($snapshot->distributions) {
        my $source = $path->child("cache/authors/id/" . $dist->pathname);
        my $target = $cache_path->child("authors/id/" . $dist->pathname);

        if ($source->exists) {
            warn "Copying ", $dist->pathname, "\n";
            $target->parent->mkpath;
            $source->copy($target) or warn "$target: $!";
        } else {
            warn "Couldn't find @{[ $dist->pathname ]}\n";
        }
    }
}

sub install {
    my($self, $path) = @_;

    my @option = (
        "install",
        "-L", $path,
        "--cpanfile", $self->cpanfile->path->stringify
        (map { ("--mirror", $_->url) } $self->effective_mirrors),
    );
    if ($self->snapshot) {
        push @option, (
            "--snapshot" => $self->snapshot->path->stringify,
            "--resolver", "snapshot",
        );
    }
    if ($self->cascade) {
        push @option, "--resolver", "metadb";
    }
    push @option, $self->groups;

    $self->run_cpm(@option)
        or die "Installing modules failed\n";
}

sub groups {
    my $self = shift;
    my @without = @{$self->without};
    if (grep { $_ eq 'develop' } @{$self->without}) {
        return;
    } else {
        return ("--with-develop");
    }
}

sub update {
    my($self, $path, @modules) = @_;

    $self->run_cpm(
        "install",
        "-L", $path,
        (map { ("--mirror", $_->url) } $self->effective_mirrors),
        "--resolver", "metadb",
        @modules
    ) or die "Updating modules failed\n";
}

sub run_cpm {
    my($self, @args) = @_;
    require App::cpm;
    my $cpm = App::cpm->new;
    my $exit = $cpm->run(@args);
    return $exit == 0;
}

1;
