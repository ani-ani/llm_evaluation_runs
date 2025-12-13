module max_game_score(
  input  [3:0]      n,
  input  [15:0]     arr [0:7],
  output reg [31:0] score
);

  // Local wires for sorting network (bitonic-style for 8 elements)
  wire [15:0] s0 [0:7];
  wire [15:0] s1 [0:7];
  wire [15:0] s2 [0:7];
  wire [15:0] s3 [0:7];
  wire [15:0] s4 [0:7];
  wire [15:0] s5 [0:7];

  // Stage 0: initial compare-swap pairs
  assign {s0[0], s0[1]} = (arr[0] <= arr[1]) ? {arr[0], arr[1]} : {arr[1], arr[0]};
  assign {s0[2], s0[3]} = (arr[2] <= arr[3]) ? {arr[2], arr[3]} : {arr[3], arr[2]};
  assign {s0[4], s0[5]} = (arr[4] <= arr[5]) ? {arr[4], arr[5]} : {arr[5], arr[4]};
  assign {s0[6], s0[7]} = (arr[6] <= arr[7]) ? {arr[6], arr[7]} : {arr[7], arr[6]};

  // Stage 1
  assign {s1[0], s1[2]} = (s0[0] <= s0[2]) ? {s0[0], s0[2]} : {s0[2], s0[0]};
  assign {s1[1], s1[3]} = (s0[1] <= s0[3]) ? {s0[1], s0[3]} : {s0[3], s0[1]};
  assign {s1[4], s1[6]} = (s0[4] <= s0[6]) ? {s0[4], s0[6]} : {s0[6], s0[4]};
  assign {s1[5], s1[7]} = (s0[5] <= s0[7]) ? {s0[5], s0[7]} : {s0[7], s0[5]};

  // Preserve untouched
  // After Stage 1, elements are partially ordered; build next stage signals

  // Stage 2
  assign {s2[1], s2[2]} = (s1[1] <= s1[2]) ? {s1[1], s1[2]} : {s1[2], s1[1]};
  assign {s2[5], s2[6]} = (s1[5] <= s1[6]) ? {s1[5], s1[6]} : {s1[6], s1[5]};

  assign s2[0] = s1[0];
  assign s2[3] = s1[3];
  assign s2[4] = s1[4];
  assign s2[7] = s1[7];

  // Stage 3
  assign {s3[0], s3[4]} = (s2[0] <= s2[4]) ? {s2[0], s2[4]} : {s2[4], s2[0]};
  assign {s3[1], s3[5]} = (s2[1] <= s2[5]) ? {s2[1], s2[5]} : {s2[5], s2[1]};
  assign {s3[2], s3[6]} = (s2[2] <= s2[6]) ? {s2[2], s2[6]} : {s2[6], s2[2]};
  assign {s3[3], s3[7]} = (s2[3] <= s2[7]) ? {s2[3], s2[7]} : {s2[7], s2[3]};

  // Stage 4
  assign {s4[2], s4[4]} = (s3[2] <= s3[4]) ? {s3[2], s3[4]} : {s3[4], s3[2]};
  assign {s4[3], s4[5]} = (s3[3] <= s3[5]) ? {s3[3], s3[5]} : {s3[5], s3[3]};

  assign s4[0] = s3[0];
  assign s4[1] = s3[1];
  assign s4[6] = s3[6];
  assign s4[7] = s3[7];

  // Stage 5 (final ordering adjustments)
  assign {s5[1], s5[2]} = (s4[1] <= s4[2]) ? {s4[1], s4[2]} : {s4[2], s4[1]};
  assign {s5[3], s5[4]} = (s4[3] <= s4[4]) ? {s4[3], s4[4]} : {s4[4], s4[3]};
  assign {s5[5], s5[6]} = (s4[5] <= s4[6]) ? {s4[5], s4[6]} : {s4[6], s4[5]};

  assign s5[0] = s4[0];
  assign s5[7] = s4[7];

  // s5[0..7] are the 8-element sorted (ascending) array

  // Masked selection based on n (1..8). For n < index, treat value as 0 and exclude from sums.
  wire [15:0] v0 = (n >= 4'd1) ? s5[0] : 16'd0;
  wire [15:0] v1 = (n >= 4'd2) ? s5[1] : 16'd0;
  wire [15:0] v2 = (n >= 4'd3) ? s5[2] : 16'd0;
  wire [15:0] v3 = (n >= 4'd4) ? s5[3] : 16'd0;
  wire [15:0] v4 = (n >= 4'd5) ? s5[4] : 16'd0;
  wire [15:0] v5 = (n >= 4'd6) ? s5[5] : 16'd0;
  wire [15:0] v6 = (n >= 4'd7) ? s5[6] : 16'd0;
  wire [15:0] v7 = (n >= 4'd8) ? s5[7] : 16'd0;

  // Pre-compute weighted contributions for positions 0..7 assuming
  // weights (i+2) except the last valid element which uses weight n.

  // For each index i, base weight = i+2.
  // We'll compute two candidate products:
  // - base_w_i = v_i * (i+2)
  // - alt_w_i  = v_i * n (used only if i is the last valid index n-1 and n>1)

  wire [31:0] base0 = v0 * 32'd2;
  wire [31:0] base1 = v1 * 32'd3;
  wire [31:0] base2 = v2 * 32'd4;
  wire [31:0] base3 = v3 * 32'd5;
  wire [31:0] base4 = v4 * 32'd6;
  wire [31:0] base5 = v5 * 32'd7;
  wire [31:0] base6 = v6 * 32'd8;
  wire [31:0] base7 = v7 * 32'd9;

  wire [31:0] alt0  = v0 * n;
  wire [31:0] alt1  = v1 * n;
  wire [31:0] alt2  = v2 * n;
  wire [31:0] alt3  = v3 * n;
  wire [31:0] alt4  = v4 * n;
  wire [31:0] alt5  = v5 * n;
  wire [31:0] alt6  = v6 * n;
  wire [31:0] alt7  = v7 * n;

  // Select per-index weight: for i == n-1 and n>1 use alt (n), else base.
  wire use_alt0 = (n > 4'd1) && (4'd0 == (n - 1'b1));
  wire use_alt1 = (n > 4'd1) && (4'd1 == (n - 1'b1));
  wire use_alt2 = (n > 4'd1) && (4'd2 == (n - 1'b1));
  wire use_alt3 = (n > 4'd1) && (4'd3 == (n - 1'b1));
  wire use_alt4 = (n > 4'd1) && (4'd4 == (n - 1'b1));
  wire use_alt5 = (n > 4'd1) && (4'd5 == (n - 1'b1));
  wire use_alt6 = (n > 4'd1) && (4'd6 == (n - 1'b1));
  wire use_alt7 = (n > 4'd1) && (4'd7 == (n - 1'b1));

  wire [31:0] w0 = use_alt0 ? alt0 : base0;
  wire [31:0] w1 = use_alt1 ? alt1 : base1;
  wire [31:0] w2 = use_alt2 ? alt2 : base2;
  wire [31:0] w3 = use_alt3 ? alt3 : base3;
  wire [31:0] w4 = use_alt4 ? alt4 : base4;
  wire [31:0] w5 = use_alt5 ? alt5 : base5;
  wire [31:0] w6 = use_alt6 ? alt6 : base6;
  wire [31:0] w7 = use_alt7 ? alt7 : base7;

  // For n == 0: score = 0.
  // For n == 1: score = sorted_arr[0] = v0.
  // For n > 1: score = sum of w0..w7 considering v_i masked by n as above.

  wire [31:0] sum_base = w0 + w1 + w2 + w3 + w4 + w5 + w6 + w7;

  always @* begin
    if (n == 4'd0) begin
      score = 32'd0;
    end else if (n == 4'd1) begin
      score = {16'd0, v0};
    end else begin
      score = sum_base;
    end
  end

endmodule