module min_diff (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in,
  input [2:0] index,
  input data_valid,
  output reg [7:0] min_diff,
  output reg done,
  output reg [2:0] state_out
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] LOAD = 3'b001;
  localparam [2:0] SORT = 3'b010;
  localparam [2:0] SORT_PASS = 3'b011;
  localparam [2:0] COMPARE = 3'b100;
  localparam [2:0] DONE = 3'b101;

  reg [2:0] state, next_state;
  reg [7:0] arr [0:7];
  reg [2:0] load_count;
  reg [2:0] outer_loop;
  reg [2:0] inner_loop;
  reg [7:0] temp;
  reg [7:0] current_min_diff;
  reg [2:0] compare_index;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      load_count <= 0;
      outer_loop <= 0;
      inner_loop <= 0;
      current_min_diff <= 8'hFF;
      compare_index <= 0;
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
        if (start) next_state = LOAD;
      end
      LOAD: begin
        if (load_count == 7 && data_valid) next_state = SORT;
      end
      SORT: begin
        if (outer_loop == 7) next_state = COMPARE;
        else next_state = SORT_PASS;
      end
      SORT_PASS: begin
        if (inner_loop == 7 - outer_loop) next_state = SORT;
      end
      COMPARE: begin
        if (compare_index == 6) next_state = DONE;
      end
      DONE: begin
        if (start) next_state = LOAD;
      end
      default: next_state = IDLE;
    endcase
  end

  // Load state: Store input data
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      load_count <= 0;
    end else if (state == LOAD && data_valid) begin
      arr[index] <= data_in;
      if (index == load_count) load_count <= load_count + 1;
    end
  end

  // Sort state: Bubble sort implementation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      outer_loop <= 0;
      inner_loop <= 0;
    end else if (state == SORT) begin
      outer_loop <= outer_loop + 1;
      inner_loop <= 0;
    end else if (state == SORT_PASS) begin
      inner_loop <= inner_loop + 1;
    end
  end

  // Bubble sort comparison and swap
  always @(posedge clk) begin
    if (state == SORT_PASS && inner_loop < 7 - outer_loop) begin
      if (arr[inner_loop] > arr[inner_loop + 1]) begin
        temp <= arr[inner_loop];
        arr[inner_loop] <= arr[inner_loop + 1];
        arr[inner_loop + 1] <= temp;
      end
    end
  end

  // Compare state: Find minimum difference
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      compare_index <= 0;
      current_min_diff <= 8'hFF;
    end else if (state == COMPARE && compare_index < 7) begin
      if (compare_index == 0) begin
        current_min_diff <= arr[1] - arr[0];
      end else begin
        temp <= arr[compare_index + 1] - arr[compare_index];
        if (temp < current_min_diff) begin
          current_min_diff <= temp;
        end
      end
      compare_index <= compare_index + 1;
    end
  end

  // Output assignments
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      min_diff <= 0;
      done <= 0;
    end else begin
      min_diff <= (state == DONE) ? current_min_diff : 0;
      done <= (state == DONE);
    end
  end

  // State output for debugging
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_out <= IDLE;
    end else begin
      state_out <= state;
    end
  end

endmodule