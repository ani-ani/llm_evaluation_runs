module power_calculator (
  input clk,
  input rst_n,
  input start,
  input [31:0] a,
  input [15:0] b,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_ZERO,
    CHECK_ONE,
    COMPUTE,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [31:0] temp_result;
  reg [3:0] counter;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
      temp_result <= 0;
      counter <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CHECK_ZERO;
      end
      CHECK_ZERO: begin
        if (b == 0) next_state = DONE;
        else next_state = CHECK_ONE;
      end
      CHECK_ONE: begin
        if (b == 1 || a == 0) next_state = DONE;
        else next_state = COMPUTE;
      end
      COMPUTE: begin
        if (counter == 0) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(*) begin
    case (current_state)
      IDLE: begin
        result = 0;
        done = 0;
        temp_result = 0;
        counter = 0;
      end
      CHECK_ZERO: begin
        if (b == 0) begin
          result = 1;
          done = 0;
        end
      end
      CHECK_ONE: begin
        if (b == 1) begin
          result = a;
          done = 0;
        end else if (a == 0) begin
          result = 0;
          done = 0;
        end
      end
      COMPUTE: begin
        if (counter == b-1) begin
          temp_result = a;
        end else if (counter > 0) begin
          temp_result = temp_result * a;
        end
        result = temp_result;
        done = 0;
      end
      DONE: begin
        done = 1;
      end
      default: begin
        result = 0;
        done = 0;
      end
    endcase
  end

  // Counter logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 0;
    end else if (current_state == COMPUTE && counter > 0) begin
      counter <= counter - 1;
    end else if (current_state == COMPUTE && counter == 0) begin
      counter <= 0;
    end else if (current_state == CHECK_ONE && b > 1 && a != 0) begin
      counter <= b - 1;
    end else begin
      counter <= 0;
    end
  end

endmodule