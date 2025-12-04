module max_bitwise_or(
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [2:0] x,
  input [7:0][15:0] arr,
  output reg [31:0] result,
  output reg done
);
  // Internal signals
  logic [2:0] k_reg, x_reg;
  logic [15:0] arr_reg[8];
  logic [15:0] pref[8];
  logic [15:0] suff[9];
  logic [15:0] xk_power;
  logic [31:0] max_candidate;
  logic [31:0] cand;
  // State machine encoding
  logic [1:0] state;
  parameter IDLE = 2'b00;
  parameter CALC = 2'b01;
  // Combinational computation: x^k, prefix, suffix, max
  always_comb begin
    // Compute x^k (max 4^7 = 16384, fits in 16 bits)
    xk_power = 16'd1;
    case (k_reg)
      3'd0: xk_power = 16'd1;
      3'd1: xk_power = {13'd0, x_reg};
      3'd2: xk_power = {13'd0, x_reg} * {13'd0, x_reg};
      3'd3: xk_power = {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg};
      3'd4: xk_power = {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg};
      3'd5: xk_power = {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg};
      3'd6: xk_power = {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg};
      3'd7: xk_power = {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg} * {13'd0, x_reg};
      default: xk_power = 16'd1;
    endcase
    // Prefix ORs: pref[i] = arr[0] | ... | arr[i-1]
    pref[0] = 16'd0;
    for (int i=0; i<7; i++) begin
      pref[i+1] = pref[i] | arr_reg[i];
    end
    // Suffix ORs: suff[i] = arr[i] | ... | arr[7]
    suff[8] = 16'd0;
    suff[7] = arr_reg[7];
    for (int i=6; i>=0; i--) begin
      suff[i] = arr_reg[i] | suff[i+1];
    end
    // Find maximum candidate across all 8 elements
    max_candidate = 32'd0;
    for (int i=0; i<8; i++) begin
      cand = (arr_reg[i] * xk_power) | pref[i] | ((i < 7) ? suff[i+1] : 16'd0);
      if (cand > max_candidate) max_candidate = cand;
    end
  end
  // Sequential state machine: capture inputs, compute, output result after 1 cycle
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 32'd0;
      done <= 1'b0;
      k_reg <= 3'd0;
      x_reg <= 3'd0;
      for (int i=0; i<8; i++) arr_reg[i] <= 16'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          result <= result; // keep old value
          if (start) begin
            k_reg <= k;
            x_reg <= x;
            for (int i=0; i<8; i++) arr_reg[i] <= arr[i];
            state <= CALC;
          end
        end
        CALC: begin
          result <= max_candidate;
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule
