module cone_lsa (
  input clk,
  input rst_n,
  input start,
  input [31:0] r_q16,
  input [31:0] h_q16,
  output reg [31:0] lsa_q16,
  output reg done
);
  reg [31:0] r_reg, h_reg;
  reg [63:0] r_sq [1:0], h_sq [1:0];
  reg [63:0] sum_sq;
  reg [63:0] sqrt_in [0:4];
  reg [31:0] sqrt_res;
  reg [63:0] mult1 [1:0];
  reg [63:0] mult2 [1:0];
  reg [3:0] counter;
  reg busy;
  
  localparam [31:0] PI_Q16 = 32'h3243F;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_reg <= 0;
      h_reg <= 0;
      r_sq[0] <= 0;
      r_sq[1] <= 0;
      h_sq[0] <= 0;
      h_sq[1] <= 0;
      sum_sq <= 0;
      sqrt_in <= '{default:0};
      sqrt_res <= 0;
      mult1[0] <= 0;
      mult1[1] <= 0;
      mult2[0] <= 0;
      mult2[1] <= 0;
      lsa_q16 <= 0;
      done <= 0;
      counter <= 0;
      busy <= 0;
    end else begin
      done <= 0;
      if (busy) begin
        counter <= counter + 1;
        if (counter == 4'd11) begin
          lsa_q16 <= mult2[1][63:32];
          done <= 1;
          busy <= 0;
        end
      end else if (start) begin
        busy <= 1;
        counter <= 0;
        r_reg <= r_q16;
        h_reg <= h_q16;
      end
      
      r_sq[0] <= r_reg * r_reg;
      r_sq[1] <= r_sq[0];
      
      h_sq[0] <= h_reg * h_reg;
      h_sq[1] <= h_sq[0];
      
      if (counter == 2) sum_sq <= r_sq[1] + h_sq[1];
      
      sqrt_in[0] <= (counter >= 2 && counter < 7) ? sum_sq : 0;
      for (int i=1; i<5; i++) sqrt_in[i] <= sqrt_in[i-1];
      
      if (counter == 7) begin
        sqrt_res <= non_restoring_sqrt(sqrt_in[4]);
      end
      
      if (counter == 7) mult1[0] <= r_reg * sqrt_res;
      mult1[1] <= mult1[0];
      
      if (counter == 9) mult2[0] <= mult1[1] * PI_Q16;
      mult2[1] <= mult2[0];
      
    end
  end
  
  function [31:0] non_restoring_sqrt(input [63:0] x);
    reg [63:0] x_reg;
    reg [31:0] q;
    reg [33:0] acc;
    integer i;
    begin
      x_reg = x;
      q = 0;
      acc = 0;
      for (i=0; i<32; i=i+1) begin
        if (acc[33]) begin
          acc = {acc[31:0], x_reg[63:62]};
          x_reg = {x_reg[61:0], 2'b00};
          if (acc[33]) begin
            q = {q[30:0], 1'b1};
            acc = {acc[31:0] + {2'b11, q[30:0], 1'b1}, 2'b00};
          end else begin
            q = {q[30:0], 1'b0};
            acc = {acc[31:0] + {2'b00, q[30:0], 1'b1}, 2'b00};
          end
        end else begin
          acc = {acc[31:0], x_reg[63:62]};
          x_reg = {x_reg[61:0], 2'b00};
          if (acc[33]) begin
            q = {q[30:0], 1'b1};
            acc = {acc[31:0] + {2'b11, q[30:0], 1'b1}, 2'b00};
          end else begin
            q = {q[30:0], 1'b0};
            acc = {acc[31:0] + {2'b00, q[30:0], 1'b1}, 2'b00};
          end
        end
      end
      non_restoring_sqrt = q;
    end
  endfunction
endmodule