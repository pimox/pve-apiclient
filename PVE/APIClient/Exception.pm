package PVE::APIClient::Exception;

# a way to add more information to exceptions (see man perlfunc (die))
# use PVE::APIClient::Exception qw(raise);
# raise ("my error message", code => 400, errors => { param1 => "err1", ...} );

use strict;
use warnings;

use base 'Exporter';

use Storable qw(dclone);
use HTTP::Status qw(:constants);

use overload '""' => sub {local $@; shift->stringify};
use overload 'cmp' => sub {
    my ($a, $b) = @_;
    local $@;
    return "$a" cmp "$b"; # compare as string
};

our @EXPORT_OK = qw(raise);

sub new {
    my ($class, $msg, %param) = @_;

    $class = ref($class) || $class;

    my $self = {
	msg => $msg,
    };

    foreach my $p (keys %param) {
	next if defined($self->{$p});
	my $v = $param{$p};
	$self->{$p} = ref($v) ? dclone($v) : $v;
    }

    return bless $self;
}

sub raise {

    my $exc = PVE::APIClient::Exception->new(@_);

    my ($pkg, $filename, $line) = caller;

    $exc->{filename} = $filename;
    $exc->{line} = $line;

    die $exc;
}

sub stringify {
    my $self = shift;

    my $msg = $self->{code} ? "$self->{code} $self->{msg}" : $self->{msg};

    if ($msg !~ m/\n$/) {
	if ($self->{filename} && $self->{line}) {
	    $msg .= " at $self->{filename} line $self->{line}";
	}
	$msg .= "\n";
    }

    if ($self->{errors}) {
	foreach my $e (keys %{$self->{errors}}) {
	    $msg .= "$e: $self->{errors}->{$e}\n";
	}
    }

    if ($self->{propagate}) {
	foreach my $pi (@{$self->{propagate}}) {
	    $msg .= "\t...propagated at $pi->[0] line $pi->[1]\n";
	}
    }

    if ($self->{usage}) {
	$msg .= $self->{usage};
	$msg .= "\n" if $msg !~ m/\n$/;
    }

    return $msg;
}

sub PROPAGATE {
    my ($self, $file, $line) = @_;

    push @{$self->{propagate}}, [$file, $line];

    return $self;
}

1;
