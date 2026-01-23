module gcd_calculator (
  input clk,
  input rst_n,
  input start,
  input [15:0] a,
  input [15:0] b,
  output reg [15:0] result,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK,
    SWAP,
    SUBTRACT,
    SHIFT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [15:0] a_reg, b_reg;
  reg a_even, b_even;
  reg a_lt_b;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      a_reg <= 0;
      b_reg <= 0;
      result <= 0;
      done <= 0;
      error <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            a_reg <= a;
            b_reg <= b;
          end
        end

        CHECK: begin
          if (a_reg == 0 && b_reg == 0) begin
            error <= 1;
          end else if (b_reg == 0) begin
            result <= a_reg;
          end
        end

        SWAP: begin
          {a_reg, b_reg} <= {b_reg, a_reg};
        end

        SUBTRACT: begin
          a_reg <= a_reg - b_reg;
        end

        SHIFT: begin
          if (b_even) begin
            b_reg <= b_reg >> 1;
          end else if (a_even) begin
            a_reg <= a_reg >> 1;
          end
        end

        DONE: begin
          done <= 1;
        end

        default: ;
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CHECK;
      end

      CHECK: begin
        if (a_reg == 0 && b_reg == 0) begin
          next_state = DONE;
        end else if (b_reg == 0) begin
          next_state = DONE;
        end else if (a_reg < b_reg) begin
          next_state = SWAP;
        end else if (b_reg[0] == 0) begin
          next_state = SHIFT;
        end else if (a_reg[0] == 0) begin
          next_state = SHIFT;
        end else begin
          next_state = SUBTRACT;
        end
      end

      SWAP: next_state = CHECK;
      SUBTRACT: next_state = CHECK;
      SHIFT: next_state = CHECK;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Combinational logic for comparisons
  assign a_lt_b = (a_reg < b_reg);
  assign a_even = (a_reg[0] == 0);
  assign b_even = (b_reg[0] == 0);

  // Reset done and error when returning to IDLE
  always @(posedge clk) begin
    if (current_state == IDLE && next_state == IDLE) begin
      done <= 0;
      error <= 0;
    end
  end

endmodule