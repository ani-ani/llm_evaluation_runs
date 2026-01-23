module prime_checker (
  input clk,
  input rst_n,
  input start,
  input [31:0] num_in,
  output reg is_prime,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    INIT,
    CHECK,
    ITERATE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [31:0] i; // divisor
  reg [31:0] remainder;
  reg [32:0] i_squared; // 33-bit to handle overflow
  reg [31:0] sqrt_limit; // approximate sqrt limit

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      is_prime <= 0;
      done <= 0;
      i <= 0;
      remainder <= 0;
      i_squared <= 0;
      sqrt_limit <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = INIT;
        else next_state = IDLE;
      end
      INIT: begin
        next_state = CHECK;
      end
      CHECK: begin
        if (remainder == 0) next_state = DONE;
        else next_state = ITERATE;
      end
      ITERATE: begin
        if (i >= 128 || i_squared > num_in) next_state = DONE;
        else next_state = CHECK;
      end
      DONE: begin
        if (!start) next_state = IDLE;
        else next_state = DONE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i <= 0;
      remainder <= 0;
      i_squared <= 0;
      sqrt_limit <= 0;
    end else begin
      case (current_state)
        INIT: begin
          i <= 2;
          remainder <= 0;
          i_squared <= 0;
          sqrt_limit <= 0;
        end
        CHECK: begin
          // Compute remainder and i_squared
          remainder <= num_in % i;
          i_squared <= i * i;
        end
        ITERATE: begin
          i <= i + 1;
        end
        default: ;
      endcase
    end
  end

  // Output logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        is_prime = 0;
        done = 0;
      end
      INIT: begin
        is_prime = 0;
        done = 0;
      end
      CHECK: begin
        is_prime = 0;
        done = 0;
      end
      ITERATE: begin
        is_prime = 0;
        done = 0;
      end
      DONE: begin
        // Special cases
        if (num_in < 2) is_prime = 0;
        else if (num_in == 2 || num_in == 3) is_prime = 1;
        else if (remainder == 0) is_prime = 0;
        else is_prime = 1;
        done = 1;
      end
      default: begin
        is_prime = 0;
        done = 0;
      end
    endcase
  end

endmodule