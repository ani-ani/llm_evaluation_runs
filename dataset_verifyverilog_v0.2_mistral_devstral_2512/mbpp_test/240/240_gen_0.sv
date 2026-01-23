module replace_list (
  input clk,
  input rst_n,
  input start,
  input [7:0] list1_len,
  input [7:0] list2_len,
  input [2:0] list1_addr,
  input [7:0] list1_data_in,
  input [2:0] list2_addr,
  input [2:0] list2_data_in,
  input load_done,
  output reg [2:0] result_addr,
  output reg [7:0] result_data,
  output reg result_valid,
  output reg done,
  output reg [3:0] result_len
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    LOAD,
    PROCESS,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal memory for lists
  reg [7:0] list1 [0:7];
  reg [2:0] list2 [0:7];

  // Internal registers
  reg [3:0] result_counter;
  reg [3:0] list1_counter;
  reg [3:0] list2_counter;
  reg [3:0] delay_counter;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result_counter <= 0;
      list1_counter <= 0;
      list2_counter <= 0;
      delay_counter <= 0;
      result_addr <= 0;
      result_data <= 0;
      result_valid <= 0;
      done <= 0;
      result_len <= 0;
    end else begin
      current_state <= next_state;

      // Load list1 data
      if (current_state == LOAD && list1_addr < list1_len) begin
        list1[list1_addr] <= list1_data_in;
      end

      // Load list2 data
      if (current_state == LOAD && list2_addr < list2_len) begin
        list2[list2_addr] <= list2_data_in;
      end

      // Process state operations
      if (current_state == PROCESS) begin
        if (delay_counter < 2) begin
          delay_counter <= delay_counter + 1;
        end else if (result_counter < result_len) begin
          if (result_counter < list1_len - 1) begin
            result_data <= list1[result_counter];
          end else begin
            result_data <= list2[result_counter - (list1_len - 1)];
          end
          result_addr <= result_counter;
          result_valid <= 1;
          result_counter <= result_counter + 1;
        end else begin
          result_valid <= 0;
        end
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD;
      end
      LOAD: begin
        if (load_done) begin
          next_state = PROCESS;
          result_len = list1_len + list2_len - 1;
        end
      end
      PROCESS: begin
        if (result_counter >= result_len) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
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