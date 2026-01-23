module bracket_validator (
  input clk,
  input rst_n,
  input start,
  input [127:0] brackets,
  input [4:0] length,
  output reg valid,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [4:0] index;
  reg [4:0] counter;
  reg underflow;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      index <= 0;
      counter <= 0;
      underflow <= 0;
      valid <= 1;
      done <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            index <= 0;
            counter <= 0;
            underflow <= 0;
            valid <= 1;
            done <= 0;
          end
        end

        PROCESSING: begin
          if (index < length) begin
            // Process current character
            if (brackets[(index + 1) * 8 - 1 : index * 8] == "<") begin
              counter <= counter + 1;
            end else if (brackets[(index + 1) * 8 - 1 : index * 8] == ">") begin
              if (counter == 0) begin
                underflow <= 1;
                valid <= 0;
              end
              counter <= counter - 1;
            end
            index <= index + 1;
          end
        end

        DONE: begin
          // Hold state until reset or new start
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
          next_state = PROCESSING;
        end
      end

      PROCESSING: begin
        if (index == length) begin
          next_state = DONE;
          done = 1;
          if (counter != 0 || underflow) begin
            valid = 0;
          end
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

endmodule