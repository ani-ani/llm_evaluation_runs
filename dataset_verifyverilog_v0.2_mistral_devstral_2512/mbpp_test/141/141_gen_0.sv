module pancake_sort (
  input clk,
  input rst_n,
  input start,
  input [2:0] idx,
  input [7:0] data_in,
  output reg [7:0] sorted_out [0:7],
  output reg done,
  output reg [2:0] debug_state
);

  // Internal array storage
  reg [7:0] array [0:7];
  
  // FSM states
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] FIND_MAX = 3'b001;
  localparam [2:0] FLIP_TO_END = 3'b010;
  localparam [2:0] UPDATE_SIZE = 3'b011;
  localparam [2:0] DONE = 3'b100;
  
  // FSM state register
  reg [2:0] state, next_state;
  
  // Control registers
  reg [2:0] current_size;
  reg [2:0] max_idx;
  reg [2:0] flip_start, flip_end;
  reg [2:0] i, j;
  reg [7:0] max_val;
  reg flip_in_progress;
  reg [2:0] flip_counter;
  
  // Initialize array from data_in
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 8; i = i + 1) begin
        array[i] <= 8'b0;
      end
    end else if (start) begin
      array[idx] <= data_in;
    end
  end
  
  // FSM state transitions
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      current_size <= 8;
      max_idx <= 0;
      flip_start <= 0;
      flip_end <= 0;
      flip_in_progress <= 1'b0;
      flip_counter <= 0;
      i <= 0;
      j <= 0;
    end else begin
      state <= next_state;
    end
  end
  
  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = FIND_MAX;
      end
      FIND_MAX: begin
        if (i == current_size) next_state = FLIP_TO_END;
      end
      FLIP_TO_END: begin
        if (flip_in_progress && flip_counter == flip_end) next_state = UPDATE_SIZE;
      end
      UPDATE_SIZE: begin
        if (current_size == 1) next_state = DONE;
        else next_state = FIND_MAX;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end
  
  // FSM datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      debug_state <= IDLE;
    end else begin
      debug_state <= state;
      case (state)
        IDLE: begin
          done <= 1'b0;
          current_size <= 8;
        end
        FIND_MAX: begin
          if (i == 0) begin
            max_val <= array[0];
            max_idx <= 0;
            i <= 1;
          end else if (i < current_size) begin
            if (array[i] > max_val) begin
              max_val <= array[i];
              max_idx <= i;
            end
            i <= i + 1;
          end
        end
        FLIP_TO_END: begin
          if (!flip_in_progress) begin
            flip_start <= max_idx;
            flip_end <= current_size - 1;
            flip_in_progress <= 1'b1;
            flip_counter <= 0;
          end else if (flip_counter < (flip_end - flip_start + 1) / 2) begin
            // Perform flip operation
            j <= flip_start + flip_counter;
            array[j] <= array[flip_end - flip_counter];
            array[flip_end - flip_counter] <= array[j];
            flip_counter <= flip_counter + 1;
          end
        end
        UPDATE_SIZE: begin
          current_size <= current_size - 1;
          i <= 0;
          flip_in_progress <= 1'b0;
        end
        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end
  
  // Output the sorted array
  always @(posedge clk) begin
    for (i = 0; i < 8; i = i + 1) begin
      sorted_out[i] <= array[i];
    end
  end
  
endmodule