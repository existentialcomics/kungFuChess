sub movingOppositeDirs {
    my ($a, $b) = @_;

    if ($a == NORTH) { return $b == SOUTH; }
    if ($a == SOUTH) { return $b == NORTH; }
    if ($a == EAST)  { return $b == WEST;  }
    if ($a == WEST)  { return $b == EAST;  }
    if ($a == NORTH_EAST)  { return $b == SOUTH_WEST;  }
    if ($a == SOUTH_EAST)  { return $b == NORTH_WEST;  }
    if ($a == NORTH_WEST)  { return $b == SOUTH_EAST;  }
    if ($a == SOUTH_WEST)  { return $b == NORTH_EAST;  }

    ### should get here
    return 0;
}





1;
