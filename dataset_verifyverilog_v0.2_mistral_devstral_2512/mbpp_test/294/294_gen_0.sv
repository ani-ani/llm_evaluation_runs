module max_val_heterogeneous (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_elements,
  input [7:0] array_data [0:7],
  output reg [7:0] max_int_result,
  output reg done,
  output reg valid
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SCAN,
    UPDATE_MAX,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] index;
  reg [7:0] max_val;
  reg integer_found;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      index <= 0;
      max_val <= 0;
      max_int_result <= 0;
      done <= 0;
      valid <= 0;
      integer_found <= 0;
    end else begin
      current_state <= next_state;
      if (next_state == UPDATE_MAX) begin
        if (array_data[index] > max_val) begin
          max_val <= array_data[index];
        end
      end
      if (next_state == DONE) begin
        max_int_result <= max_val;
        done <= 1;
        valid <= integer_found;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = SCAN;
          index = 0;
          max_val = 0;
          integer_found = 0;
          done = 0;
          valid = 0;
        end
      end
      SCAN: begin
        if (index == num_elements) begin
          next_state = DONE;
        end else begin
          if (array_data[index] != 0) begin
            integer_found = 1;
            if (array_data[index] > max_val) begin
              next_state = UPDATE_MAX;
            end else begin
              index = index + 1;
            end
          end else begin
            index = index + 1;
          end
        end
      end
      UPDATE_MAX: begin
        index = index + 1;
        if (index == num_elements) begin
          next_state = DONE;
        end else begin
          next_state = SCAN;
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