module iscube (
  input clk,
  input rst_n,
  input start,
  input signed [7:0] a,
  output reg result,
  output reg done
);

  // Define states
  typedef enum logic [1:0] {
    IDLE,
    CHECKING,
    DONE
  } state_t;

  // State registers
  state_t state, next_state;
  reg signed [2:0] current_root;
  reg signed [7:0] current_cube;
  reg [3:0] counter;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_root <= 0;
      counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      state <= next_state;
      if (state == CHECKING) begin
        if (counter < 5) begin
          current_root <= counter + 1;
          counter <= counter + 1;
        end
      end else begin
        current_root <= 0;
        counter <= 0;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CHECKING;
      end
      CHECKING: begin
        if (counter == 5) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Cube calculation and comparison
  always @(*) begin
    current_cube = current_root * current_root * current_root;
  end

  // Result and done logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          result <= 0;
          done <= 0;
        end
        CHECKING: begin
          if (current_cube == a) begin
            result <= 1;
            next_state = DONE;
          end else if (counter == 5) begin
            result <= 0;
          end
        end
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

endmodule