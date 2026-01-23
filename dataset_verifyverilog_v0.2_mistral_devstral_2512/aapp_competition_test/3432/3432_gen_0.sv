module minimal_max_sum (
  input clk,
  input rst_n,
  input start,
  input [6:0] a_in,
  input [6:0] b_in,
  input data_valid,
  output reg [7:0] result,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    COLLECT,
    SORT_A,
    SORT_B,
    CALCULATE,
    DONE
  } state_t;

  state_t state, next_state;

  // Array storage (8 elements, 7 bits each)
  reg [6:0] a_buffer [0:7];
  reg [6:0] b_buffer [0:7];

  // Control signals
  reg [2:0] collect_count;
  reg [2:0] sort_pass_a;
  reg [2:0] sort_pass_b;
  reg [2:0] sort_index;
  reg [2:0] calc_index;
  reg [7:0] max_sum;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      collect_count <= 0;
      sort_pass_a <= 0;
      sort_pass_b <= 0;
      sort_index <= 0;
      calc_index <= 0;
      max_sum <= 0;
      done <= 0;
      error <= 0;
      result <= 0;
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
        if (collect_count == 7 || (data_valid && collect_count == 7)) begin
          next_state = SORT_A;
        end
      end
      SORT_A: begin
        if (sort_pass_a == 7 && sort_index == 6) begin
          next_state = SORT_B;
        end
      end
      SORT_B: begin
        if (sort_pass_b == 7 && sort_index == 6) begin
          next_state = CALCULATE;
        end
      end
      CALCULATE: begin
        if (calc_index == 7) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (start) begin
          next_state = COLLECT;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Data collection
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      collect_count <= 0;
      error <= 0;
    end else if (state == COLLECT && data_valid) begin
      if (collect_count < 8) begin
        a_buffer[collect_count] <= a_in;
        b_buffer[collect_count] <= b_in;
        collect_count <= collect_count + 1;
      end else begin
        error <= 1;
      end
    end
  end

  // Bubble sort for array A (ascending)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sort_pass_a <= 0;
      sort_index <= 0;
    end else if (state == SORT_A) begin
      if (sort_index < 7 - sort_pass_a) begin
        if (a_buffer[sort_index] > a_buffer[sort_index + 1]) begin
          // Swap
          reg [6:0] temp = a_buffer[sort_index];
          a_buffer[sort_index] <= a_buffer[sort_index + 1];
          a_buffer[sort_index + 1] <= temp;
        end
        sort_index <= sort_index + 1;
      end else begin
        sort_index <= 0;
        sort_pass_a <= sort_pass_a + 1;
      end
    end
  end

  // Bubble sort for array B (descending)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sort_pass_b <= 0;
      sort_index <= 0;
    end else if (state == SORT_B) begin
      if (sort_index < 7 - sort_pass_b) begin
        if (b_buffer[sort_index] < b_buffer[sort_index + 1]) begin
          // Swap
          reg [6:0] temp = b_buffer[sort_index];
          b_buffer[sort_index] <= b_buffer[sort_index + 1];
          b_buffer[sort_index + 1] <= temp;
        end
        sort_index <= sort_index + 1;
      end else begin
        sort_index <= 0;
        sort_pass_b <= sort_pass_b + 1;
      end
    end
  end

  // Calculate max sum
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      calc_index <= 0;
      max_sum <= 0;
    end else if (state == CALCULATE) begin
      if (calc_index < 8) begin
        reg [7:0] current_sum = a_buffer[calc_index] + b_buffer[calc_index];
        if (current_sum > max_sum) begin
          max_sum <= current_sum;
        end
        calc_index <= calc_index + 1;
      end
    end
  end

  // Output handling
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      result <= 0;
    end else if (state == DONE) begin
      done <= 1;
      result <= max_sum;
    end else begin
      done <= 0;
    end
  end

endmodule