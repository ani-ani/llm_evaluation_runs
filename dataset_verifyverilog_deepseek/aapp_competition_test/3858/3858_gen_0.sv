module convex_score_sum (
  input clk,
  input rst_n,
  input start,
  input [3:0] x [0:7],
  input [3:0] y [0:7],
  output reg [29:0] sum,
  output reg done
);
  localparam integer MOD = 998244353;
  localparam integer BASE = 219;
  
  reg [4:0] cycle_count;
  reg [29:0] accumulator;
  reg [3:0] x_reg [0:7];
  reg [3:0] y_reg [0:7];
  reg [29:0] sum_reg;
  
  function [2:0] get_i(input [4:0] idx);
    if (idx < 7) get_i = 0;
    else if (idx < 13) get_i = 1;
    else if (idx < 18) get_i = 2;
    else if (idx < 22) get_i = 3;
    else if (idx < 25) get_i = 4;
    else if (idx < 27) get_i = 5;
    else get_i = 6;
  endfunction
  
  function [2:0] get_j(input [4:0] idx);
    if (idx < 7) get_j = idx[2:0] + 1;
    else if (idx < 13) get_j = (idx - 7) + 2;
    else if (idx < 18) get_j = (idx - 13) + 3;
    else if (idx < 22) get_j = (idx - 18) + 4;
    else if (idx < 25) get_j = (idx - 22) + 5;
    else if (idx < 27) get_j = (idx - 25) + 6;
    else get_j = 7;
  endfunction
  
  function [29:0] get_term(input [2:0] c);
    case(c)
      0: get_term = 0;
      1: get_term = 0;
      2: get_term = 1;
      3: get_term = 4;
      4: get_term = 11;
      5: get_term = 26;
      6: get_term = 57;
      default: get_term = 0;
    endcase
  endfunction
  
  function [2:0] calc_c(input [2:0] i, input [2:0] j);
    reg signed [4:0] dx_ij, dy_ij, dx_ik, dy_ik;
    reg signed [9:0] prod1, prod2;
    integer kk;
    begin
      calc_c = 0;
      dx_ij = x_reg[j] - x_reg[i];
      dy_ij = y_reg[j] - y_reg[i];
      for (kk=0; kk<8; kk=kk+1) begin
        if (kk != i && kk != j) begin
          dx_ik = x_reg[kk] - x_reg[i];
          dy_ik = y_reg[kk] - y_reg[i];
          prod1 = dx_ij * dy_ik;
          prod2 = dx_ik * dy_ij;
          if (prod1 == prod2) calc_c = calc_c + 1;
        end
      end
    end
  endfunction
  
  wire [4:0] pidx1 = (cycle_count > 0) ? 5'd2 * (cycle_count - 1) : 0;
  wire [4:0] pidx2 = pidx1 + 1;
  wire [2:0] i1 = get_i(pidx1);
  wire [2:0] j1 = get_j(pidx1);
  wire [2:0] i2 = get_i(pidx2);
  wire [2:0] j2 = get_j(pidx2);
  wire [2:0] c1 = calc_c(i1, j1);
  wire [2:0] c2 = calc_c(i2, j2);
  wire [29:0] term1 = get_term(c1);
  wire [29:0] term2 = get_term(c2);
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count <= 0;
      sum_reg <= 0;
      accumulator <= 0;
      done <= 0;
      sum <= 0;
      for (int i=0; i<8; i=i+1) begin
        x_reg[i] <= 0;
        y_reg[i] <= 0;
      end
    end else begin
      if (cycle_count == 0) begin
        if (start) begin
          x_reg <= x;
          y_reg <= y;
          accumulator <= 0;
          sum_reg <= 0;
          cycle_count <= 1;
          done <= 0;
        end
      end else if (cycle_count <= 20) begin
        if (cycle_count >= 1 && cycle_count <= 14) begin
          accumulator <= (accumulator + term1 + term2) % MOD;
        end else if (cycle_count == 15) begin
          sum_reg <= (BASE + MOD - accumulator % MOD) % MOD;
        end
        
        if (cycle_count == 20) begin
          sum <= sum_reg % MOD;
          done <= 1;
          cycle_count <= 0;
        end else cycle_count <= cycle_count + 1;
      end
    end
  end
endmodule