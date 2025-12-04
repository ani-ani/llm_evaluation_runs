module penguin_plaque_counter(
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  input [3:0] k,
  output reg [31:0] result,
  output reg done
);

  localparam M = 32'd1000000007;
  typedef enum logic [2:0] {
    IDLE,
    CALC_A,
    CALC_B,
    MULTIPLY,
    DONE
  } state_e;

  state_e state, next_state;
  reg [31:0] A_reg, base_reg, current_reg;
  reg [4:0] exp_counter;
  reg [31:0] B_reg;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 32'd0;
      done <= 1'b0;
      A_reg <= 32'd0;
      B_reg <= 32'd0;
      base_reg <= 32'd0;
      current_reg <= 32'd0;
      exp_counter <= 5'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            if (k == 4'd0) begin
              result <= 32'd0;
              next_state <= DONE;
            end else begin
              base_reg <= k;
              exp_counter <= (k >= 1) ? (k - 1) : 5'd0;
              current_reg <= 32'd1;
              next_state <= CALC_A;
            end
          end
        end

        CALC_A: begin
          if (exp_counter > 0) begin
            current_reg <= (current_reg * base_reg) % M;
            exp_counter <= exp_counter - 1;
          end else begin
            A_reg <= current_reg;
            base_reg <= n - k;
            exp_counter <= (n >= k) ? (n - k) : 5'd0;
            current_reg <= 32'd1;
            next_state <= CALC_B;
          end
        end

        CALC_B: begin
          if (n == k) begin
            B_reg <= 32'd1;
            next_state <= MULTIPLY;
          end else if ((n - k) == 0) begin
            B_reg <= 32'd0;
            next_state <= MULTIPLY;
          end else if (exp_counter > 0) begin
            current_reg <= (current_reg * base_reg) % M;
            exp_counter <= exp_counter - 1;
          end else begin
            B_reg <= current_reg;
            next_state <= MULTIPLY;
          end
        end

        MULTIPLY: begin
          result <= (A_reg * B_reg) % M;
          next_state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          if (!start) next_state <= IDLE;
        end
      endcase
    end
  end

  always_comb begin
    next_state = state;
    if (!rst_n) next_state = IDLE;
    if (state == IDLE && start) next_state = (k == 0) ? DONE : CALC_A;
  end

endmodule