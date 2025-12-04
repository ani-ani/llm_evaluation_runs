module pancake_sort(input clk, input rst_n, input start, input [7:0] data_in [7:0], output reg [7:0] sorted [7:0], output reg done);
  parameter IDLE = 2'd0;
  parameter FIND_FLIP1 = 2'd1;
  parameter FLIP2 = 2'd2;
  parameter DONE = 2'd3;
  
  reg [1:0] state, next_state;
  reg [7:0] work_array [7:0];
  reg [7:0] next_work_array [7:0];
  reg [2:0] current_size, next_current_size;
  reg [2:0] max_index;
  reg [7:0] max_value;
  
  // Combinational max finder
  always @(*) begin
    max_value = 0;
    max_index = 0;
    for (int i=0; i<current_size; i++) begin
      if (work_array[i] > max_value) begin
        max_value = work_array[i];
        max_index = i;
      end
    end
  end
  
  // FSM state register
  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      done <= 0;
      current_size <= 3'd8;
      for (int k=0; k<8; k++) work_array[k] <= 0;
    end else begin
      state <= next_state;
      done <= next_done;
      current_size <= next_current_size;
      for (int k=0; k<8; k++) work_array[k] <= next_work_array[k];
    end
  end
  
  // FSM combinational logic
  reg next_done;
  always @(*) begin
    next_state = state;
    for (int k=0; k<8; k++) next_work_array[k] = work_array[k];
    next_current_size = current_size;
    next_done = done;
    
    case(state)
      IDLE: begin
        if (start) begin
          next_state = FIND_FLIP1;
          for (int k=0; k<8; k++) next_work_array[k] = data_in[k];
          next_current_size = 3'd8;
          next_done = 0;
        end
      end
      FIND_FLIP1: begin
        for (int i=0; i<=max_index; i++) next_work_array[i] = work_array[max_index - i];
        for (int i=max_index+1; i<8; i++) next_work_array[i] = work_array[i];
        next_state = FLIP2;
      end
      FLIP2: begin
        for (int i=0; i<current_size; i++) next_work_array[i] = work_array[current_size-1 - i];
        next_current_size = current_size - 1;
        if (next_current_size >= 2) begin
          next_state = FIND_FLIP1;
        end else begin
          next_state = DONE;
          next_done = 1;
        end
      end
      DONE: begin
        next_state = DONE;
        next_done = 1;
      end
      default: next_state = IDLE;
    endcase
  end
  
  // Output assignment
  assign sorted = work_array;
endmodule