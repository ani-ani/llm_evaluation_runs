module max_bitwise_or(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [2:0] k, // max operations (0-7)
  input [2:0] x, // multiplier (2-4)
  input [7:0][15:0] arr, // fixed 8-element array (padded with 0s if n<8)
  output reg [31:0] result, // maximum OR value
  output reg done // high when computation completes
);

  // Internal signals
  reg [15:0] pow_x_k;
  reg [15:0] base;
  integer i;

  // Compute x^k combinationally
  always @* begin
    // map x (2-4) into 16-bit base
    case (x)
      3'd2: base = 16'd2;
      3'd3: base = 16'd3;
      3'd4: base = 16'd4;
      default: base = 16'd1; // for safety, though x is specified 2-4
    endcase

    pow_x_k = 16'd1;
    for (i = 0; i < 8; i = i + 1) begin
      if (i < k)
        pow_x_k = pow_x_k * base;
    end
  end

  // Prefix ORs (pref[i] = OR of arr[0..i-1])
  wire [15:0] pref [0:7];
  assign pref[0] = 16'd0;
  generate
    genvar pi;
    for (pi = 1; pi < 8; pi = pi + 1) begin : GEN_PREF
      assign pref[pi] = pref[pi-1] | arr[pi-1];
    end
  endgenerate

  // Suffix ORs (suff[i] = OR of arr[i+1..7])
  wire [15:0] suff [0:7];
  assign suff[7] = 16'd0;
  generate
    genvar si;
    for (si = 6; si >= 0; si = si - 1) begin : GEN_SUFF
      if (si == 6) begin
        assign suff[si] = arr[7];
      end else begin
        assign suff[si] = suff[si+1] | arr[si+1];
      end
    end
  endgenerate

  // Candidates and maximum
  wire [31:0] candidate [0:7];
  generate
    genvar ci;
    for (ci = 0; ci < 8; ci = ci + 1) begin : GEN_CAND
      wire [31:0] scaled;
      wire [31:0] or_others;
      assign scaled   = (arr[ci] * pow_x_k);
      assign or_others = {16'd0, (pref[ci] | suff[ci])};
      assign candidate[ci] = scaled | or_others;
    end
  endgenerate

  wire [31:0] max0_0 = (candidate[0] >= candidate[1]) ? candidate[0] : candidate[1];
  wire [31:0] max0_1 = (candidate[2] >= candidate[3]) ? candidate[2] : candidate[3];
  wire [31:0] max0_2 = (candidate[4] >= candidate[5]) ? candidate[4] : candidate[5];
  wire [31:0] max0_3 = (candidate[6] >= candidate[7]) ? candidate[6] : candidate[7];

  wire [31:0] max1_0 = (max0_0 >= max0_1) ? max0_0 : max0_1;
  wire [31:0] max1_1 = (max0_2 >= max0_3) ? max0_2 : max0_3;

  wire [31:0] max_final = (max1_0 >= max1_1) ? max1_0 : max1_1;

  // Sequential control: register result and done one cycle after start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 32'd0;
      done   <= 1'b0;
    end else begin
      if (start) begin
        result <= max_final;
        done   <= 1'b1;
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule