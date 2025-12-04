module grade_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [7:0] T,
  input [31:0] a0, b0, c0,
  input [31:0] a1, b1, c1,
  input [31:0] a2, b2, c2,
  input [31:0] a3, b3, c3,
  input [31:0] a4, b4, c4,
  input [31:0] a5, b5, c5,
  input [31:0] a6, b6, c6,
  input [31:0] a7, b7, c7,
  output reg [31:0] avg_grade,
  output reg done
);

  localparam FP_SHIFT = 16;
  localparam ITERATIONS = 100;
  
  reg [7:0] cycle;
  reg [31:0] t[0:7];
  reg [31:0] deriv[0:7];
  
  wire [2:0] max_id, min_id;
  
  // Internal a,b,c array
  wire [31:0] a[0:7], b[0:7];
  assign a[0] = a0; b[0] = b0;
  assign a[1] = a1; b[1] = b1;
  assign a[2] = a2; b[2] = b2;
  assign a[3] = a3; b[3] = b3;
  assign a[4] = a4; b[4] = b4;
  assign a[5] = a5; b[5] = b5;
  assign a[6] = a6; b[6] = b6;
  assign a[7] = a7; b[7] = b7;
  
  // Calculate derivatives for all subjects
  function [31:0] calculate_deriv(input [31:0] a, t, b);
    reg signed [63:0] mult, doubled, b_scaled;
    reg signed [63:0] sum_pre;
    begin
      mult = $signed(a) * $signed(t);
      doubled = mult << 1;
      b_scaled = $signed(b) << FP_SHIFT;
      sum_pre = doubled + b_scaled;
      calculate_deriv = sum_pre[47:16] + (sum_pre[15] ? 1 : 0); // Round-to-nearest
    end
  endfunction
  
  // Combinatorial max/min finder
  integer i;
  reg [31:0] max_val;
  reg [31:0] min_val;
  always @(*) begin
    max_val = deriv[0];
    max_id = 0;
    min_val = deriv[0];
    min_id = 0;
    for (i = 0; i < 8; i = i+1) begin
      if (i < N) begin
        if ($signed(deriv[i]) > $signed(max_val)) begin
          max_val = deriv[i];
          max_id = i;
        end
        if ($signed(deriv[i]) < $signed(min_val)) begin
          min_val = deriv[i];
          min_id = i;
        end
      end
    end
  end
  
  // Calculate final grade for a subject
  function [31:0] calculate_grade(input [31:0] a, t, b, c);
    reg signed [63:0] t_sq, a_t_sq;
    reg signed [63:0] b_t;
    reg signed [95:0] sum_pre, c_scaled;
    reg [31:0] res;
    begin
      t_sq = $signed(t) * $signed(t);
      a_t_sq = $signed(a) * t_sq;
      b_t = $signed(b) * $signed(t);
      c_scaled = $signed(c) << (FP_SHIFT * 2);
      sum_pre = a_t_sq + (b_t << FP_SHIFT) + c_scaled;
      res = sum_pre[63:32] + (sum_pre[31] ? 1 : 0); // Round-to-nearest
      calculate_grade = res;
    end
  endfunction
  
  // Calculate initial time allocation with rounding
  function [31:0] calc_init_t(input [7:0] T, input [2:0] N);
    reg [23:0] T_fixed;
    reg [31:0] inv_N;
    reg [47:0] T_ext;
    reg [63:0] product;
    reg [15:0] rounding;
    begin
      case(N)
        3'd1: inv_N = 32'h00010000;
        3'd2: inv_N = 32'h00008000;
        3'd3: inv_N = 32'h00005555;
        3'd4: inv_N = 32'h00004000;
        3'd5: inv_N = 32'h00003333;
        3'd6: inv_N = 32'h00002AAA;
        3'd7: inv_N = 32'h00002492;
        3'd8: inv_N = 32'h00002000;
        default: inv_N = 32'h00010000;
      endcase
      T_ext = {16'h0, T, 16'h0};
      product = T_ext * inv_N;
      rounding = (product[31:16] >= 16'h8000) ? 1 : 0;
      calc_init_t = product[47:16] + rounding;
    end
  endfunction
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      cycle <= 0;
      avg_grade <= 0;
      for (i=0; i<8; i=i+1) begin
        t[i] <= 0;
        deriv[i] <= 0;
      end
    end else begin
      done <= 1'b0;
      if (start) begin
        cycle <= 0;
        for (i=0; i<8; i=i+1) begin
          t[i] <= (i < N) ? calc_init_t(T, N) : 0;
        end
      end else if (cycle < ITERATIONS) begin
        if (cycle == 0) begin // Initial derivative computation
          for (i=0; i<8; i=i+1) deriv[i] <= (i < N) ? calculate_deriv(a[i], t[i], b[i]) : 0;
        end else begin // Adjust times
          t[max_id] <= t[max_id] + 1;
          t[min_id] <= t[min_id] - 1;
          deriv[max_id] <= calculate_deriv(a[max_id], t[max_id] + 1, b[max_id]);
          deriv[min_id] <= calculate_deriv(a[min_id], t[min_id] - 1, b[min_id]);
        end
        cycle <= cycle + 1;
      end else if (cycle == ITERATIONS) begin
        begin
          reg [31:0] sum;
          reg [31:0] f;
          sum = 0;
          for (i=0; i<8; i=i+1) begin
            if (i < N) begin
              f = calculate_grade(a[i], t[i], b[i], (i==0)?c0:(i==1)?c1:(i==2)?c2:(i==3)?c3:(i==4)?c4:(i==5)?c5:(i==6)?c6:c7);
              sum = sum + f;
            end
          end
          avg_grade <= calc_init_t(sum[23:16], N) >> (FP_SHIFT - 8);
          done <= 1'b1;
        end
      end
    end
  end

endmodule