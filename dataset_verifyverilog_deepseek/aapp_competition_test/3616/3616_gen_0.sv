module allergen_test_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [2:0] D1,
  input [2:0] D2,
  input [2:0] D3,
  input [2:0] D4,
  output reg done,
  output reg [4:0] T
);

  reg [2:0] k_reg;
  reg [4:0] D1_reg, D2_reg, D3_reg, D4_reg;
  reg [4:0] sum_D;
  reg [4:0] max_D;
  reg [1:0] state;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      T <= 0;
      k_reg <= 0;
      D1_reg <= 0;
      D2_reg <= 0;
      D3_reg <= 0;
      D4_reg <= 0;
      sum_D <= 0;
      max_D <= 0;
      state <= 0;
    end else begin
      case (state)
        0: begin
          done <= 0;
          if (start) begin
            D1_reg <= D1;
            D2_reg <= D2;
            D3_reg <= D3;
            D4_reg <= D4;
            k_reg <= k;
            state <= 1;
          end
        end
        1: begin
          // Cycle 1: Compute sum & max
          sum_D <= 5'b0;
          max_D <= 5'b0;
          if (k_reg >= 1) begin
            sum_D <= sum_D + D1_reg;
            max_D <= max_D > D1_reg ? max_D : D1_reg;
          end
          if (k_reg >= 2) begin
            sum_D <= sum_D + D2_reg;
            max_D <= max_D > D2_reg ? max_D : D2_reg;
          end
          if (k_reg >= 3) begin
            sum_D <= sum_D + D3_reg;
            max_D <= max_D > D3_reg ? max_D : D3_reg;
          end
          if (k_reg >= 4) begin
            sum_D <= sum_D + D4_reg;
            max_D <= max_D > D4_reg ? max_D : D4_reg;
          end
          state <= 2;
        end
        2: begin
          // Cycle 2: Compute T
          T <= (sum_D - ((k_reg > 1) ? (k_reg - 1) : 0)) > max_D ? 
                (sum_D - ((k_reg > 1) ? (k_reg - 1) : 0)) : max_D;
          state <= 3;
        end
        3: begin
          // Cycle 3: Output
          done <= 1;
          state <= 0;
        end
      endcase
    end
  end
endmodule
