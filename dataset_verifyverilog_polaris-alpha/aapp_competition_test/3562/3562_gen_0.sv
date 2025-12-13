module grade_optimizer(
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [7:0] T,
  input [31:0] a0,
  input [31:0] b0,
  input [31:32] c0,
  input [31:0] a1,
  input [31:0] b1,
  input [31:0] c1,
  input [31:0] a2,
  input [31:0] b2,
  input [31:0] c2,
  input [31:0] a3,
  input [31:0] b3,
  input [31:0] c3,
  input [31:0] a4,
  input [31:0] b4,
  input [31:0] c4,
  input [31:0] a5,
  input [31:0] b5,
  input [31:0] c5,
  input [31:0] a6,
  input [31:0] b6,
  input [31:0] c6,
  input [31:0] a7,
  input [31:0] b7,
  input [31:0] c7,
  output reg [31:0] avg_grade,
  output reg done
);

  // Signed parameters in Q16.16
  wire signed [31:0] a [0:7];
  wire signed [31:0] b [0:7];
  wire signed [31:0] c [0:7];

  assign a[0]=a0; assign b[0]=b0; assign c[0]=c0;
  assign a[1]=a1; assign b[1]=b1; assign c[1]=c1;
  assign a[2]=a2; assign b[2]=b2; assign c[2]=c2;
  assign a[3]=a3; assign b[3]=b3; assign c[3]=c3;
  assign a[4]=a4; assign b[4]=b4; assign c[4]=c4;
  assign a[5]=a5; assign b[5]=b5; assign c[5]=c5;
  assign a[6]=a6; assign b[6]=b6; assign c[6]=c6;
  assign a[7]=a7; assign b[7]=b7; assign c[7]=c7;

  // Internal time allocations t[i] in Q16.16 (0..T)
  reg signed [31:0] t [0:7];
  reg [6:0] cycle_cnt;
  reg busy;

  // Derivatives
  reg signed [31:0] deriv [0:7];

  integer i;

  // Compute integer division T/N and rounding
  function [15:0] div_round_uint8_by_uint3;
    input [7:0] num;
    input [2:0] den;
    reg [15:0] q;
    begin
      if (den == 0) begin
        q = 16'd0;
      end else begin
        q = (num + (den>>1)) / den;
      end
      div_round_uint8_by_uint3 = q;
    end
  endfunction

  // Two's power for Q16.16 1.0
  localparam signed [31:0] ONE_Q16_16 = 32'sd65536;

  // Derivative step (discrete time unit in Q16.16)
  // Chosen small step for stable behavior
  localparam signed [31:0] STEP_Q16_16 = 32'sd1024; // = 1024/65536 = 1/64 hour per cycle transfer

  // State machine and computations
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      busy <= 1'b0;
      cycle_cnt <= 7'd0;
      avg_grade <= 32'sd0;
      done <= 1'b0;
      for (i=0; i<8; i=i+1) begin
        t[i] <= 32'sd0;
        deriv[i] <= 32'sd0;
      end
    end else begin
      done <= 1'b0;

      if (start && !busy) begin
        // Initialize
        busy <= 1'b1;
        cycle_cnt <= 7'd0;

        // Compute base hours per subject (integer hours with rounding)
        // t_i = (T/N rounded) in Q16.16
        // Sum might differ slightly; we keep simple equal allocation, ignoring remainder distribution.
        // If N==0, treat as N=1 to avoid div-by-zero (though spec says 1-8).
        reg [2:0] N_eff;
        reg [15:0] base_h;
        N_eff = (N == 3'd0) ? 3'd1 : N;
        base_h = div_round_uint8_by_uint3(T, N_eff);

        for (i=0; i<8; i=i+1) begin
          if (i < N_eff)
            t[i] <= $signed({base_h,16'd0});
          else
            t[i] <= 32'sd0;
        end
      end else if (busy) begin
        if (cycle_cnt < 7'd100) begin
          // 1) Compute derivatives for active subjects
          integer j;
          reg signed [63:0] mult;
          for (j=0; j<8; j=j+1) begin
            if (j < N) begin
              // deriv = 2*a*t + b, all in Q16.16
              // 2*a*t: a(32)*t(32) -> 64, shift>>16 with rounding
              mult = $signed(a[j]) * $signed(t[j]);
              mult = (mult + 64'sd32768) >>> 16; // rounding
              mult = mult <<< 1; // *2
              deriv[j] <= $signed(mult[31:0]) + b[j];
            end else begin
              deriv[j] <= 32'sd0;
            end
          end

          // 2) Find max and min derivative indices among active subjects
          reg signed [31:0] max_d, min_d;
          reg [2:0] max_i, min_i;
          max_d = -32'sd2147483648;
          min_d =  32'sd2147483647;
          max_i = 3'd0;
          min_i = 3'd0;

          for (j=0; j<8; j=j+1) begin
            if (j < N) begin
              if (deriv[j] > max_d) begin
                max_d = deriv[j];
                max_i = j[2:0];
              end
              if (deriv[j] < min_d) begin
                min_d = deriv[j];
                min_i = j[2:0];
              end
            end
          end

          // 3) Adjust times between max_i and min_i while preserving total T
          // Move STEP_Q16_16 from max_i to min_i if possible
          if (max_i != min_i && N != 3'd0) begin
            // Ensure non-negative times; clamp if needed
            if (t[max_i] > STEP_Q16_16) begin
              t[max_i] <= t[max_i] - STEP_Q16_16;
              t[min_i] <= t[min_i] + STEP_Q16_16;
            end
          end

          cycle_cnt <= cycle_cnt + 7'd1;
        end else begin
          // After 100 cycles: compute avg_grade = sum(f_i(t_i))/N
          // f_i(t) = a*t^2 + b*t + c; all Q16.16
          reg [2:0] N_eff2;
          reg signed [63:0] sum_f;
          reg signed [63:0] tmp64;
          reg signed [63:0] t_sq;
          N_eff2 = (N == 3'd0) ? 3'd1 : N;
          sum_f = 64'sd0;

          for (i=0; i<8; i=i+1) begin
            if (i < N) begin
              // t_sq = (t*t)>>16 with rounding
              t_sq = $signed(t[i]) * $signed(t[i]);
              t_sq = (t_sq + 64'sd32768) >>> 16;

              // a*t^2
              tmp64 = $signed(a[i]) * $signed(t_sq[31:0]);
              tmp64 = (tmp64 + 64'sd32768) >>> 16;

              // b*t
              reg signed [63:0] bt;
              bt = $signed(b[i]) * $signed(t[i]);
              bt = (bt + 64'sd32768) >>> 16;

              // f = a*t^2 + b*t + c
              tmp64 = tmp64 + bt + $signed({{32{c[i][31]}},c[i]});

              sum_f = sum_f + tmp64;
            end
          end

          // avg = sum_f / N_eff2
          // sum_f is Q16.16; divide as signed with rounding
          reg signed [63:0] num;
          reg signed [31:0] div_res;
          num = sum_f;
          if (N_eff2 != 0) begin
            if (num >= 0)
              num = num + (N_eff2>>>1);
            else
              num = num - (N_eff2>>>1);
            div_res = num / N_eff2;
          end else begin
            div_res = 32'sd0;
          end

          avg_grade <= div_res;
          done <= 1'b1;
          busy <= 1'b0;
        end
      end
    end
  end

endmodule