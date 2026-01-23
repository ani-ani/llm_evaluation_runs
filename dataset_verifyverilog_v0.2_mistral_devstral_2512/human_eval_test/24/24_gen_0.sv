module largest_divisor (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [7:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CHECK,
    ITERATE,
    DONE
  } state_t;

  state_t state;
  reg [7:0] current_candidate;
  reg [7:0] remainder;
  reg [7:0] counter;

  // Reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 8'b0;
      done <= 1'b0;
      current_candidate <= 8'b0;
      remainder <= 8'b0;
      counter <= 8'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECK;
            current_candidate <= n - 1;
            remainder <= 8'b0;
            counter <= 8'b0;
            done <= 1'b0;
          end
        end

        CHECK: begin
          // Compute n % current_candidate
          remainder <= n;
          counter <= current_candidate;
          state <= ITERATE;
        end

        ITERATE: begin
          if (counter > 8'b0) begin
            remainder <= remainder - counter;
            counter <= counter - 1;
          end else begin
            if (remainder == 8'b0) begin
              // Found divisor
              result <= current_candidate;
              state <= DONE;
              done <= 1'b1;
            end else begin
              // Not a divisor, try next candidate
              if (current_candidate == 1) begin
                // No proper divisor found, return 1
                result <= 1;
                state <= DONE;
                done <= 1'b1;
              end else begin
                current_candidate <= current_candidate - 1;
                state <= CHECK;
              end
            end
          end
        end

        DONE: begin
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