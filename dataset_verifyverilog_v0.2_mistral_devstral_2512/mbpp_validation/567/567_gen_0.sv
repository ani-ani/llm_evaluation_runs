module is_sorted_checker (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in,
  input [2:0] index,
  input data_valid,
  output reg is_sorted,
  output reg done,
  output reg [2:0] error_index
);

  // Define states
  typedef enum logic [1:0] {
    IDLE,
    LOAD_DATA,
    CHECKING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] list [0:7];
  reg [2:0] data_count;
  reg [2:0] check_index;
  reg [2:0] first_error;
  reg all_loaded;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      data_count <= 0;
      check_index <= 0;
      first_error <= 0;
      all_loaded <= 0;
      is_sorted <= 0;
      done <= 0;
      error_index <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD_DATA;
      end
      LOAD_DATA: begin
        if (data_count == 7) begin
          next_state = CHECKING;
        end
      end
      CHECKING: begin
        if (check_index == 6) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Data loading logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_count <= 0;
      all_loaded <= 0;
    end else begin
      if (current_state == LOAD_DATA && data_valid) begin
        list[index] <= data_in;
        if (index == data_count) begin
          data_count <= data_count + 1;
        end
        if (data_count == 7) begin
          all_loaded <= 1;
        end
      end
    end
  end

  // Checking logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      check_index <= 0;
      first_error <= 0;
      is_sorted <= 0;
      error_index <= 0;
    end else begin
      if (current_state == CHECKING) begin
        if (list[check_index] > list[check_index + 1] && first_error == 0) begin
          first_error <= check_index;
        end
        check_index <= check_index + 1;
        if (check_index == 6) begin
          is_sorted <= (first_error == 0);
          error_index <= first_error;
        end
      end
    end
  end

  // Done signal
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else begin
      if (current_state == DONE) begin
        done <= 1;
      end else begin
        done <= 0;
      end
    end
  end

endmodule