module undulating_check (
  input  reg [31:0] num,
  output logic       is_undulating
);

  // Extract 8 digits (each 4 bits): d0 is the most significant nibble
  logic [3:0] d0, d1, d2, d3, d4, d5, d6, d7;
  assign d0 = num[31:28];
  assign d1 = num[27:24];
  assign d2 = num[23:20];
  assign d3 = num[19:16];
  assign d4 = num[15:12];
  assign d5 = num[11: 8];
  assign d6 = num[ 7: 4];
  assign d7 = num[ 3: 0];

  // Check all conditions simultaneously
  logic cond_a, cond_b, cond_c;
  assign cond_a = (d0 == d2) && (d0 == d4) && (d0 == d6);
  assign cond_b = (d1 == d3) && (d1 == d5) && (d1 == d7);
  assign cond_c = (d0 != d1);

  assign is_undulating = cond_a && cond_b && cond_c;

endmodule
