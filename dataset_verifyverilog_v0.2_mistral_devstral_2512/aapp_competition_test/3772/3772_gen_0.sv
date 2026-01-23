module resistance_calculator (
  input clk,
  input rst_n,
  input start,
  input [63:0] a,
  input [63:0] b,
  output reg [63:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALCULATE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [63:0] current_a, current_b;
  reg [63:0] sum;
  reg [63:0] quotient, remainder;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      current_a <= 0;
      current_b <= 0;
      sum <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CALCULATE;
        end else begin
          next_state = IDLE;
        end
      end

      CALCULATE: begin
        if (current_b == 0) begin
          next_state = DONE;
        end else begin
          next_state = CALCULATE;
        end
      end

      DONE: begin
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_a <= 0;
      current_b <= 0;
      sum <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            current_a <= a;
            current_b <= b;
            sum <= 0;
            done <= 0;
          end
        end

        CALCULATE: begin
          if (current_b == 0) begin
            result <= sum;
            done <= 1;
          end else begin
            // Compute quotient and remainder
            quotient = current_a / current_b;
            remainder = current_a % current_b;

            // Add quotient to sum
            sum <= sum + quotient;

            // Update current_a and current_b
            current_a <= current_b;
            current_b <= remainder;
          end
        end

        DONE: begin
          // Stay in DONE until reset or new start
          if (start) begin
            current_a <= a;
            current_b <= b;
            sum <= 0;
            done <= 0;
          end
        end

        default: begin
          current_a <= 0;
          current_b <= 0;
          sum <= 0;
          result <= 0;
          done <= 0;
        end
      endcase
    end
  end

endmodule