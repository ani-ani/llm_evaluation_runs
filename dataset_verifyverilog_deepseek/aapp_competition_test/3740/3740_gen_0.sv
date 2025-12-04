module digit_sum_pair_counter(
  input clk,
  input rst_n,
  input start,
  input [15:0] S_in,
  output reg [31:0] count,
  output reg done
);

  localparam MOD = 32'd1000000007;
  localparam [2:0]
    IDLE       = 3'd0,
    INIT_L     = 3'd1,
    SUM_DIGITS = 3'd2,
    CHECK_SUM  = 3'd3,
    NEXT_L     = 3'd4,
    FINISH     = 3'd5;

  reg [2:0] state;
  reg [16:0] l;
  reg [16:0] r;
  reg [15:0] current_sum;

  wire [16:0] max_l = {S_in, 1'b0}; // 2*S_in

  function [3:0] digit_count;
    input [16:0] num;
    begin
      if      (num < 17'd10)    digit_count = 4'd1;
      else if (num < 17'd100)   digit_count = 4'd2;
      else if (num < 17'd1000)  digit_count = 4'd3;
      else if (num < 17'd10000) digit_count = 4'd4;
      else if (num < 17'd100000)digit_count = 4'd5;
      else                      digit_count = 4'd6;
    end
  endfunction

  wire [3:0] current_digit_count = digit_count(r);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 0;
      done <= 0;
      l <= 0;
      r <= 0;
      current_sum <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            l <= 17'd1;
            count <= 0;
            state <= INIT_L;
          end
        end

        INIT_L: begin
          current_sum <= 0;
          r <= l;
          state <= SUM_DIGITS;
        end

        SUM_DIGITS: begin
          current_sum <= current_sum + current_digit_count;
          state <= CHECK_SUM;
        end

        CHECK_SUM: begin
          if (current_sum == S_in) count <= (count + 1) % MOD;
          if (current_sum >= S_in) state <= NEXT_L;
          else begin
            r <= r + 1;
            state <= SUM_DIGITS;
          end
        end

        NEXT_L: begin
          l <= l + 1;
          if ((l + 1) > max_l) state <= FINISH;
          else state <= INIT_L;
        end

        FINISH: begin
          done <= 1;
          state <= FINISH;
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule