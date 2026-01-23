module eulerian_number (
  input [3:0] n,
  input [3:0] m,
  output [15:0] result
);

  // Precomputed Eulerian numbers for n=0 to 8, m=0 to 7
  // Stored as a 2D array (n x m)
  localparam [15:0] eulerian_table [0:8][0:7] = '
  {
    '0, // n=0 (all m)
    '{1, 0, 0, 0, 0, 0, 0, 0}, // n=1
    '{1, 1, 0, 0, 0, 0, 0, 0}, // n=2
    '{1, 4, 1, 0, 0, 0, 0, 0}, // n=3
    '{1, 11, 11, 1, 0, 0, 0, 0}, // n=4
    '{1, 26, 66, 26, 1, 0, 0, 0}, // n=5
    '{1, 57, 302, 302, 57, 1, 0, 0}, // n=6
    '{1, 120, 1191, 2416, 1191, 120, 1, 0}, // n=7
    '{1, 247, 4293, 15619, 15619, 4293, 247, 1}  // n=8
  };

  // Default output is 0 for invalid cases
  assign result = (n > 8 || m >= n) ? 0 : eulerian_table[n][m];

endmodule