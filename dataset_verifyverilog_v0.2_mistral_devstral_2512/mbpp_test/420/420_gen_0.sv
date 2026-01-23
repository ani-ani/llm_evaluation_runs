module cube_sum_even (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COMPUTE,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [3:0] counter;
  reg [31:0] accumulator;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      counter <= 0;
      accumulator <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = COMPUTE;
        else next_state = IDLE;
      end
      COMPUTE: begin
        if (counter == n) next_state = DONE;
        else next_state = COMPUTE;
      end
      DONE: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 0;
      accumulator <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            counter <= 1;
            accumulator <= 0;
          end
        end
        COMPUTE: begin
          if (counter <= n) begin
            // Calculate (2*counter)^3 = 8 * counter^3
            reg [31:0] cube = (counter * counter * counter) << 3;
            accumulator <= accumulator + cube;
            counter <= counter + 1;
          end
        end
        DONE: begin
          result <= accumulator;
          done <= 1;
        end
      endcase
    end
  end

  // Reset done signal when leaving DONE state
  always @(posedge clk) begin
    if (current_state == DONE && next_state == IDLE) begin
      done <= 0;
    end
  end

endmodule