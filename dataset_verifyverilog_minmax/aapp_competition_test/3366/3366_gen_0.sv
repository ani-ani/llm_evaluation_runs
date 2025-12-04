module collatz_sum(
  input clk,               // clock
  input rst_n,             // active-low reset
  input start,             // start computation (pulse high)
  input [15:0] L,          // interval start (1-65535)
  input [15:0] R,          // interval end (L <= R)
  output reg [20:0] S,     // accumulated sum (max 21 bits)
  output reg done          // high when computation complete
);

  localparam IDLE = 2'b00;
  localparam COMPUTE_FX = 2'b01;
  localparam SUM_LOOP = 2'b10;

  localparam MAX_ITER = 32; // Cap iterations per X

  reg [1:0] state, state_next;
  reg [15:0] cur_x, cur_x_next;
  reg [5:0] iter_cnt, iter_cnt_next;
  reg [20:0] S_next;
  reg [15:0] L_reg, R_reg;

  always @(*) begin
    state_next = state;
    cur_x_next = cur_x;
    iter_cnt_next = iter_cnt;
    S_next = S;
    done = 1'b0;

    case (state)
      IDLE: begin
        done = 1'b1; // Idle and no active work
        if (start) begin
          S_next = 21'd0;
          cur_x_next = L;
          iter_cnt_next = 6'd0;
          state_next = COMPUTE_FX;
        end
      end

      COMPUTE_FX: begin
        if (cur_x == 16'd1 || iter_cnt == MAX_ITER) begin
          S_next = S + {15'd0, iter_cnt};
          state_next = SUM_LOOP;
        end else begin
          iter_cnt_next = iter_cnt + 1'b1;
          if (cur_x[0] == 1'b0) begin
            cur_x_next = cur_x >> 1; // even: X/2
          end else begin
            cur_x_next = cur_x + 1'b1; // odd: X+1
          end
        end
      end

      SUM_LOOP: begin
        if (cur_x == R_reg) begin
          S_next = S; // unchanged from last COMPUTE_FX
          state_next = IDLE;
        end else begin
          cur_x_next = cur_x + 1'b1;
          iter_cnt_next = 6'd0;
          state_next = COMPUTE_FX;
        end
      end

      default: state_next = IDLE;
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cur_x <= 16'd0;
      iter_cnt <= 6'd0;
      S <= 21'd0;
      L_reg <= 16'd0;
      R_reg <= 16'd0;
      done <= 1'b0;
    end else begin
      state <= state_next;
      cur_x <= cur_x_next;
      iter_cnt <= iter_cnt_next;
      S <= S_next;
      done <= (state_next == IDLE) ? 1'b1 : 1'b0;
      if (start) begin
        L_reg <= L;
        R_reg <= R;
      end
    end
  end
endmodule
