module diophantine_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] a,
  input [7:0] b,
  input [7:0] n,
  output reg [7:0] x,
  output reg [7:0] y,
  output reg valid,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK,
    CALC,
    FOUND,
    NOT_FOUND
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] x_reg;
  reg [15:0] a_x_product;
  reg [15:0] remainder;
  reg [7:0] x_counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      x_reg <= 0;
      a_x_product <= 0;
      remainder <= 0;
      x_counter <= 0;
      x <= 0;
      y <= 0;
      valid <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          x_reg <= 0;
          x_counter <= 0;
          valid <= 0;
          done <= 0;
        end

        CHECK: begin
          if (x_counter < 16) begin
            a_x_product <= a * x_counter;
          end
        end

        CALC: begin
          remainder <= n - a_x_product;
        end

        FOUND: begin
          x <= x_counter;
          y <= remainder / b;
          valid <= 1;
          done <= 1;
        end

        NOT_FOUND: begin
          valid <= 0;
          done <= 1;
        end

        default: begin
          current_state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = CHECK;
        end
      end

      CHECK: begin
        if (x_counter >= 16) begin
          next_state = NOT_FOUND;
        end else if (a_x_product > n) begin
          next_state = NOT_FOUND;
        end else begin
          next_state = CALC;
        end
      end

      CALC: begin
        if (remainder < 0) begin
          next_state = NOT_FOUND;
        end else if (remainder % b == 0) begin
          next_state = FOUND;
        end else begin
          next_state = CHECK;
          x_counter = x_counter + 1;
        end
      end

      FOUND, NOT_FOUND: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule