module array_debug (
  input clk,
  input rst_n,
  input start,
  input [5:0] k_val,
  input [5:0] q_val,
  input [5:0] update_val,
  input update_valid,
  input [5:0] query_l,
  input [5:0] query_r,
  input query_valid,
  output reg [31:0] result,
  output reg done,
  output reg ready_for_update,
  output reg ready_for_query
);

  // Parameters
  localparam ARRAY_SIZE = 64;
  localparam MAX_K = 32;
  localparam MAX_Q = 32;

  // States
  typedef enum logic [2:0] {
    IDLE,
    COLLECT_UPDATES,
    PROCESS_UPDATES,
    BUILD_PREFIX,
    COLLECT_QUERIES,
    PROCESS_QUERIES,
    DONE
  } state_t;

  // State registers
  state_t current_state, next_state;
  logic [5:0] update_count;
  logic [5:0] query_count;
  logic [5:0] prefix_index;
  logic [31:0] array [0:ARRAY_SIZE-1];
  logic [31:0] prefix [0:ARRAY_SIZE];
  logic [5:0] current_update;
  logic [5:0] current_query_l, current_query_r;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      update_count <= 0;
      query_count <= 0;
      prefix_index <= 0;
      current_update <= 0;
      current_query_l <= 0;
      current_query_r <= 0;
      done <= 0;
      ready_for_update <= 0;
      ready_for_query <= 0;
      result <= 0;
      for (int i = 0; i < ARRAY_SIZE; i++) begin
        array[i] <= 0;
        prefix[i] <= 0;
      end
      prefix[ARRAY_SIZE] <= 0;
    end else begin
      current_state <= next_state;
      if (current_state == COLLECT_UPDATES && update_valid) begin
        current_update <= update_val;
        update_count <= update_count + 1;
      end
      if (current_state == COLLECT_QUERIES && query_valid) begin
        current_query_l <= query_l;
        current_query_r <= query_r;
        query_count <= query_count + 1;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = COLLECT_UPDATES;
          update_count = 0;
          query_count = 0;
          prefix_index = 0;
          done = 0;
          ready_for_update = 1;
          ready_for_query = 0;
          result = 0;
        end
      end
      COLLECT_UPDATES: begin
        if (update_count == k_val) begin
          next_state = PROCESS_UPDATES;
          ready_for_update = 0;
        end else begin
          ready_for_update = 1;
        end
      end
      PROCESS_UPDATES: begin
        next_state = BUILD_PREFIX;
      end
      BUILD_PREFIX: begin
        if (prefix_index == ARRAY_SIZE) begin
          next_state = COLLECT_QUERIES;
          ready_for_query = 1;
        end else begin
          ready_for_query = 0;
        end
      end
      COLLECT_QUERIES: begin
        if (query_count == q_val) begin
          next_state = DONE;
          done = 1;
          ready_for_query = 0;
        end else begin
          ready_for_query = 1;
        end
      end
      PROCESS_QUERIES: begin
        next_state = COLLECT_QUERIES;
      end
      DONE: begin
        done = 1;
      end
    endcase
  end

  // Update processing
  always @(posedge clk) begin
    if (current_state == PROCESS_UPDATES) begin
      for (int i = 0; i < ARRAY_SIZE; i++) begin
        if (i % current_update == 0) begin
          array[i] <= array[i] + 1;
        end
      end
      next_state = BUILD_PREFIX;
    end
  end

  // Prefix sum computation
  always @(posedge clk) begin
    if (current_state == BUILD_PREFIX) begin
      if (prefix_index == 0) begin
        prefix[0] <= array[0];
        prefix_index <= prefix_index + 1;
      end else if (prefix_index < ARRAY_SIZE) begin
        prefix[prefix_index] <= prefix[prefix_index-1] + array[prefix_index];
        prefix_index <= prefix_index + 1;
      end else begin
        prefix[ARRAY_SIZE] <= prefix[ARRAY_SIZE-1];
        next_state = COLLECT_QUERIES;
      end
    end
  end

  // Query processing
  always @(posedge clk) begin
    if (current_state == COLLECT_QUERIES && query_valid) begin
      next_state = PROCESS_QUERIES;
    end else if (current_state == PROCESS_QUERIES) begin
      if (current_query_l == 0) begin
        result <= prefix[current_query_r];
      end else begin
        result <= prefix[current_query_r] - prefix[current_query_l - 1];
      end
      next_state = COLLECT_QUERIES;
    end
  end

endmodule