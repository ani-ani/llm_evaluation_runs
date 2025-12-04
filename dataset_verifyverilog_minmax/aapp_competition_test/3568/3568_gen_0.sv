module floppy_organ_scheduler(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // start computation
  input [1:0] f, // number of frequencies (1-3)
  // Per-frequency parameters (max 3 frequencies)
  input [15:0] t_0, // period for freq 0
  input [1:0] n_0, // interval count for freq 0 (1-4)
  input [15:0] intervals_0 [0:7], // 4 intervals (8 time points)
  input [15:0] t_1, // period for freq 1
  input [1:0] n_1, // interval count for freq 1
  input [15:0] intervals_1 [0:7],
  input [15:0] t_2, // period for freq 2
  input [1:0] n_2, // interval count for freq 2
  input [15:0] intervals_2 [0:7],
  output reg possible, // 1=possible, 0=impossible
  output reg done // high when computation complete
);

  // State machine states
  localparam IDLE          = 3'b000;
  localparam CHECK_FREQ    = 3'b001;
  localparam CHECK_INTERVAL= 3'b010;
  localparam VERIFY_PAUSE  = 3'b011;
  localparam DONE          = 3'b100;

  // Internal state and datapath
  reg [2:0] state, state_next;
  reg [1:0] freq_idx;     // which frequency is being checked (0..2)
  reg [1:0] freq_idx_next;
  reg [1:0] interval_idx; // which interval within the current frequency (0..(n_i-1))
  reg [1:0] interval_idx_next;
  reg [2:0] loop_cnt;     // loop counter for per-interval checks (0..3)
  reg [2:0] loop_cnt_next;
  reg [15:0] t_reg;       // selected period (t_i)
  reg [15:0] t_reg_next;
  reg [1:0] n_reg;        // selected interval count (n_i)
  reg [1:0] n_reg_next;
  reg [15:0] start_time, start_time_next; // current interval start
  reg [15:0] end_time,   end_time_next;   // current interval end
  reg [15:0] next_start, next_start_next; // next interval start (if exists)
  reg curr_dir, next_dir; // 0=downward, 1=upward
  reg [15:0] sweep_max, sweep_max_next;   // maximum sweep time from last interval end to period end (considering final 1fs pause)
  reg freq_ok;            // per-frequency valid flag
  reg freq_ok_next;
  reg possible_next;
  reg done_next;
  reg [6:0] cycle_counter; // cycles elapsed since start (<= 70, safe in 7 bits)
  reg [6:0] cycle_counter_next;
  reg [6:0] max_cycles;    // per-run max cycles (10 + 20*f)
  reg [6:0] max_cycles_next;

  // Per-frequency wires to cleanly select inputs
  wire [15:0] t_w [0:2];
  wire [1:0] n_w [0:2];
  wire [15:0] start_w, end_w, next_start_w;
  assign t_w[0] = t_0;
  assign t_w[1] = t_1;
  assign t_w[2] = t_2;
  assign n_w[0] = n_0;
  assign n_w[1] = n_1;
  assign n_w[2] = n_2;
  assign start_w = intervals_0[2*interval_idx];     // placeholder, updated per freq below
  assign end_w   = intervals_0[2*interval_idx + 1]; // placeholder, updated per freq below
  assign next_start_w = intervals_0[2*interval_idx + 2]; // placeholder, updated per freq below

  // Re-select per-frequency arrays for start/end/next_start
  // This is purely combinatorial; intervals_0/1/2 are packed memories.
  reg [15:0] curr_start_w, curr_end_w, curr_next_start_w;
  always @(*) begin
    case (freq_idx)
      2'b00: begin
        curr_start_w     = intervals_0[2*interval_idx];
        curr_end_w       = intervals_0[2*interval_idx + 1];
        curr_next_start_w= intervals_0[2*interval_idx + 2];
      end
      2'b01: begin
        curr_start_w     = intervals_1[2*interval_idx];
        curr_end_w       = intervals_1[2*interval_idx + 1];
        curr_next_start_w= intervals_1[2*interval_idx + 2];
      end
      2'b10: begin
        curr_start_w     = intervals_2[2*interval_idx];
        curr_end_w       = intervals_2[2*interval_idx + 1];
        curr_next_start_w= intervals_2[2*interval_idx + 2];
      end
      default: begin
        curr_start_w     = 16'h0;
        curr_end_w       = 16'h0;
        curr_next_start_w= 16'h0;
      end
    endcase
  end

  // Sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      freq_idx       <= 2'b0;
      interval_idx   <= 2'b0;
      loop_cnt       <= 3'b0;
      t_reg          <= 16'h0;
      n_reg          <= 2'b0;
      start_time     <= 16'h0;
      end_time       <= 16'h0;
      next_start     <= 16'h0;
      curr_dir       <= 1'b0;
      sweep_max      <= 16'h0;
      freq_ok        <= 1'b1;
      possible       <= 1'b0;
      done           <= 1'b0;
      cycle_counter  <= 7'b0;
      max_cycles     <= 7'b0;
    end else begin
      state          <= state_next;
      freq_idx       <= freq_idx_next;
      interval_idx   <= interval_idx_next;
      loop_cnt       <= loop_cnt_next;
      t_reg          <= t_reg_next;
      n_reg          <= n_reg_next;
      start_time     <= start_time_next;
      end_time       <= end_time_next;
      next_start     <= next_start_next;
      curr_dir       <= next_dir;
      sweep_max      <= sweep_max_next;
      freq_ok        <= freq_ok_next;
      possible       <= possible_next;
      done           <= done_next;
      cycle_counter  <= cycle_counter_next;
      max_cycles     <= max_cycles_next;
    end
  end

  // Combinational next-state logic
  always @(*) begin
    // Defaults (prevent latches)
    state_next          = state;
    freq_idx_next       = freq_idx;
    interval_idx_next   = interval_idx;
    loop_cnt_next       = loop_cnt;
    t_reg_next          = t_reg;
    n_reg_next          = n_reg;
    start_time_next     = start_time;
    end_time_next       = end_time;
    next_start_next     = next_start;
    next_dir            = curr_dir;
    sweep_max_next      = sweep_max;
    freq_ok_next        = freq_ok;
    possible_next       = possible;
    done_next           = done;
    cycle_counter_next  = cycle_counter;
    max_cycles_next     = max_cycles;

    case (state)
      IDLE: begin
        possible_next = 1'b0;
        done_next     = 1'b0;
        cycle_counter_next = 7'b0;
        max_cycles_next    = 7'b0;
        if (start) begin
          // Initialize for first frequency
          freq_idx_next    = 2'b0;
          freq_ok_next     = 1'b1;
          // Load parameters for freq 0
          t_reg_next       = t_w[0];
          n_reg_next       = (|n_w[0]) ? n_w[0] : 2'b0; // Defend against 0
          // Prepare first check
          interval_idx_next= 2'b0;
          loop_cnt_next    = 3'b0;
          next_dir         = 1'b0;
          sweep_max_next   = 16'hFFFF; // Will be set in CHECK_FREQ
          cycle_counter_next = 7'b1;   // Count the first cycle after start
          max_cycles_next  = 10 + 20 * f;
          state_next       = CHECK_FREQ;
        end
      end

      CHECK_FREQ: begin
        // Load frequency parameters at loop start (loop_cnt==0)
        if (loop_cnt == 3'b0) begin
          // Sanity on f
          if (freq_idx >= (f + 1)) begin
            // Nothing to process for this idx; finalize immediately
            interval_idx_next = 2'b0;
            loop_cnt_next     = 3'b0;
            state_next        = DONE;
          end else begin
            t_reg_next  = t_w[freq_idx];
            n_reg_next  = (|n_w[freq_idx]) ? n_w[freq_idx] : 2'b0;
            // Initialize direction and sweep limit for this freq
            // Sweep from 0 to period-1 takes (t_reg) units; add 1fs pause at end => (t_reg + 1)
            sweep_max_next = (t_reg + 16'h1);
            // Set up for first interval
            interval_idx_next = 2'b0;
            loop_cnt_next     = 3'b1; // Move to interval check next cycle
          end
        end else begin
          // Normal path
          cycle_counter_next = cycle_counter + 1;
          if (freq_idx >= (f + 1)) begin
            // No more frequencies to process
            state_next = DONE;
          end else if (n_reg == 2'b0) begin
            // No intervals defined for this freq => impossible per rules (n in 1-4)
            freq_ok_next = 1'b0;
            state_next   = DONE;
          end else begin
            // Proceed to verify each interval in sequence
            state_next = CHECK_INTERVAL;
          end
        end
      end

      CHECK_INTERVAL: begin
        cycle_counter_next = cycle_counter + 1;
        // Pull current interval data (per-frequency arrays)
        start_time_next = curr_start_w;
        end_time_next   = curr_end_w;
        next_start_next = curr_next_start_w;

        // Basic bounds and ordering checks
        if (start_time >= t_reg) begin
          // Start exceeds period
          freq_ok_next = 1'b0;
        end else if (end_time >= t_reg) begin
          // End exceeds period
          freq_ok_next = 1'b0;
        end else if (start_time >= end_time) begin
          // Non-ascending interval
          freq_ok_next = 1'b0;
        end else begin
          // Direction logic: ascending => up, descending => down
          if (interval_idx == 2'b0) begin
            // First interval; set direction
            next_dir = (start_time <= end_time) ? 1'b1 : 1'b0;
          end else begin
            if (start_time <= end_time) begin
              // Upward segment
              if (curr_dir != 1'b1) begin
                // Direction change => 1fs pause is required here, ensure it is between intervals
                if (start_time == end_time) begin
                  // No gap to insert pause; invalid (pause would fall within next interval)
                  freq_ok_next = 1'b0;
                end else if ((start_time + 16'h1) >= end_time) begin
                  // No room to insert a 1fs pause before next interval start
                  freq_ok_next = 1'b0;
                end
              end
              next_dir = 1'b1;
            end else begin
              // Downward segment
              if (curr_dir != 1'b0) begin
                // Direction change => 1fs pause is required here, ensure it is between intervals
                if (start_time == end_time) begin
                  // No gap to insert pause; invalid
                  freq_ok_next = 1'b0;
                else if ((end_time + 16'h1) >= start_time) begin
                  // No room for a 1fs pause before next interval start
                  freq_ok_next = 1'b0;
                end
              end
              next_dir = 1'b0;
            end
          end

          // Check no-overlap and pause insertion feasibility with the next interval
          if (interval_idx < (n_reg - 1)) begin
            // Ensure gap for final 1fs pause at end_time before next_start
            if (end_time + 16'h1 >= next_start_next) begin
              freq_ok_next = 1'b0;
            end
            // Ensure ascending order across intervals
            if (end_time >= next_start_next) begin
              freq_ok_next = 1'b0;
            end
          end

          // Check that whole timeline fits within sweep_max (period + final 1fs pause)
          if (end_time + 16'h1 > sweep_max) begin
            freq_ok_next = 1'b0;
          end
        end

        // Move to verification of pause constraints for this interval
        state_next = VERIFY_PAUSE;
      end

      VERIFY_PAUSE: begin
        cycle_counter_next = cycle_counter + 1;
        if (!freq_ok) begin
          // Already invalid; skip forward
          if (freq_idx < 2) begin
            freq_idx_next = freq_idx + 1;
            interval_idx_next = 2'b0;
            loop_cnt_next = 3'b0;
            state_next = CHECK_FREQ;
          end else begin
            state_next = DONE;
          end
        end else begin
          // Advance to next interval in this frequency
          if (interval_idx < (n_reg - 1)) begin
            interval_idx_next = interval_idx + 1;
            loop_cnt_next     = loop_cnt; // Keep loop count; CHECK_INTERVAL will consume a cycle
            state_next        = CHECK_INTERVAL;
          end else begin
            // Frequency complete; finalize and move to next frequency
            if (freq_idx < 2) begin
              freq_idx_next = freq_idx + 1;
              interval_idx_next = 2'b0;
              loop_cnt_next = 3'b0;
              state_next    = CHECK_FREQ;
            end else begin
              state_next    = DONE;
            end
          end
        end
      end

      DONE: begin
        // possible already reflects AND of all frequencies' results
        done_next = 1'b1;
        // Hold final values
        state_next = DONE;
      end

      default: begin
        state_next = IDLE;
      end
    endcase
  end

  // Determine per-frequency validity and overall possibility at the end
  // Use a small combinational cone to update possible and freq_ok without branching in FSM
  // freq_ok is kept per frequency internally; here we AND across processed frequencies and store to possible.
  always @(*) begin
    // possible_next is updated in IDLE/DONE and after each frequency conclusion.
    // The following ensures when leaving VERIFY_PAUSE with last frequency we finalize.
    // Note: possible_next may have been set earlier; update it when moving to DONE.
    if (state == VERIFY_PAUSE && (freq_idx == f) && freq_ok) begin
      // Last frequency just processed successfully
      possible_next = 1'b1;
    end
    // If any frequency fails, mark impossible
    if (state == VERIFY_PAUSE && !freq_ok) begin
      possible_next = 1'b0;
    end
  end

  // Enforce completion deadline: done=1 after (10 + 20*f) cycles
  always @(*) begin
    if (state == IDLE) begin
      done_next = 1'b0;
    end else if (cycle_counter >= max_cycles) begin
      done_next = 1'b1;
    end else begin
      done_next = done; // hold
    end
  end

endmodule