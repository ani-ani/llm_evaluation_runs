module wool_sequence_counter (
  input clk,
  input rst_n,
  input start,
  input [31:0] n,
  input [31:0] m,
  output reg [31:0] result,
  output reg done
);

  parameter MOD = 1000000009;

  typedef enum logic [1:0] {
    IDLE,
    CALC_POW,
    CALC_LOOP,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [31:0] pow_accum = 0;
  reg [31:0] loop_counter = 0;
  reg [31:0] current_result = 0;
  reg [31:0] temp_mult = 0;
  reg [31:0] base = 0;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      pow_accum <= 0;
      loop_counter <= 0;
      current_result <= 0;
      temp_mult <= 0;
      base <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALC_POW;
            pow_accum <= 1;
            loop_counter <= 0;
            current_result <= 1;
          end
        end
        CALC_POW: begin
          if (loop_counter < m) begin
            pow_accum <= (pow_accum * 2) % MOD;
            loop_counter <= loop_counter + 1;
          end else begin
            base <= (pow_accum - 1) % MOD;
            loop_counter <= 0;
            current_result <= 1;
            state <= CALC_LOOP;
          end
        end
        CALC_LOOP: begin
          if (loop_counter < n) begin
            temp_mult <= (base - loop_counter) % MOD;
            current_result <= (current_result * temp_mult) % MOD;
            loop_counter <= loop_counter + 1;
          end else begin
            result <= current_result;
            done <= 1;
            state <= DONE;
          end
        end
        DONE: begin
          if (!start) begin
            done <= 0;
            state <= IDLE;
          end
        end
      endcase
    end
  end

endmodule