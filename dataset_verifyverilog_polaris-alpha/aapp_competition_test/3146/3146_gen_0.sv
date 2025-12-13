module prescription_scheduler(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Start processing (pulse high to begin)
  // Config inputs valid when start=1
  input [2:0] num_prescriptions, // Max 8 prescriptions (0-7)
  input [1:0] num_techs, // Max 4 technicians (0-3)
  // Prescription data (8 entries max)
  input [15:0] presc_drop_time [0:7], // Drop time in seconds (16-bit)
  input [7:0]  presc_type      [0:7], // 0='R', 1='S' (8-bit)
  input [8:0]  presc_fill_time [0:7], // Fill duration in seconds (9-bit)
  
  output reg [31:0] avg_s, // Avg S completion (Q16.16 fixed-point)
  output reg [31:0] avg_r, // Avg R completion (Q16.16 fixed-point)
  output reg done // High when computation completes
);

  // FSM state encoding
  localparam IDLE        = 2'd0;
  localparam PROCESSING  = 2'd1;
  localparam CALCULATING = 2'd2;
  localparam DONE        = 2'd3;

  reg [1:0] state, next_state;

  // Internal configuration registers
  reg [2:0] n_presc;   // 0-7 (max 8)
  reg [1:0] n_techs;   // 0-3 (max 4)

  // Local copies of prescription data for sorting and processing
  reg [15:0] drop_time [0:7];
  reg [7:0]  type_reg  [0:7];
  reg [8:0]  fill_time [0:7];

  // Scheduling and time tracking
  reg [15:0] current_time; // global time in seconds

  // For each technician: busy flag and remaining time
  reg        tech_busy [0:3];
  reg [15:0] tech_rem  [0:3];

  // To track assigned prescription index for each tech (if needed for debug/extension)
  reg [2:0] tech_presc_idx [0:3];

  // Track which prescriptions are completed and which are assigned
  reg        presc_done     [0:7];
  reg        presc_assigned [0:7];

  // Accumulators
  reg [31:0] total_s;
  reg [31:0] total_r;
  reg [3:0]  count_s; // up to 8
  reg [3:0]  count_r; // up to 8

  // Iteration indices
  integer i, j;

  // Sorting control
  reg [3:0] sort_i; // up to 7
  reg [3:0] sort_j; // up to 7

  // Flag to indicate sorting completed
  reg sort_done;

  // Division control
  reg [31:0] dividend;
  reg [15:0] divisor;
  reg [47:0] div_work;
  reg [15:0] div_bit;
  reg [31:0] div_quotient;
  reg        div_run;
  reg        div_sel_s; // 1: computing avg_s, 0: avg_r
  reg        div_pending_r; // whether we still need to do R after S

  // Utility function for comparison according to priority rules
  // Returns 1 if (a) should come after (b) (i.e., swap needed for ascending order)
  function automatic cmp_swap_needed(
    input [15:0] dt_a, input [7:0] ty_a, input [8:0] ft_a,
    input [15:0] dt_b, input [7:0] ty_b, input [8:0] ft_b
  );
    begin
      // Priority:
      // 1) Earlier drop_time first (ascending)
      // 2) For same drop_time: S(1) > R(0) => S first => descending by type
      // 3) For same drop_time and type: shorter fill_time first (ascending)
      if (dt_a > dt_b) begin
        cmp_swap_needed = 1'b1;
      end else if (dt_a < dt_b) begin
        cmp_swap_needed = 1'b0;
      end else begin
        // same drop_time
        if (ty_a < ty_b) begin
          // need S(1) before R(0) => if a.type < b.type, swap
          cmp_swap_needed = 1'b1;
        end else if (ty_a > ty_b) begin
          cmp_swap_needed = 1'b0;
        end else begin
          // same type, use shorter fill_time first
          if (ft_a > ft_b)
            cmp_swap_needed = 1'b1;
          else
            cmp_swap_needed = 1'b0;
        end
      end
    end
  endfunction

  // FSM sequential
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all
      avg_s       <= 32'd0;
      avg_r       <= 32'd0;
      done        <= 1'b0;
      n_presc     <= 3'd0;
      n_techs     <= 2'd0;
      current_time<= 16'd0;
      total_s     <= 32'd0;
      total_r     <= 32'd0;
      count_s     <= 4'd0;
      count_r     <= 4'd0;
      sort_i      <= 4'd0;
      sort_j      <= 4'd0;
      sort_done   <= 1'b0;
      div_run     <= 1'b0;
      div_sel_s   <= 1'b0;
      div_pending_r <= 1'b0;
      dividend    <= 32'd0;
      divisor     <= 16'd0;
      div_work    <= 48'd0;
      div_bit     <= 16'd0;
      div_quotient<= 32'd0;
      for (i = 0; i < 8; i = i + 1) begin
        drop_time[i]     <= 16'd0;
        type_reg[i]      <= 8'd0;
        fill_time[i]     <= 9'd0;
        presc_done[i]    <= 1'b0;
        presc_assigned[i]<= 1'b0;
      end
      for (i = 0; i < 4; i = i + 1) begin
        tech_busy[i]     <= 1'b0;
        tech_rem[i]      <= 16'd0;
        tech_presc_idx[i]<= 3'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          done  <= 1'b0;
          avg_s <= 32'd0;
          avg_r <= 32'd0;
          // Wait for start pulse
          if (start) begin
            // Latch configuration
            n_presc <= num_prescriptions;
            n_techs <= num_techs;

            // Copy inputs
            for (i = 0; i < 8; i = i + 1) begin
              drop_time[i]      <= presc_drop_time[i];
              type_reg[i]       <= presc_type[i];
              fill_time[i]      <= presc_fill_time[i];
              presc_done[i]     <= 1'b0;
              presc_assigned[i] <= 1'b0;
            end

            // Init technicians
            for (i = 0; i < 4; i = i + 1) begin
              tech_busy[i]      <= 1'b0;
              tech_rem[i]       <= 16'd0;
              tech_presc_idx[i] <= 3'd0;
            end

            // Init accumulators and time
            current_time <= 16'd0;
            total_s      <= 32'd0;
            total_r      <= 32'd0;
            count_s      <= 4'd0;
            count_r      <= 4'd0;

            // Init sort state
            sort_i    <= 4'd0;
            sort_j    <= 4'd0;
            sort_done <= 1'b0;

            // Clear division state
            div_run       <= 1'b0;
            div_sel_s     <= 1'b0;
            div_pending_r <= 1'b0;
            dividend      <= 32'd0;
            divisor       <= 16'd0;
            div_work      <= 48'd0;
            div_bit       <= 16'd0;
            div_quotient  <= 32'd0;
          end
        end

        PROCESSING: begin
          // Step 1: if sorting not done, perform bubble sort over multiple cycles
          if (!sort_done) begin
            // Bubble sort: one compare-swap per cycle
            if (n_presc <= 1) begin
              sort_done <= 1'b1;
            end else begin
              if (sort_i < n_presc) begin
                if (sort_j + 1 < n_presc - sort_i) begin
                  // Compare index j and j+1
                  if (cmp_swap_needed(
                        drop_time[sort_j], type_reg[sort_j], fill_time[sort_j],
                        drop_time[sort_j+1], type_reg[sort_j+1], fill_time[sort_j+1])) begin
                    // swap entries
                    reg [15:0] tmp_dt;
                    reg [7:0]  tmp_ty;
                    reg [8:0]  tmp_ft;
                    tmp_dt = drop_time[sort_j];
                    tmp_ty = type_reg[sort_j];
                    tmp_ft = fill_time[sort_j];
                    drop_time[sort_j]   = drop_time[sort_j+1];
                    type_reg[sort_j]    = type_reg[sort_j+1];
                    fill_time[sort_j]   = fill_time[sort_j+1];
                    drop_time[sort_j+1] = tmp_dt;
                    type_reg[sort_j+1]  = tmp_ty;
                    fill_time[sort_j+1] = tmp_ft;
                    // Preserve state arrays (presc_done/presc_assigned) aligned with sorted data reset
                    presc_done[sort_j]      <= 1'b0;
                    presc_done[sort_j+1]    <= 1'b0;
                    presc_assigned[sort_j]  <= 1'b0;
                    presc_assigned[sort_j+1]<= 1'b0;
                  end
                  sort_j <= sort_j + 1;
                end else begin
                  sort_j <= 4'd0;
                  sort_i <= sort_i + 1;
                end
              end else begin
                sort_done <= 1'b1;
              end
            end
          end else begin
            // After sort is complete, run discrete-event style scheduling each cycle:
            // 1) Assign ready prescriptions to free technicians.
            // 2) If none assigned and some busy, advance time to next completion.
            // 3) On completions, update totals.

            // Step 1: Attempt assignments based on current_time and tech free
            // We try to fill all free techs in priority order of sorted list.
            for (i = 0; i < n_techs; i = i + 1) begin
              if (!tech_busy[i]) begin
                // Find first unassigned, not-done prescription whose drop_time <= current_time
                integer k;
                reg found;
                found = 1'b0;
                for (k = 0; k < n_presc; k = k + 1) begin
                  if (!presc_done[k] && !presc_assigned[k] && (drop_time[k] <= current_time) && !found) begin
                    // Assign to this technician
                    tech_busy[i]       <= 1'b1;
                    tech_rem[i]        <= fill_time[k];
                    tech_presc_idx[i]  <= k[2:0];
                    presc_assigned[k]  <= 1'b1;
                    found = 1'b1;
                  end
                end
              end
            end

            // Step 2: Check if all prescriptions completed
            integer done_cnt;
            done_cnt = 0;
            for (i = 0; i < n_presc; i = i + 1) begin
              if (presc_done[i]) done_cnt = done_cnt + 1;
            end

            if (done_cnt == n_presc) begin
              // All done, move to CALCULATING
              // Next_state logic will transition; nothing more here
            end else begin
              // Not all done: if any tech busy, advance time to next event; else jump to next drop_time and assign
              // Determine minimal remaining time among busy techs
              reg any_busy;
              reg [15:0] min_rem;
              any_busy = 1'b0;
              min_rem  = 16'hFFFF;

              for (i = 0; i < n_techs; i = i + 1) begin
                if (tech_busy[i]) begin
                  any_busy = 1'b1;
                  if (tech_rem[i] < min_rem)
                    min_rem = tech_rem[i];
                end
              end

              // Determine earliest unassigned prescription drop_time > current_time
              reg has_future;
              reg [15:0] min_future_dt;
              has_future    = 1'b0;
              min_future_dt = 16'hFFFF;
              for (i = 0; i < n_presc; i = i + 1) begin
                if (!presc_done[i] && !presc_assigned[i] && (drop_time[i] > current_time)) begin
                  if (!has_future || drop_time[i] < min_future_dt) begin
                    has_future    = 1'b1;
                    min_future_dt = drop_time[i];
                  end
                end
              end

              if (any_busy) begin
                // We have active work; next event is min_rem completion
                // Advance time by min_rem
                current_time <= current_time + min_rem;

                // Update all busy technicians, mark completions
                for (i = 0; i < n_techs; i = i + 1) begin
                  if (tech_busy[i]) begin
                    if (tech_rem[i] == min_rem) begin
                      // This tech finishes now
                      tech_busy[i] <= 1'b0;
                      tech_rem[i]  <= 16'd0;
                      // Completion bookkeeping
                      integer idx;
                      reg [31:0] completion_time;
                      idx = tech_presc_idx[i];
                      presc_done[idx] <= 1'b1;
                      // completion_time = (start_processing_time + fill_time) - drop_time
                      // start_processing_time = current_time_before_advance
                      // But we don't track start time explicitly. Instead we can use:
                      // (finish_time - drop_time) where finish_time = new current_time (after advance).
                      completion_time = (current_time + min_rem) - drop_time[idx];
                      if (type_reg[idx] == 8'd1) begin
                        total_s <= total_s + completion_time;
                        count_s <= count_s + 1;
                      end else begin
                        total_r <= total_r + completion_time;
                        count_r <= count_r + 1;
                      end
                    end else begin
                      // Still busy; decrement remaining
                      tech_rem[i] <= tech_rem[i] - min_rem;
                    end
                  end
                end
              end else begin
                // No busy techs. Need to jump to next available drop_time if exists.
                if (has_future) begin
                  current_time <= min_future_dt;
                  // Assignments will occur in next cycle's assignment stage.
                end
              end
            end
          end
        end

        CALCULATING: begin
          // Sequential division to compute Q16.16 averages.
          // avg = (total_time << 16) / count
          if (!div_run) begin
            // Start with S if available, else R, else done
            if (count_s != 0) begin
              div_sel_s     <= 1'b1;
              div_pending_r <= (count_r != 0);
              dividend      <= total_s << 16;
              divisor       <= count_s;
              // Non-restoring/shift-subtract style integer division (32/16 -> 32)
              div_work      <= {16'd0, (total_s << 16)};
              div_bit       <= 1 << 15; // up to 16 bits for divisor alignment
              while ((divisor & (~div_bit)) != 0 && div_bit != 0) begin
                div_bit = div_bit >> 1;
              end
              div_quotient  <= 32'd0;
              div_run       <= 1'b1;
            end else if (count_r != 0) begin
              div_sel_s     <= 1'b0;
              div_pending_r <= 1'b0;
              dividend      <= total_r << 16;
              divisor       <= count_r;
              div_work      <= {16'd0, (total_r << 16)};
              div_bit       <= 1 << 15;
              while ((divisor & (~div_bit)) != 0 && div_bit != 0) begin
                div_bit = div_bit >> 1;
              end
              div_quotient  <= 32'd0;
              div_run       <= 1'b1;
            end else begin
              // No S and no R prescriptions
              avg_s <= 32'd0;
              avg_r <= 32'd0;
            end
          end else begin
            // Run iterative restoring division (one bit per cycle)
            if (div_bit != 0) begin
              // Align divisor with current bit, subtract if possible
              reg [47:0] sub_val;
              sub_val = (({32'd0, divisor}) << (div_bit - 1));
              if (div_work >= sub_val) begin
                div_work     <= div_work - sub_val;
                div_quotient <= div_quotient | (div_bit << 16); // scale to 32-bit range
              end
              div_bit <= div_bit >> 1;
            end else begin
              // Division complete for current type
              if (div_sel_s) begin
                avg_s <= div_quotient;
                if (div_pending_r) begin
                  // Start R division next
                  div_sel_s     <= 1'b0;
                  div_pending_r <= 1'b0;
                  dividend      <= total_r << 16;
                  divisor       <= count_r;
                  div_work      <= {16'd0, (total_r << 16)};
                  div_bit       <= 1 << 15;
                  while ((divisor & (~div_bit)) != 0 && div_bit != 0) begin
                    div_bit = div_bit >> 1;
                  end
                  div_quotient  <= 32'd0;
                  div_run       <= 1'b1;
                end else begin
                  div_run <= 1'b0;
                end
              end else begin
                avg_r  <= div_quotient;
                div_run<= 1'b0;
              end
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          // Hold results until next start or reset
        end

        default: begin
          // Should not occur
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
        end
      end

      PROCESSING: begin
        if (sort_done) begin
          // Check if all prescriptions completed
          integer dc;
          dc = 0;
          for (i = 0; i < n_presc; i = i + 1) begin
            if (presc_done[i]) dc = dc + 1;
          end
          if (dc == n_presc) begin
            next_state = CALCULATING;
          end else begin
            next_state = PROCESSING;
          end
        end else begin
          next_state = PROCESSING;
        end
      end

      CALCULATING: begin
        if (!div_run) begin
          // If no division needed (no counts) or completed
          next_state = DONE;
        end else begin
          next_state = CALCULATING;
        end
      end

      DONE: begin
        if (start) begin
          next_state = PROCESSING;
        end else if (!rst_n) begin
          next_state = IDLE;
        end else begin
          next_state = DONE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule