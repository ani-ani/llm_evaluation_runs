module paint_the_numbers (
  input clk,
  input rst_n,
  input start,
  input valid_in,
  input [7:0] data_in,
  input [7:0] num_inputs,
  output reg [7:0] num_colors,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    COLLECT,
    SORT,
    PROCESS,
    DONE
  } state_t;
  state_t state, next_state;

  // Internal signals
  reg [6:0] idx; // Array index (0-99)
  reg [6:0] i, j; // Loop counters
  reg [7:0] arr [0:99]; // Input buffer
  reg [7:0] count; // Input counter
  reg [7:0] color_count; // Color counter
  reg [7:0] temp; // Temporary for sorting
  reg [99:0] marked; // Marked flags
  reg [6:0] current; // Current element index
  reg [6:0] next; // Next element index

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      idx <= 0;
      i <= 0;
      j <= 0;
      count <= 0;
      color_count <= 0;
      current <= 0;
      next <= 0;
      done <= 0;
      num_colors <= 0;
      for (int k = 0; k < 100; k++) begin
        arr[k] <= 0;
        marked[k] <= 0;
      end
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = COLLECT;
      end
      COLLECT: begin
        if (count == num_inputs - 1) next_state = SORT;
      end
      SORT: begin
        if (i == 99 && j == 99) next_state = PROCESS;
      end
      PROCESS: begin
        if (current == 99) next_state = DONE;
      end
      DONE: begin
        if (start) next_state = COLLECT;
      end
      default: next_state = IDLE;
    endcase
  end

  // Collect state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count <= 0;
    end else if (state == COLLECT && valid_in) begin
      arr[idx] <= data_in;
      idx <= idx + 1;
      count <= count + 1;
    end
  end

  // Sort state logic (bubble sort)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i <= 0;
      j <= 0;
    end else if (state == SORT) begin
      if (j < 99 - i) begin
        if (arr[j] > arr[j + 1]) begin
          temp <= arr[j];
          arr[j] <= arr[j + 1];
          arr[j + 1] <= temp;
        end
        j <= j + 1;
      end else begin
        j <= 0;
        i <= i + 1;
      end
    end
  end

  // Process state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current <= 0;
      next <= 0;
      color_count <= 0;
      for (int k = 0; k < 100; k++) marked[k] <= 0;
    end else if (state == PROCESS) begin
      if (!marked[current]) begin
        color_count <= color_count + 1;
        marked[current] <= 1;
        next <= current + 1;
        while (next < num_inputs) begin
          if (arr[next] % arr[current] == 0) begin
            marked[next] <= 1;
          end
          next <= next + 1;
        end
      end
      current <= current + 1;
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      num_colors <= 0;
    end else if (state == DONE) begin
      done <= 1;
      num_colors <= color_count;
    end else begin
      done <= 0;
    end
  end

endmodule