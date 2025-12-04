module show_recorder(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [1:0] k,
  input [31:0] show_times[0:15],
  output reg [2:0] count,
  output reg done
);

  // Parameters and typed state enum
  localparam N_MAX = 8;
  localparam SLOT_MAX = 4;

  typedef enum logic [1:0] {
    IDLE      = 2'b00,
    SORTING   = 2'b01,
    ALLOCATING= 2'b10,
    DONE      = 2'b11
  } state_t;

  state_t state;

  // Sorting storage: pairs of [x_i, y_i] for up to 8 shows
  reg [31:0] pairs_x [0:N_MAX-1];
  reg [31:0] pairs_y [0:N_MAX-1];

  // Slot trackers: last end times for up to 4 slots
  reg [31:0] slots [0:SLOT_MAX-1];

  // Bubble sort control
  reg [2:0] s;       // outer pass (0..n-1)
  reg [2:0] i;       // inner index (0..n-2-s)
  reg sorted;        // set when fully sorted
  reg pass_done;     // one-cycle pulse indicating a pass completed
  reg swap;          // indicates a swap occurred during a pass

  // Allocation control
  reg [2:0] show_idx;   // which show is being considered (0..n-1)
  reg [2:0] alloc_count; // number of allocated shows

  // Helper: one-cycle pulse on s increment (end of pass)
  reg [2:0] s_prev;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) s_prev <= 3'b0;
    else s_prev <= s;
  end
  assign pass_done = (s_prev != s) && (s != 3'b0);

  // Update state machine and datapath
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done  <= 1'b0;
      count <= 3'b0;
      sorted <= 1'b0;
      swap   <= 1'b0;
      s <= 3'b0;
      i <= 3'b0;
      show_idx <= 3'b0;
      alloc_count <= 3'b0;
      // Clear slot trackers
      for (int p = 0; p < SLOT_MAX; p++) slots[p] <= 32'h0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          count <= 3'b0;
          // Latch and prep on start
          if (start) begin
            // Load pairs from flat input
            for (int j = 0; j < N_MAX; j++) begin
              if (j < n) begin
                pairs_x[j] <= show_times[2*j];
                pairs_y[j] <= show_times[2*j + 1];
              end else begin
                pairs_x[j] <= 32'h0;
                pairs_y[j] <= 32'h0;
              end
            end
            // Clear slots
            for (int p = 0; p < SLOT_MAX; p++) slots[p] <= 32'h0;
            // Init sort control
            sorted <= (n <= 1);
            swap   <= 1'b0;
            s      <= (n <= 1) ? 3'd0 : 3'd1; // pass 1 when n>=2
            i      <= 3'd0;
            // Init alloc control
            show_idx   <= 3'd0;
            alloc_count<= 3'd0;
            state <= SORTING;
          end
        end

        SORTING: begin
          // Bubble sort: one compare per cycle
          if (!sorted) begin
            if (i < (n - 1 - s)) begin
              // Compare and swap if needed
              if (pairs_y[i] > pairs_y[i+1]) begin
                // Swap y
                pairs_y[i]   <= pairs_y[i+1];
                pairs_y[i+1] <= pairs_y[i];
                // Swap x accordingly
                pairs_x[i]   <= pairs_x[i+1];
                pairs_x[i+1] <= pairs_x[i];
                swap <= 1'b1;
              end else begin
                swap <= 1'b0;
              end
              i <= i + 1; // advance inner index
            end else begin
              // End of pass
              if (swap) begin
                s <= s + 1;
                i <= 3'd0;
              end else begin
                sorted <= 1'b1; // fully sorted, exit sort state next cycle
              end
            end
          end

          // Transition when sorted and either we just finished a pass or n<=1
          if (sorted) begin
            state <= ALLOCATING;
            show_idx   <= 3'd0;
            alloc_count<= 3'd0;
            // Reset slot trackers to 0 (will only use first k slots)
            for (int p = 0; p < SLOT_MAX; p++) slots[p] <= 32'h0;
          end
        end

        ALLOCATING: begin
          if (show_idx < n) begin
            // Greedy allocation: try to place show show_idx into any slot
            // For simplicity, scan slots 0..k-1; this can schedule up to k concurrent shows
            for (int sl = 0; sl < SLOT_MAX; sl++) begin
              if (sl < k && pairs_x[show_idx] >= slots[sl]) begin
                slots[sl] <= pairs_y[show_idx];
                alloc_count <= alloc_count + 1;
              end
            end
            show_idx <= show_idx + 1;
          end else begin
            // All shows considered
            count <= alloc_count;
            done  <= 1'b1;
            state <= DONE;
          end
        end

        DONE: begin
          // Hold results until start or reset
          count <= count;
          done  <= 1'b1;
          if (start) begin
            // Restart if new start pulse arrives
            state <= IDLE;
            done  <= 1'b0;
          end
        end
      endcase
    end
  end

endmodule
