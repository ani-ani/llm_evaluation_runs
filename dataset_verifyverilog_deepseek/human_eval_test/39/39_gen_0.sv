module prime_fib (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  output reg [14:0] result,
  output reg done
);

  typedef enum logic [2:0] { IDLE, GENERATE, CHECK_PRIME, EVALUATE, DONE } state_t;
  state_t state;

  reg [14:0] fib_prev, fib_curr;
  reg [7:0] divisor;
  reg [2:0] prime_count;
  reg [2:0] n_reg;
  wire [14:0] fib_next = fib_prev + fib_curr;
  wire [14:0] divisor_sq = divisor * divisor;
  wire is_divisible = (fib_curr % divisor) == 0;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      fib_prev <= 15'd1;
      fib_curr <= 15'd2;
      divisor <= 8'd2;
      prime_count <= 3'd0;
      result <= 15'd0;
      done <= 1'b0;
      n_reg <= 3'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            n_reg <= n;
            prime_count <= 3'd0;
            fib_prev <= 15'd1;
            fib_curr <= 15'd2;
            divisor <= 8'd2;
            state <= CHECK_PRIME;
          end
        end

        GENERATE: begin
          fib_prev <= fib_curr;
          fib_curr <= fib_next;
          divisor <= 8'd2;
          state <= CHECK_PRIME;
        end

        CHECK_PRIME: begin
          if (divisor_sq > fib_curr) begin
            state <= EVALUATE;
          end else if (is_divisible) begin
            state <= GENERATE;
          end else begin
            divisor <= divisor + 8'd1;
          end
        end

        EVALUATE: begin
          prime_count <= prime_count + 3'd1;
          if ((prime_count + 3'd1) == n_reg) begin
            result <= fib_curr;
            state <= DONE;
          end else begin
            state <= GENERATE;
          end
        end

        DONE: begin
          done <= 1'b1;
          if (start) state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule