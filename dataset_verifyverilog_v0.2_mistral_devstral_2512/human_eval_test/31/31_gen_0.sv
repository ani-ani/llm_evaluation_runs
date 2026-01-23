module is_prime (
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  output reg is_prime_result,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    INIT,
    CHECK_EVEN,
    ITERATE,
    DIVIDE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [15:0] n_reg;
  reg [15:0] d_reg;
  reg [15:0] remainder_reg;
  reg [15:0] sqrt_n_reg;
  reg [15:0] temp_reg;
  reg [7:0] iteration_count;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      is_prime_result <= 0;
      done <= 0;
      n_reg <= 0;
      d_reg <= 0;
      remainder_reg <= 0;
      sqrt_n_reg <= 0;
      temp_reg <= 0;
      iteration_count <= 0;
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
      end
      INIT: begin
        next_state = CHECK_EVEN;
      end
      CHECK_EVEN: begin
        if (n_reg <= 1) next_state = DONE;
        else if (n_reg == 2) next_state = DONE;
        else if (n_reg[0] == 0) next_state = DONE;
        else next_state = ITERATE;
      end
      ITERATE: begin
        if (d_reg * d_reg > n_reg || iteration_count >= 256) next_state = DONE;
        else next_state = DIVIDE;
      end
      DIVIDE: begin
        if (remainder_reg == 0) next_state = DONE;
        else next_state = ITERATE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_reg <= 0;
      d_reg <= 0;
      remainder_reg <= 0;
      sqrt_n_reg <= 0;
      temp_reg <= 0;
      iteration_count <= 0;
    end else begin
      case (current_state)
        INIT: begin
          n_reg <= n;
          d_reg <= 3;
          iteration_count <= 0;
        end
        ITERATE: begin
          if (d_reg * d_reg <= n_reg && iteration_count < 256) begin
            d_reg <= d_reg + 2;
            iteration_count <= iteration_count + 1;
          end
        end
        DIVIDE: begin
          // Compute n_reg % d_reg
          temp_reg <= n_reg;
          remainder_reg <= temp_reg % d_reg;
        end
        DONE: begin
          if (!start) begin
            is_prime_result <= 0;
            done <= 0;
          end
        end
      endcase
    end
  end

  // Output logic
  always @(*) begin
    case (current_state)
      CHECK_EVEN: begin
        if (n_reg <= 1) begin
          is_prime_result = 0;
          done = 1;
        end else if (n_reg == 2) begin
          is_prime_result = 1;
          done = 1;
        end else if (n_reg[0] == 0) begin
          is_prime_result = 0;
          done = 1;
        end
      end
      DIVIDE: begin
        if (remainder_reg == 0) begin
          is_prime_result = 0;
          done = 1;
        end
      end
      DONE: begin
        if (is_prime_result === 1'bx) begin
          if (n_reg <= 1 || n_reg[0] == 0) is_prime_result = 0;
          else if (n_reg == 2) is_prime_result = 1;
          else is_prime_result = 1;
        end
        done = 1;
      end
      default: begin
        is_prime_result = 0;
        done = 0;
      end
    endcase
  end

endmodule