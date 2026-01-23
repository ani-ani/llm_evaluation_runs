module gem_collector (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [5:0] w,
  input [7:0] h,
  input [2:0] gem_index,
  input [5:0] gem_x,
  input [7:0] gem_y,
  input gem_wr,
  output reg [2:0] max_gems,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD_GEMS,
    SORT_GEMS,
    DP_PROCESS,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal storage for gems (max 8 gems)
  logic [5:0] gem_x_mem [0:7];
  logic [7:0] gem_y_mem [0:7];
  logic [2:0] gem_count;

  // Sorting variables
  logic [2:0] sort_i, sort_j;
  logic [5:0] temp_x;
  logic [7:0] temp_y;

  // DP variables
  logic [2:0] dp_i, dp_j;
  logic [2:0] dp_count [0:7];
  logic [2:0] max_count;

  // Timing control
  logic [8:0] cycle_count;

  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      gem_count <= 0;
      sort_i <= 0;
      sort_j <= 0;
      dp_i <= 0;
      dp_j <= 0;
      cycle_count <= 0;
      max_gems <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD_GEMS;
      end
      LOAD_GEMS: begin
        if (gem_count == n) next_state = SORT_GEMS;
      end
      SORT_GEMS: begin
        if (cycle_count >= 512) next_state = DP_PROCESS;
      end
      DP_PROCESS: begin
        if (dp_i == gem_count) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Load gems into memory
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      gem_count <= 0;
      for (int i = 0; i < 8; i++) begin
        gem_x_mem[i] <= 0;
        gem_y_mem[i] <= 0;
      end
    end else if (current_state == LOAD_GEMS && gem_wr && gem_index < 8) begin
      gem_x_mem[gem_index] <= gem_x;
      gem_y_mem[gem_index] <= gem_y;
      if (gem_index == n-1) gem_count <= n;
    end
  end

  // Bubble sort implementation
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sort_i <= 0;
      sort_j <= 0;
    end else if (current_state == SORT_GEMS) begin
      if (sort_j < gem_count - sort_i - 1) begin
        if (gem_y_mem[sort_j] > gem_y_mem[sort_j + 1]) begin
          // Swap
          temp_x = gem_x_mem[sort_j];
          temp_y = gem_y_mem[sort_j];
          gem_x_mem[sort_j] <= gem_x_mem[sort_j + 1];
          gem_y_mem[sort_j] <= gem_y_mem[sort_j + 1];
          gem_x_mem[sort_j + 1] <= temp_x;
          gem_y_mem[sort_j + 1] <= temp_y;
        end
        sort_j <= sort_j + 1;
      end else begin
        sort_j <= 0;
        if (sort_i < gem_count - 1) begin
          sort_i <= sort_i + 1;
        end else begin
          sort_i <= 0;
        end
      end
    end
  end

  // Dynamic programming processing
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      dp_i <= 0;
      dp_j <= 0;
      max_count <= 0;
      for (int i = 0; i < 8; i++) begin
        dp_count[i] <= 0;
      end
    end else if (current_state == DP_PROCESS) begin
      if (dp_j < dp_i) begin
        // Check reachability from previous gems
        if ((dp_j == 0) || 
            (gem_x_mem[dp_i] - gem_x_mem[dp_j]) <= (gem_y_mem[dp_i] - gem_y_mem[dp_j]) ||
            (gem_x_mem[dp_j] - gem_x_mem[dp_i]) <= (gem_y_mem[dp_i] - gem_y_mem[dp_j])) begin
          if (dp_count[dp_j] + 1 > dp_count[dp_i]) begin
            dp_count[dp_i] <= dp_count[dp_j] + 1;
          end
        end
        dp_j <= dp_j + 1;
      end else begin
        dp_j <= 0;
        if (dp_i < gem_count - 1) begin
          dp_i <= dp_i + 1;
        end else begin
          // Find maximum count
          for (int i = 0; i < gem_count; i++) begin
            if (dp_count[i] > max_count) begin
              max_count = dp_count[i];
            end
          end
          max_gems <= max_count + 1; // +1 for starting line
        end
      end
    end
  end

  // Cycle counter
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_count <= 0;
    end else if (current_state == SORT_GEMS) begin
      cycle_count <= cycle_count + 1;
    end else begin
      cycle_count <= 0;
    end
  end

  // Done signal
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
    end else if (current_state == DONE) begin
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule