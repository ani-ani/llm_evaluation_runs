module interesting_problemset(
  input  [15:0] valid,
  input  [63:0] problems,
  output result
);

  wire has_zero_problem;
  wire has_disjoint_pair;

  // Check for any valid problem that is all zeros
  assign has_zero_problem =
    ((valid[0]  & ~|problems[3:0])        ) |
    ((valid[1]  & ~|problems[7:4])        ) |
    ((valid[2]  & ~|problems[11:8])       ) |
    ((valid[3]  & ~|problems[15:12])      ) |
    ((valid[4]  & ~|problems[19:16])      ) |
    ((valid[5]  & ~|problems[23:20])      ) |
    ((valid[6]  & ~|problems[27:24])      ) |
    ((valid[7]  & ~|problems[31:28])      ) |
    ((valid[8]  & ~|problems[35:32])      ) |
    ((valid[9]  & ~|problems[39:36])      ) |
    ((valid[10] & ~|problems[43:40])      ) |
    ((valid[11] & ~|problems[47:44])      ) |
    ((valid[12] & ~|problems[51:48])      ) |
    ((valid[13] & ~|problems[55:52])      ) |
    ((valid[14] & ~|problems[59:56])      ) |
    ((valid[15] & ~|problems[63:60])      );

  // Extract each 4-bit problem for readability
  wire [3:0] p [15:0];
  assign p[0]  = problems[3:0];
  assign p[1]  = problems[7:4];
  assign p[2]  = problems[11:8];
  assign p[3]  = problems[15:12];
  assign p[4]  = problems[19:16];
  assign p[5]  = problems[23:20];
  assign p[6]  = problems[27:24];
  assign p[7]  = problems[31:28];
  assign p[8]  = problems[35:32];
  assign p[9]  = problems[39:36];
  assign p[10] = problems[43:40];
  assign p[11] = problems[47:44];
  assign p[12] = problems[51:48];
  assign p[13] = problems[55:52];
  assign p[14] = problems[59:56];
  assign p[15] = problems[63:60];

  // Check for any two different valid problems i and j where (p[i] & p[j]) == 0
  assign has_disjoint_pair =
    ((valid[0]  & valid[1]  & ~|(p[0]  & p[1])) )  |
    ((valid[0]  & valid[2]  & ~|(p[0]  & p[2])) )  |
    ((valid[0]  & valid[3]  & ~|(p[0]  & p[3])) )  |
    ((valid[0]  & valid[4]  & ~|(p[0]  & p[4])) )  |
    ((valid[0]  & valid[5]  & ~|(p[0]  & p[5])) )  |
    ((valid[0]  & valid[6]  & ~|(p[0]  & p[6])) )  |
    ((valid[0]  & valid[7]  & ~|(p[0]  & p[7])) )  |
    ((valid[0]  & valid[8]  & ~|(p[0]  & p[8])) )  |
    ((valid[0]  & valid[9]  & ~|(p[0]  & p[9])) )  |
    ((valid[0]  & valid[10] & ~|(p[0]  & p[10])) ) |
    ((valid[0]  & valid[11] & ~|(p[0]  & p[11])) ) |
    ((valid[0]  & valid[12] & ~|(p[0]  & p[12])) ) |
    ((valid[0]  & valid[13] & ~|(p[0]  & p[13])) ) |
    ((valid[0]  & valid[14] & ~|(p[0]  & p[14])) ) |
    ((valid[0]  & valid[15] & ~|(p[0]  & p[15])) ) |

    ((valid[1]  & valid[2]  & ~|(p[1]  & p[2])) )  |
    ((valid[1]  & valid[3]  & ~|(p[1]  & p[3])) )  |
    ((valid[1]  & valid[4]  & ~|(p[1]  & p[4])) )  |
    ((valid[1]  & valid[5]  & ~|(p[1]  & p[5])) )  |
    ((valid[1]  & valid[6]  & ~|(p[1]  & p[6])) )  |
    ((valid[1]  & valid[7]  & ~|(p[1]  & p[7])) )  |
    ((valid[1]  & valid[8]  & ~|(p[1]  & p[8])) )  |
    ((valid[1]  & valid[9]  & ~|(p[1]  & p[9])) )  |
    ((valid[1]  & valid[10] & ~|(p[1]  & p[10])) ) |
    ((valid[1]  & valid[11] & ~|(p[1]  & p[11])) ) |
    ((valid[1]  & valid[12] & ~|(p[1]  & p[12])) ) |
    ((valid[1]  & valid[13] & ~|(p[1]  & p[13])) ) |
    ((valid[1]  & valid[14] & ~|(p[1]  & p[14])) ) |
    ((valid[1]  & valid[15] & ~|(p[1]  & p[15])) ) |

    ((valid[2]  & valid[3]  & ~|(p[2]  & p[3])) )  |
    ((valid[2]  & valid[4]  & ~|(p[2]  & p[4])) )  |
    ((valid[2]  & valid[5]  & ~|(p[2]  & p[5])) )  |
    ((valid[2]  & valid[6]  & ~|(p[2]  & p[6])) )  |
    ((valid[2]  & valid[7]  & ~|(p[2]  & p[7])) )  |
    ((valid[2]  & valid[8]  & ~|(p[2]  & p[8])) )  |
    ((valid[2]  & valid[9]  & ~|(p[2]  & p[9])) )  |
    ((valid[2]  & valid[10] & ~|(p[2]  & p[10])) ) |
    ((valid[2]  & valid[11] & ~|(p[2]  & p[11])) ) |
    ((valid[2]  & valid[12] & ~|(p[2]  & p[12])) ) |
    ((valid[2]  & valid[13] & ~|(p[2]  & p[13])) ) |
    ((valid[2]  & valid[14] & ~|(p[2]  & p[14])) ) |
    ((valid[2]  & valid[15] & ~|(p[2]  & p[15])) ) |

    ((valid[3]  & valid[4]  & ~|(p[3]  & p[4])) )  |
    ((valid[3]  & valid[5]  & ~|(p[3]  & p[5])) )  |
    ((valid[3]  & valid[6]  & ~|(p[3]  & p[6])) )  |
    ((valid[3]  & valid[7]  & ~|(p[3]  & p[7])) )  |
    ((valid[3]  & valid[8]  & ~|(p[3]  & p[8])) )  |
    ((valid[3]  & valid[9]  & ~|(p[3]  & p[9])) )  |
    ((valid[3]  & valid[10] & ~|(p[3]  & p[10])) ) |
    ((valid[3]  & valid[11] & ~|(p[3]  & p[11])) ) |
    ((valid[3]  & valid[12] & ~|(p[3]  & p[12])) ) |
    ((valid[3]  & valid[13] & ~|(p[3]  & p[13])) ) |
    ((valid[3]  & valid[14] & ~|(p[3]  & p[14])) ) |
    ((valid[3]  & valid[15] & ~|(p[3]  & p[15])) ) |

    ((valid[4]  & valid[5]  & ~|(p[4]  & p[5])) )  |
    ((valid[4]  & valid[6]  & ~|(p[4]  & p[6])) )  |
    ((valid[4]  & valid[7]  & ~|(p[4]  & p[7])) )  |
    ((valid[4]  & valid[8]  & ~|(p[4]  & p[8])) )  |
    ((valid[4]  & valid[9]  & ~|(p[4]  & p[9])) )  |
    ((valid[4]  & valid[10] & ~|(p[4]  & p[10])) ) |
    ((valid[4]  & valid[11] & ~|(p[4]  & p[11])) ) |
    ((valid[4]  & valid[12] & ~|(p[4]  & p[12])) ) |
    ((valid[4]  & valid[13] & ~|(p[4]  & p[13])) ) |
    ((valid[4]  & valid[14] & ~|(p[4]  & p[14])) ) |
    ((valid[4]  & valid[15] & ~|(p[4]  & p[15])) ) |

    ((valid[5]  & valid[6]  & ~|(p[5]  & p[6])) )  |
    ((valid[5]  & valid[7]  & ~|(p[5]  & p[7])) )  |
    ((valid[5]  & valid[8]  & ~|(p[5]  & p[8])) )  |
    ((valid[5]  & valid[9]  & ~|(p[5]  & p[9])) )  |
    ((valid[5]  & valid[10] & ~|(p[5]  & p[10])) ) |
    ((valid[5]  & valid[11] & ~|(p[5]  & p[11])) ) |
    ((valid[5]  & valid[12] & ~|(p[5]  & p[12])) ) |
    ((valid[5]  & valid[13] & ~|(p[5]  & p[13])) ) |
    ((valid[5]  & valid[14] & ~|(p[5]  & p[14])) ) |
    ((valid[5]  & valid[15] & ~|(p[5]  & p[15])) ) |

    ((valid[6]  & valid[7]  & ~|(p[6]  & p[7])) )  |
    ((valid[6]  & valid[8]  & ~|(p[6]  & p[8])) )  |
    ((valid[6]  & valid[9]  & ~|(p[6]  & p[9])) )  |
    ((valid[6]  & valid[10] & ~|(p[6]  & p[10])) ) |
    ((valid[6]  & valid[11] & ~|(p[6]  & p[11])) ) |
    ((valid[6]  & valid[12] & ~|(p[6]  & p[12])) ) |
    ((valid[6]  & valid[13] & ~|(p[6]  & p[13])) ) |
    ((valid[6]  & valid[14] & ~|(p[6]  & p[14])) ) |
    ((valid[6]  & valid[15] & ~|(p[6]  & p[15])) ) |

    ((valid[7]  & valid[8]  & ~|(p[7]  & p[8])) )  |
    ((valid[7]  & valid[9]  & ~|(p[7]  & p[9])) )  |
    ((valid[7]  & valid[10] & ~|(p[7]  & p[10])) ) |
    ((valid[7]  & valid[11] & ~|(p[7]  & p[11])) ) |
    ((valid[7]  & valid[12] & ~|(p[7]  & p[12])) ) |
    ((valid[7]  & valid[13] & ~|(p[7]  & p[13])) ) |
    ((valid[7]  & valid[14] & ~|(p[7]  & p[14])) ) |
    ((valid[7]  & valid[15] & ~|(p[7]  & p[15])) ) |

    ((valid[8]  & valid[9]  & ~|(p[8]  & p[9])) )  |
    ((valid[8]  & valid[10] & ~|(p[8]  & p[10])) ) |
    ((valid[8]  & valid[11] & ~|(p[8]  & p[11])) ) |
    ((valid[8]  & valid[12] & ~|(p[8]  & p[12])) ) |
    ((valid[8]  & valid[13] & ~|(p[8]  & p[13])) ) |
    ((valid[8]  & valid[14] & ~|(p[8]  & p[14])) ) |
    ((valid[8]  & valid[15] & ~|(p[8]  & p[15])) ) |

    ((valid[9]  & valid[10] & ~|(p[9]  & p[10])) ) |
    ((valid[9]  & valid[11] & ~|(p[9]  & p[11])) ) |
    ((valid[9]  & valid[12] & ~|(p[9]  & p[12])) ) |
    ((valid[9]  & valid[13] & ~|(p[9]  & p[13])) ) |
    ((valid[9]  & valid[14] & ~|(p[9]  & p[14])) ) |
    ((valid[9]  & valid[15] & ~|(p[9]  & p[15])) ) |

    ((valid[10] & valid[11] & ~|(p[10] & p[11])) ) |
    ((valid[10] & valid[12] & ~|(p[10] & p[12])) ) |
    ((valid[10] & valid[13] & ~|(p[10] & p[13])) ) |
    ((valid[10] & valid[14] & ~|(p[10] & p[14])) ) |
    ((valid[10] & valid[15] & ~|(p[10] & p[15])) ) |

    ((valid[11] & valid[12] & ~|(p[11] & p[12])) ) |
    ((valid[11] & valid[13] & ~|(p[11] & p[13])) ) |
    ((valid[11] & valid[14] & ~|(p[11] & p[14])) ) |
    ((valid[11] & valid[15] & ~|(p[11] & p[15])) ) |

    ((valid[12] & valid[13] & ~|(p[12] & p[13])) ) |
    ((valid[12] & valid[14] & ~|(p[12] & p[14])) ) |
    ((valid[12] & valid[15] & ~|(p[12] & p[15])) ) |

    ((valid[13] & valid[14] & ~|(p[13] & p[14])) ) |
    ((valid[13] & valid[15] & ~|(p[13] & p[15])) ) |

    ((valid[14] & valid[15] & ~|(p[14] & p[15])) );

  assign result = has_zero_problem | has_disjoint_pair;

endmodule