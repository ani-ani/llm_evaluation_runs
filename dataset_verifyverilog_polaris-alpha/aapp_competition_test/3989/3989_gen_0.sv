module div7_digit_rearranger(
  input  [31:0] digits_in,   // 8-digit input (4-bits per digit, MSD-first)
  output reg [31:0] rearranged_out  // 8-digit output (4-bits per digit)
);

  // ------------------------------------------------------------
  // Extract digits (d7 = MSD, d0 = LSD)
  // ------------------------------------------------------------
  wire [3:0] d7 = digits_in[31:28];
  wire [3:0] d6 = digits_in[27:24];
  wire [3:0] d5 = digits_in[23:20];
  wire [3:0] d4 = digits_in[19:16];
  wire [3:0] d3 = digits_in[15:12];
  wire [3:0] d2 = digits_in[11:8];
  wire [3:0] d1 = digits_in[7:4];
  wire [3:0] d0 = digits_in[3:0];

  // ------------------------------------------------------------
  // Identify positions of mandatory digits 1,6,8,9
  // Each mandatory digit must appear exactly once per problem statement.
  // We create one-hot flags and extract remaining digits.
  // ------------------------------------------------------------
  // Flags for whether each nibble equals 1,6,8,9
  function automatic bit is_digit(input [3:0] v, input [3:0] d);
    is_digit = (v == d);
  endfunction

  // Track usage to ensure exactly one of each 1,6,8,9 is removed, but per
  // problem statement we assume input is valid, so we only find and remove.

  // We'll mark digits that are 1,6,8,9; others become remaining digits.
  wire is1_7 = is_digit(d7,4'd1);
  wire is1_6 = is_digit(d6,4'd1);
  wire is1_5 = is_digit(d5,4'd1);
  wire is1_4 = is_digit(d4,4'd1);
  wire is1_3 = is_digit(d3,4'd1);
  wire is1_2 = is_digit(d2,4'd1);
  wire is1_1 = is_digit(d1,4'd1);
  wire is1_0 = is_digit(d0,4'd1);

  wire is6_7 = is_digit(d7,4'd6);
  wire is6_6 = is_digit(d6,4'd6);
  wire is6_5 = is_digit(d5,4'd6);
  wire is6_4 = is_digit(d4,4'd6);
  wire is6_3 = is_digit(d3,4'd6);
  wire is6_2 = is_digit(d2,4'd6);
  wire is6_1 = is_digit(d1,4'd6);
  wire is6_0 = is_digit(d0,4'd6);

  wire is8_7 = is_digit(d7,4'd8);
  wire is8_6 = is_digit(d6,4'd8);
  wire is8_5 = is_digit(d5,4'd8);
  wire is8_4 = is_digit(d4,4'd8);
  wire is8_3 = is_digit(d3,4'd8);
  wire is8_2 = is_digit(d2,4'd8);
  wire is8_1 = is_digit(d1,4'd8);
  wire is8_0 = is_digit(d0,4'd8);

  wire is9_7 = is_digit(d7,4'd9);
  wire is9_6 = is_digit(d6,4'd9);
  wire is9_5 = is_digit(d5,4'd9);
  wire is9_4 = is_digit(d4,4'd9);
  wire is9_3 = is_digit(d3,4'd9);
  wire is9_2 = is_digit(d2,4'd9);
  wire is9_1 = is_digit(d1,4'd9);
  wire is9_0 = is_digit(d0,4'd9);

  // A digit is removed if it's one of 1,6,8,9.
  wire rem_7 = is1_7 | is6_7 | is8_7 | is9_7;
  wire rem_6 = is1_6 | is6_6 | is8_6 | is9_6;
  wire rem_5 = is1_5 | is6_5 | is8_5 | is9_5;
  wire rem_4 = is1_4 | is6_4 | is8_4 | is9_4;
  wire rem_3 = is1_3 | is6_3 | is8_3 | is9_3;
  wire rem_2 = is1_2 | is6_2 | is8_2 | is9_2;
  wire rem_1 = is1_1 | is6_1 | is8_1 | is9_1;
  wire rem_0 = is1_0 | is6_0 | is8_0 | is9_0;

  // ------------------------------------------------------------
  // Collect remaining 4 digits in original order
  // ------------------------------------------------------------
  reg [3:0] r0, r1, r2, r3;  // remaining digits

  always @* begin
    r0 = 4'd0;
    r1 = 4'd0;
    r2 = 4'd0;
    r3 = 4'd0;
    integer idx;
    idx = 0;

    if (!rem_7) begin
      r0 = d7; idx = 1; end
    if (!rem_6) begin
      case (idx)
        0: r0 = d6;
        1: r1 = d6;
        2: r2 = d6;
        3: r3 = d6;
      endcase
      idx = idx + 1;
    end
    if (!rem_5) begin
      case (idx)
        0: r0 = d5;
        1: r1 = d5;
        2: r2 = d5;
        3: r3 = d5;
      endcase
      idx = idx + 1;
    end
    if (!rem_4) begin
      case (idx)
        0: r0 = d4;
        1: r1 = d4;
        2: r2 = d4;
        3: r3 = d4;
      endcase
      idx = idx + 1;
    end
    if (!rem_3) begin
      case (idx)
        0: r0 = d3;
        1: r1 = d3;
        2: r2 = d3;
        3: r3 = d3;
      endcase
      idx = idx + 1;
    end
    if (!rem_2) begin
      case (idx)
        0: r0 = d2;
        1: r1 = d2;
        2: r2 = d2;
        3: r3 = d2;
      endcase
      idx = idx + 1;
    end
    if (!rem_1) begin
      case (idx)
        0: r0 = d1;
        1: r1 = d1;
        2: r2 = d1;
        3: r3 = d1;
      endcase
      idx = idx + 1;
    end
    if (!rem_0) begin
      case (idx)
        0: r0 = d0;
        1: r1 = d0;
        2: r2 = d0;
        3: r3 = d0;
      endcase
      // idx = idx + 1; // not needed further
    end
  end

  // ------------------------------------------------------------
  // Sort remaining digits in descending order (simple combinational sort)
  // ------------------------------------------------------------
  function automatic void sort4_desc(
    input  [3:0] in0, input [3:0] in1, input [3:0] in2, input [3:0] in3,
    output [3:0] o0, output [3:0] o1, output [3:0] o2, output [3:0] o3
  );
    reg [3:0] a0,a1,a2,a3;
    reg [3:0] t;
    begin
      a0 = in0; a1 = in1; a2 = in2; a3 = in3;
      if (a0 < a1) begin t=a0; a0=a1; a1=t; end
      if (a2 < a3) begin t=a2; a2=a3; a3=t; end
      if (a0 < a2) begin t=a0; a0=a2; a2=t; end
      if (a1 < a3) begin t=a1; a1=a3; a3=t; end
      if (a1 < a2) begin t=a1; a1=a2; a2=t; end
      o0 = a0; o1 = a1; o2 = a2; o3 = a3;
    end
  endfunction

  wire [3:0] s0, s1, s2, s3; // sorted remaining digits (desc)
  assign {s0,s1,s2,s3} = {4'(0)}; // dummy to keep tools quiet; real values via function below

  // We must call function within an always_comb block to get wires
  reg [3:0] rs0, rs1, rs2, rs3;
  always @* begin
    sort4_desc(r0, r1, r2, r3, rs0, rs1, rs2, rs3);
  end

  // ------------------------------------------------------------
  // Compute (remaining_num * 10000) % 7
  // remaining_num = rs0 rs1 rs2 rs3 (as decimal digits)
  // 10000 % 7 = 4
  // So (remaining_num * 10000) % 7 = (remaining_num % 7) * 4 % 7
  // remaining_num % 7 is computed digit-wise.
  // ------------------------------------------------------------
  function automatic [2:0] mod7_digit_add(input [2:0] cur, input [3:0] dig);
    // new = (cur*10 + dig) % 7
    reg [5:0] tmp;
    begin
      tmp = cur * 6'd10 + dig[3:0];
      mod7_digit_add = tmp % 6'd7;
    end
  endfunction

  reg [2:0] rem_mod;
  always @* begin
    rem_mod = 3'd0;
    rem_mod = mod7_digit_add(rem_mod, rs0);
    rem_mod = mod7_digit_add(rem_mod, rs1);
    rem_mod = mod7_digit_add(rem_mod, rs2);
    rem_mod = mod7_digit_add(rem_mod, rs3);
    // multiply by 10000: *4 mod 7
    rem_mod = (rem_mod * 3'd4) % 3'd7;
  end

  // ------------------------------------------------------------
  // Precomputed permutations of 1,6,8,9 (seven specific ones as given)
  // We'll store their decimal values and their mod7 values.
  // permutations: 1869, 1968, 1689, 6198, 1698, 9861, 1896
  // ------------------------------------------------------------
  localparam int NUM_PERM = 7;

  // Each perm encoded as 16b: d3 d2 d1 d0 (MSD->LSD), 4b each
  localparam [15:0] PERM_D [0:NUM_PERM-1] = '{
    16'h1_8_6_9, // 1869
    16'h1_9_6_8, // 1968
    16'h1_6_8_9, // 1689
    16'h6_1_9_8, // 6198
    16'h1_6_9_8, // 1698
    16'h9_8_6_1, // 9861
    16'h1_8_9_6  // 1896
  };

  // Precompute their value mod7
  function automatic [2:0] perm_mod7(input [15:0] p);
    reg [3:0] a,b,c,d;
    reg [2:0] r;
    begin
      a = p[15:12];
      b = p[11:8];
      c = p[7:4];
      d = p[3:0];
      r = 3'd0;
      r = mod7_digit_add(r, a);
      r = mod7_digit_add(r, b);
      r = mod7_digit_add(r, c);
      r = mod7_digit_add(r, d);
      perm_mod7 = r;
    end
  endfunction

  // Build a constant array of mod7 values
  wire [2:0] PERM_M7 [0:NUM_PERM-1];
  assign PERM_M7[0] = perm_mod7(PERM_D[0]);
  assign PERM_M7[1] = perm_mod7(PERM_D[1]);
  assign PERM_M7[2] = perm_mod7(PERM_D[2]);
  assign PERM_M7[3] = perm_mod7(PERM_D[3]);
  assign PERM_M7[4] = perm_mod7(PERM_D[4]);
  assign PERM_M7[5] = perm_mod7(PERM_D[5]);
  assign PERM_M7[6] = perm_mod7(PERM_D[6]);

  // ------------------------------------------------------------
  // Choose permutation such that (rem_mod + perm_mod) %7 == 0
  // ------------------------------------------------------------
  reg [15:0] selected_perm;
  always @* begin
    selected_perm = 16'h0;
    integer i;
    for (i = 0; i < NUM_PERM; i = i + 1) begin
      if (((rem_mod + PERM_M7[i]) % 3'd7) == 3'd0 && selected_perm == 16'h0) begin
        selected_perm = PERM_D[i];
      end
    end
    // In valid inputs, exactly one should match.
    // If none matched (shouldn't happen), default to first.
    if (selected_perm == 16'h0)
      selected_perm = PERM_D[0];
  end

  // ------------------------------------------------------------
  // Construct output:
  // remaining_digits_sorted_desc + selected_perm
  // (Trailing zeros requirement is naturally met since zeros in remaining
  // digits are sorted to the right; no extra padding beyond 8 digits.)
  // Ensure no leading zero: problem guarantees such arrangement exists.
  // ------------------------------------------------------------
  always @* begin
    rearranged_out[31:28] = rs0;
    rearranged_out[27:24] = rs1;
    rearranged_out[23:20] = rs2;
    rearranged_out[19:16] = rs3;
    rearranged_out[15:12] = selected_perm[15:12];
    rearranged_out[11:8]  = selected_perm[11:8];
    rearranged_out[7:4]   = selected_perm[7:4];
    rearranged_out[3:0]   = selected_perm[3:0];
  end

endmodule