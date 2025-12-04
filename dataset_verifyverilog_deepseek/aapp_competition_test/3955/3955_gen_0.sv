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
  
  // Registered inputs when start is high
  reg [7:0][15:0] arr_reg;
  reg [2:0] k_reg, x_reg;
  reg busy;
  
  // Combinatorial signals
  logic [15:0] x_power;
  logic [7:0][15:0] pref, suff;
  logic [7:0][31:0] candidate;
  logic [31:0] max_candidate;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      arr_reg <= '0;
      k_reg <= '0;
      x_reg <= '0;
      busy <= 0;
      result <= 0;
      done <= 0;
    end else begin
      done <= 0; // done is default low
      if (start) begin
        // Capture inputs when start is high
        arr_reg <= arr;
        k_reg <= k;
        x_reg <= x;
        busy <= 1;
      end else if (busy) begin
        // One cycle after capture, output result
        result <= max_candidate;
        done <= 1;
        busy <= 0;
      end
    end
  end
  
  always_comb begin
    // Compute x_power = x_reg^k_reg
    case ({x_reg, k_reg})
      {3'd2, 3'd0}: x_power = 16'd1;
      {3'd2, 3'd1}: x_power = 16'd2;
      {3'd2, 3'd2}: x_power = 16'd4;
      {3'd2, 3'd3}: x_power = 16'd8;
      {3'd2, 3'd4}: x_power = 16'd16;
      {3'd2, 3'd5}: x_power = 16'd32;
      {3'd2, 3'd6}: x_power = 16'd64;
      {3'd2, 3'd7}: x_power = 16'd128;
      {3'd3, 3'd0}: x_power = 16'd1;
      {3'd3, 3'd1}: x_power = 16'd3;
      {3'd3, 3'd2}: x_power = 16'd9;
      {3'd3, 3'd3}: x_power = 16'd27;
      {3'd3, 3'd4}: x_power = 16'd81;
      {3'd3, 3'd5}: x_power = 16'd243;
      {3'd3, 3'd6}: x_power = 16'd729;
      {3'd3, 3'd7}: x_power = 16'd2187;
      {3'd4, 3'd0}: x_power = 16'd1;
      {3'd4, 3'd1}: x_power = 16'd4;
      {3'd4, 3'd2}: x_power = 16'd16;
      {3'd4, 3'd3}: x_power = 16'd64;
      {3'd4, 3'd4}: x_power = 16'd256;
      {3'd4, 3'd5}: x_power = 16'd1024;
      {3'd4, 3'd6}: x_power = 16'd4096;
      {3'd4, 3'd7}: x_power = 16'd16384;
      default: x_power = 16'd1;
    endcase
    
    // Prefix OR array
    pref[0] = 16'b0;
    for (int i = 1; i < 8; i++) pref[i] = pref[i-1] | arr_reg[i-1];
    
    // Suffix OR array
    suff[7] = 16'b0;
    for (int i = 6; i >= 0; i--) suff[i] = suff[i+1] | arr_reg[i+1];
    
    // Compute each candidate
    for (int i = 0; i < 8; i++) begin
      logic [31:0] product;
      product = arr_reg[i] * x_power;
      candidate[i] = product | {16'b0, pref[i]} | {16'b0, suff[i]};
    end
    
    // Find maximum candidate
    max_candidate = candidate[0];
    for (int i = 1; i < 8; i++) begin
      if (candidate[i] > max_candidate) max_candidate = candidate[i];
    end
  end
endmodule