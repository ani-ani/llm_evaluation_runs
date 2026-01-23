module maximum_k (
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [2:0] n,
  input signed [7:0] arr [0:6],
  output reg signed [7:0] result [0:6],
  output reg done
);

  // Internal buffer for sorting
  reg signed [7:0] buffer [0:6];

  // State machine
  typedef enum logic [3:0] {
    IDLE,
    CHECK_DONE,
    SORT_PASS,
    SELECT_TOP_K,
    COMPLETE
  } state_t;
  state_t state, next_state;

  // Counters
  reg [2:0] pass_count = 0;
  reg [2:0] comp_count = 0;
  reg [2:0] copy_count = 0;

  // Temporary variables for swapping
  reg signed [7:0] temp;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      state <= IDLE;
      pass_count <= 0;
      comp_count <= 0;
      copy_count <= 0;
      for (int i = 0; i < 7; i = i + 1) begin
        result[i] <= 0;
        buffer[i] <= 0;
      end
    end else begin
      state <= next_state;
      done <= (state == COMPLETE);
    end
  end

  // State machine logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          if (k == 0) begin
            next_state = COMPLETE;
          end else begin
            next_state = CHECK_DONE;
          end
        end
      end

      CHECK_DONE: begin
        if (pass_count == n - 1) begin
          next_state = SELECT_TOP_K;
        end else begin
          next_state = SORT_PASS;
        end
      end

      SORT_PASS: begin
        if (comp_count == n - pass_count - 1) begin
          next_state = CHECK_DONE;
        end
      end

      SELECT_TOP_K: begin
        if (copy_count == k - 1) begin
          next_state = COMPLETE;
        end
      end

      COMPLETE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Copy input array to buffer
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 0; i < 7; i = i + 1) begin
        buffer[i] <= 0;
      end
    end else if (start && state == IDLE && k != 0) begin
      for (int i = 0; i < 7; i = i + 1) begin
        if (i < n) begin
          buffer[i] <= arr[i];
        end else begin
          buffer[i] <= 0;
        end
      end
    end
  end

  // Bubble sort logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pass_count <= 0;
      comp_count <= 0;
    end else if (state == SORT_PASS) begin
      if (buffer[comp_count] > buffer[comp_count + 1]) begin
        temp <= buffer[comp_count];
        buffer[comp_count] <= buffer[comp_count + 1];
        buffer[comp_count + 1] <= temp;
      end
      comp_count <= comp_count + 1;
      if (comp_count == n - pass_count - 1) begin
        comp_count <= 0;
        pass_count <= pass_count + 1;
      end
    end
  end

  // Copy top k elements to result
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      copy_count <= 0;
      for (int i = 0; i < 7; i = i + 1) begin
        result[i] <= 0;
      end
    end else if (state == SELECT_TOP_K) begin
      result[copy_count] <= buffer[n - k + copy_count];
      copy_count <= copy_count + 1;
    end
  end

endmodule