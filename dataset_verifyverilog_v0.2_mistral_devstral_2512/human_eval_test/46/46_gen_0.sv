module fib4 (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    INIT,
    COMPUTE,
    DONE
  } state_t;

  state_t state, next_state;
  reg [15:0] reg0, reg1, reg2, reg3;
  reg [3:0] counter;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      reg0 <= 0;
      reg1 <= 0;
      reg2 <= 0;
      reg3 <= 0;
      counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end
      INIT: begin
        next_state = COMPUTE;
      end
      COMPUTE: begin
        if (counter == n) next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset handled in state transition
    end else begin
      case (state)
        INIT: begin
          // Initialize registers based on base cases
          case (n)
            4'd0, 4'd1, 4'd3: begin
              reg0 <= 0;
              reg1 <= 0;
              reg2 <= 0;
              reg3 <= 0;
              result <= 0;
            end
            4'd2: begin
              reg0 <= 2;
              reg1 <= 0;
              reg2 <= 0;
              reg3 <= 0;
              result <= 2;
            end
            default: begin
              reg0 <= 0;
              reg1 <= 0;
              reg2 <= 2;
              reg3 <= 0;
              counter <= 4;
            end
          endcase
        end
        COMPUTE: begin
          if (counter < n) begin
            // Compute next value
            reg [15:0] new_val = reg0 + reg1 + reg2 + reg3;
            // Shift registers
            reg3 <= reg2;
            reg2 <= reg1;
            reg1 <= reg0;
            reg0 <= new_val;
            counter <= counter + 1;
          end
        end
        DONE: begin
          // Output result based on n
          case (n)
            4'd0, 4'd1, 4'd3: result <= 0;
            4'd2: result <= 2;
            default: result <= reg0;
          endcase
          done <= 1;
        end
        IDLE: begin
          done <= 0;
        end
      endcase
    end
  end

endmodule