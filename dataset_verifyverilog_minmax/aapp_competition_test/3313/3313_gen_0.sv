module gem_collector(
  input clk, // 100MHz clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [3:0] gem_count, // number of gems (1-8)
  input [3:0] r, // velocity ratio (1-10)
  input [7:0] w, // track width (0-255)
  input [7:0] h, // finish height (0-255)
  input [7:0] gem_x [0:7], // gem x coordinates (0-8'd255)
  input [7:0] gem_y [0:7], // gem y coordinates (1-8'd255)
  output reg [3:0] max_gems, // maximum collectable gems (0-8)
  output reg done // high when computation complete
);

  // State machine states
  localparam IDLE        = 2'b00;
  localparam SORTING     = 2'b01;
  localparam CALCULATING = 2'b10;
  localparam DONE        = 2'b11;

  // Internal storage for sorted gems
  reg [7:0] sorted_x [0:7];
  reg [7:0] sorted_y [0:7];

  // DP array (max path length ending at each gem)
  reg [3:0] dp [0:7];

  // Counters/indices for algorithm progression
  reg [6:0] cycles;         // cycle counter for both phases (max 128)
  reg [2:0] i_idx, j_idx;   // i and j for DP loops

  // State register
  reg [1:0] state, next_state;

  // Control signals
  wire start_pulse;
  reg  do_sort_step, do_dp_step;

  // Start pulse detection (single cycle)
  reg start_d1;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d1 <= 1'b0;
    end else begin
      start_d1 <= start;
    end
  end
  assign start_pulse = start && !start_d1;

  // State register with async reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // State machine next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse) next_state = SORTING;
      end
      SORTING: begin
        if (cycles >= 7) next_state = CALCULATING; // sort completes in 8 cycles
      end
      CALCULATING: begin
        if (cycles >= 127) next_state = DONE; // worst-case 128 cycles
      end
      DONE: begin
        if (!start_pulse) next_state = IDLE; // wait for next start
      end
      default: next_state = IDLE;
    endcase
  end

  // Output control
  always @(*) begin
    done = (state == DONE);
    if (state == IDLE) begin
      max_gems = 4'd0;
    end
  end

  // Combinational control for steps
  always @(*) begin
    do_sort_step = (state == SORTING);
    do_dp_step   = (state == CALCULATING);
  end

  // Cycle counter and DP indices
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycles <= 7'd0;
      i_idx  <= 3'd0;
      j_idx  <= 3'd0;
    end else begin
      case (state)
        SORTING: begin
          cycles <= cycles + 1'b1; // one bubble-compare per cycle (8 cycles total)
        end
        CALCULATING: begin
          cycles <= cycles + 1'b1; // up to 128 cycles, but typically 64
          // Update DP indices in sync with do_dp_step
          if (do_dp_step) begin
            if (j_idx == 3'd0) begin
              if (i_idx == 3'd7) begin
                // All i processed; hold indices
                i_idx <= i_idx;
                j_idx <= j_idx;
              end else begin
                i_idx <= i_idx + 1'b1;
                j_idx <= i_idx; // start j = i
              end
            end else begin
              j_idx <= j_idx - 1'b1; // j loops downwards
            end
          end
        end
        default: begin
          cycles <= 7'd0;
          i_idx  <= 3'd0;
          j_idx  <= 3'd0;
        end
      endcase
    end
  end

  // Sorting: load and bubble-sort by ascending y (if start)
  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (k = 0; k < 8; k = k + 1) begin
        sorted_x[k] <= 8'd0;
        sorted_y[k] <= 8'd0;
      end
    end else begin
      if (state == IDLE) begin
        // Initialize with zeros or keep prior; choose zeros for cleanliness
        for (k = 0; k < 8; k = k + 1) begin
          sorted_x[k] <= 8'd0;
          sorted_y[k] <= 8'd0;
        end
      end else if (start_pulse) begin
        // Load input arrays into sorted arrays
        for (k = 0; k < 8; k = k + 1) begin
          if (k < gem_count) begin
            sorted_x[k] <= gem_x[k];
            sorted_y[k] <= gem_y[k];
          end else begin
            sorted_x[k] <= 8'd255; // push invalid entries to bottom (y large)
            sorted_y[k] <= 8'd255;
          end
        end
      end else if (do_sort_step && (cycles < 7)) begin
        // Bubble one pass per cycle over the active range
        if (cycles < (gem_count - 1)) begin
          if (sorted_y[cycles] > sorted_y[cycles + 1]) begin
            // swap
            sorted_y[cycles]     <= sorted_y[cycles + 1];
            sorted_y[cycles + 1] <= sorted_y[cycles];
            sorted_x[cycles]     <= sorted_x[cycles + 1];
            sorted_x[cycles + 1] <= sorted_x[cycles];
          end
        end
      end
    end
  end

  // DP computation: standard LIS with movement constraint
  // dp[i] = 1 + max(dp[j]) over j < i with |x_i - x_j| <= (y_i - y_j)/r
  // Use 16-bit intermediate for the division to avoid truncation issues.
  reg [15:0] dy;
  reg [15:0] dx_max;
  reg [15:0] abs_dx;
  reg [3:0] best;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (k = 0; k < 8; k = k + 1) dp[k] <= 4'd1;
      max_gems <= 4'd0;
    end else begin
      if (state == SORTING && start_pulse) begin
        // Initialize DP before calculation
        for (k = 0; k < 8; k = k + 1) dp[k] <= 4'd1;
        max_gems <= 4'd0;
      end else if (do_dp_step) begin
        // Start a new i on the cycle where j is set to i
        if (j_idx == i_idx) begin
          dp[i_idx] <= 4'd1; // base case: at least this gem
        end else if (j_idx < i_idx) begin
          // Evaluate transition from j to i
          dy     = {8'd0, sorted_y[i_idx]} - {8'd0, sorted_y[j_idx]};
          dx_max = dy / {12'd0, r};      // floor division, 16-bit intermediate
          abs_dx = (sorted_x[i_idx] >= sorted_x[j_idx]) ?
                   ({8'd0, sorted_x[i_idx]} - {8'd0, sorted_x[j_idx]}) :
                   ({8'd0, sorted_x[j_idx]} - {8'd0, sorted_x[i_idx]});

          if (abs_dx <= dx_max) begin
            best = dp[j_idx] + 1'b1;
            if (best > dp[i_idx]) begin
              dp[i_idx] <= best;
            end
          end
        end
      end else if (state == CALCULATING && cycles == 7'd126) begin
        // Final read-out: compute max over dp[0..gem_count-1]
        max_gems <= 4'd1; // at least 1 if gem_count >= 1
        if (gem_count == 4'd0) begin
          max_gems <= 4'd0;
        end else begin
          for (k = 0; k < 8; k = k + 1) begin
            if (k < gem_count) begin
              if (dp[k] > max_gems) begin
                max_gems <= dp[k];
              end
            end
          end
        end
      end
    end
  end

endmodule