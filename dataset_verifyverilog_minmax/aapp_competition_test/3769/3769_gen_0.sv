module function_counter(
  input clk,
  input rst_n,
  input start,
  input [4:0] p,
  input [4:0] k,
  output reg [29:0] result,
  output reg done
);

  localparam MOD = 30'd1000000007;

  // State encoding
  localparam IDLE = 4'd0;
  localparam ORDER_INIT = 4'd1;
  localparam ORDER_CHECK = 4'd2;
  localparam ORDER_NEXT = 4'd3;
  localparam ORDER_DONE = 4'd4;
  localparam EXP0_INIT = 4'd5;
  localparam EXP0_LOOP = 4'd6;
  localparam EXP0_DONE = 4'd7;
  localparam EXP1_INIT = 4'd8;
  localparam EXP1_LOOP = 4'd9;
  localparam EXP1_DONE = 4'd10;
  localparam EXP2_INIT = 4'd11;
  localparam EXP2_LOOP = 4'd12;
  localparam EXP2_DONE = 4'd13;
  localparam DONE = 4'd14;

  reg [3:0] state;

  // Order-finding signals
  reg [4:0] t;
  reg [4:0] cur_pow;
  reg [4:0] order_t;

  // Exponentiation signals
  reg [29:0] exp_base;
  reg [4:0] exp_exp;
  reg [29:0] exp_result;

  // Temporary variables for modular multiplication
  reg [9:0] temp_small;  // for mod p multiplication
  reg [59:0] temp_large;  // for mod MOD multiplication

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      result <= 30'd0;
      t <= 5'd0;
      cur_pow <= 5'd0;
      order_t <= 5'd0;
      exp_base <= 30'd0;
      exp_exp <= 5'd0;
      exp_result <= 30'd0;
      temp_small <= 10'd0;
      temp_large <= 60'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            if (k == 5'd0) begin
              state <= EXP0_INIT;
            end else if (k == 5'd1) begin
              state <= EXP1_INIT;
            end else begin
              state <= ORDER_INIT;
            end
            done <= 1'b0;
          end
        end

        ORDER_INIT: begin
          t <= 5'd1;
          cur_pow <= k % p;
          state <= ORDER_CHECK;
        end

        ORDER_CHECK: begin
          if (cur_pow == 5'd1) begin
            order_t <= t;
            state <= ORDER_DONE;
          end else begin
            state <= ORDER_NEXT;
          end
        end

        ORDER_NEXT: begin
          t <= t + 1;
          temp_small <= cur_pow * k;
          cur_pow <= temp_small % p;
          if (t < p - 1) begin
            state <= ORDER_CHECK;
          end else begin
            state <= ORDER_DONE;
          end
        end

        ORDER_DONE: begin
          // Compute c = (p-1) / order_t
          exp_base <= p;
          exp_exp <= (p - 1) / order_t;
          exp_result <= 30'd1;
          state <= EXP2_INIT;
        end

        EXP0_INIT: begin
          exp_base <= p;
          exp_exp <= p - 1;
          exp_result <= 30'd1;
          state <= EXP0_LOOP;
        end

        EXP0_LOOP: begin
          if (exp_exp[0]) begin
            temp_large <= exp_result * exp_base;
            exp_result <= temp_large % MOD;
          end
          temp_large <= exp_base * exp_base;
          exp_base <= temp_large % MOD;
          exp_exp <= exp_exp >> 1;
          if (exp_exp == 5'd0) begin
            state <= EXP0_DONE;
          end else begin
            state <= EXP0_LOOP;
          end
        end

        EXP0_DONE: begin
          result <= exp_result;
          state <= DONE;
        end

        EXP1_INIT: begin
          exp_base <= p;
          exp_exp <= p;
          exp_result <= 30'd1;
          state <= EXP1_LOOP;
        end

        EXP1_LOOP: begin
          if (exp_exp[0]) begin
            temp_large <= exp_result * exp_base;
            exp_result <= temp_large % MOD;
          end
          temp_large <= exp_base * exp_base;
          exp_base <= temp_large % MOD;
          exp_exp <= exp_exp >> 1;
          if (exp_exp == 5'd0) begin
            state <= EXP1_DONE;
          end else begin
            state <= EXP1_LOOP;
          end
        end

        EXP1_DONE: begin
          result <= exp_result;
          state <= DONE;
        end

        EXP2_INIT: begin
          state <= EXP2_LOOP;
        end

        EXP2_LOOP: begin
          if (exp_exp[0]) begin
            temp_large <= exp_result * exp_base;
            exp_result <= temp_large % MOD;
          end
          temp_large <= exp_base * exp_base;
          exp_base <= temp_large % MOD;
          exp_exp <= exp_exp >> 1;
          if (exp_exp == 5'd0) begin
            state <= EXP2_DONE;
          end else begin
            state <= EXP2_LOOP;
          end
        end

        EXP2_DONE: begin
          result <= exp_result;
          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule