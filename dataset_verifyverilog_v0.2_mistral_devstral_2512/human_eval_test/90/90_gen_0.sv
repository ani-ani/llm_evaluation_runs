module next_smallest (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_elements,
  input [7:0] data_in,
  input data_valid,
  output reg [7:0] result,
  output reg done,
  output reg valid
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COLLECT,
    PROCESS,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] data_array [0:7];
  reg [2:0] element_count;
  reg [7:0] min1, min2;
  reg [2:0] index;
  reg [7:0] current_value;

  // Default assignments
  always @(*) begin
    result = 8'hFF;
    done = 1'b0;
    valid = 1'b0;
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      element_count <= 0;
      index <= 0;
      min1 <= 8'hFF;
      min2 <= 8'hFF;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = COLLECT;
      end
      COLLECT: begin
        if (element_count == num_elements - 1 && data_valid) begin
          next_state = PROCESS;
        end
      end
      PROCESS: begin
        if (index == num_elements - 1) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (start) next_state = COLLECT;
      end
    endcase
  end

  // Data collection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      element_count <= 0;
    end else if (current_state == COLLECT && data_valid) begin
      data_array[element_count] <= data_in;
      element_count <= element_count + 1;
    end
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      index <= 0;
      min1 <= 8'hFF;
      min2 <= 8'hFF;
    end else if (current_state == PROCESS) begin
      current_value = data_array[index];
      if (index == 0) begin
        min1 = current_value;
        min2 = 8'hFF;
      end else begin
        if (current_value < min1) begin
          min2 = min1;
          min1 = current_value;
        end else if (current_value > min1 && (current_value < min2 || min2 == 8'hFF)) begin
          min2 = current_value;
        end
      end
      index <= index + 1;
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 8'hFF;
      done <= 1'b0;
      valid <= 1'b0;
    end else begin
      case (current_state)
        DONE: begin
          if (num_elements >= 2 && min2 != 8'hFF) begin
            result <= min2;
            valid <= 1'b1;
          end else begin
            result <= 8'hFF;
            valid <= 1'b0;
          end
          done <= 1'b1;
        end
        default: begin
          done <= 1'b0;
          valid <= 1'b0;
        end
      endcase
    end
  end

endmodule