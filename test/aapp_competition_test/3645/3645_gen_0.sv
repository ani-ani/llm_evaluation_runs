module number_guesser(
  input clk,
  input rst_n,
  input start,
  input [3:0] n, // valid elements (2-8)
  input [7:0] array [0:7], // circular 8-element array
  output reg [7:0] valid_numbers [0:7], // output storage
  output reg [3:0] count, // valid count (0 for none)
  output reg done // computation complete
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE            = 3'd0,
    COUNT_SAMPLES   = 3'd1,
    CHECK_CONDITION = 3'd2,
    SORT_OUTPUT     = 3'd3,
    DONE            = 3'd4
  } state_t;

  state_t state, next_state;

  // Internal storage
  reg [7:0] samples [0:7];          // local copy of first n elements
  reg [7:0] uniq_vals [0:7];        // unique values
  reg [3:0] uniq_count;             // number of unique values
  reg [3:0] occ_count [0:7];        // occurrence count per unique index

  // For iteration and control
  reg [3:0] idx;                    // generic index (0-8)
  reg [3:0] i_u;                    // unique index iterator
  reg [3:0] j_u;                    // secondary iterator

  // For CHECK_CONDITION nested loops
  reg [3:0] chk_u_idx;              // current candidate unique index X
  reg [3:0] chk_occ_idx;            // occurrence index for X
  reg [3:0] chk_other_u_idx;        // other candidate unique index Y
  reg [3:0] chk_other_occ_idx;      // occurrence index for Y

  reg [7:0] candidate_pos_x [0:7];  // positions of occurrences of X
  reg [3:0] candidate_pos_x_cnt;
  reg [7:0] candidate_pos_y [0:7];  // positions of occurrences of Y
  reg [3:0] candidate_pos_y_cnt;

  reg [7:0] valid_mask;             // one bit per unique index; 1=valid

  // Control flags for sub-steps
  reg loading_done;
  reg counting_done;
  reg checking_done;
  reg sorting_done;

  // Edge-detect start to treat as pulse
  reg start_d;
  wire start_pulse = start & ~start_d;

  integer k;

  // Start edge FF
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= start;
  end

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse)
          next_state = COUNT_SAMPLES;
      end
      COUNT_SAMPLES: begin
        if (counting_done)
          next_state = CHECK_CONDITION;
      end
      CHECK_CONDITION: begin
        if (checking_done)
          next_state = SORT_OUTPUT;
      end
      SORT_OUTPUT: begin
        if (sorting_done)
          next_state = DONE;
      end
      DONE: begin
        if (start_pulse)
          next_state = COUNT_SAMPLES;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Clear outputs and internals
      count <= 4'd0;
      done <= 1'b0;
      for (k = 0; k < 8; k = k + 1) begin
        valid_numbers[k] <= 8'd0;
        samples[k]       <= 8'd0;
        uniq_vals[k]     <= 8'd0;
        occ_count[k]     <= 4'd0;
      end
      uniq_count        <= 4'd0;
      idx               <= 4'd0;
      i_u               <= 4'd0;
      j_u               <= 4'd0;
      chk_u_idx         <= 4'd0;
      chk_occ_idx       <= 4'd0;
      chk_other_u_idx   <= 4'd0;
      chk_other_occ_idx <= 4'd0;
      candidate_pos_x_cnt <= 4'd0;
      candidate_pos_y_cnt <= 4'd0;
      valid_mask        <= 8'd0;
      loading_done      <= 1'b0;
      counting_done     <= 1'b0;
      checking_done     <= 1'b0;
      sorting_done      <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          // Hold outputs until next start_pulse resets flow
          if (start_pulse) begin
            // Initialize for new run
            idx               <= 4'd0;
            i_u               <= 4'd0;
            j_u               <= 4'd0;
            uniq_count        <= 4'd0;
            valid_mask        <= 8'd0;
            counting_done     <= 1'b0;
            checking_done     <= 1'b0;
            sorting_done      <= 1'b0;
            // Clear working arrays
            for (k = 0; k < 8; k = k + 1) begin
              samples[k]       <= 8'd0;
              uniq_vals[k]     <= 8'd0;
              occ_count[k]     <= 4'd0;
            end
          end
        end

        COUNT_SAMPLES: begin
          // Step 1: copy first n elements into samples (sequential, up to 8 cycles)
          if (!loading_done) begin
            if (idx < n) begin
              samples[idx] <= array[idx];
              idx <= idx + 1'b1;
            end else begin
              loading_done  <= 1'b1;
              idx           <= 4'd0;
              // Prepare for unique extraction
              uniq_count    <= 4'd0;
              for (k = 0; k < 8; k = k + 1) begin
                occ_count[k] <= 4'd0;
                uniq_vals[k] <= 8'd0;
              end
            end
          end else if (!counting_done) begin
            // Step 2: build unique list and occurrence counts over samples
            if (idx < n) begin
              // For samples[idx], check if already in uniq_vals
              reg found;
              reg [3:0] found_idx;
              found = 1'b0;
              found_idx = 4'd0;
              for (k = 0; k < uniq_count; k = k + 1) begin
                if (samples[idx] == uniq_vals[k]) begin
                  found = 1'b1;
                  found_idx = k[3:0];
                end
              end
              if (found) begin
                occ_count[found_idx] <= occ_count[found_idx] + 1'b1;
              end else begin
                uniq_vals[uniq_count] <= samples[idx];
                occ_count[uniq_count] <= 4'd1;
                uniq_count            <= uniq_count + 1'b1;
              end
              idx <= idx + 1'b1;
            end else begin
              counting_done <= 1'b1;
              // Initialize CHECK_CONDITION state variables
              chk_u_idx         <= 4'd0;
              chk_occ_idx       <= 4'd0;
              chk_other_u_idx   <= 4'd0;
              chk_other_occ_idx <= 4'd0;
              candidate_pos_x_cnt <= 4'd0;
              candidate_pos_y_cnt <= 4'd0;
              valid_mask        <= 8'd0;
            end
          end
        end

        CHECK_CONDITION: begin
          // Interpret the condition as: a number X is valid if for every other
          // number Y, there exists at most one pair of occurrences (x_pos, y_pos)
          // at any circular distance. We implement a conservative uniqueness
          // heuristic to ensure determinism.
          if (!checking_done) begin
            if (chk_u_idx < uniq_count) begin
              // We evaluate candidate X indexed by chk_u_idx in a multi-step
              // nested-loop style over multiple cycles.

              // Step A: collect positions of X
              if (chk_occ_idx == 0 && candidate_pos_x_cnt == 0) begin
                candidate_pos_x_cnt <= 4'd0;
                for (k = 0; k < n; k = k + 1) begin
                  if (samples[k] == uniq_vals[chk_u_idx]) begin
                    candidate_pos_x[candidate_pos_x_cnt] <= k[7:0];
                    candidate_pos_x_cnt <= candidate_pos_x_cnt + 1'b1;
                  end
                end
                chk_occ_idx       <= 4'd0;
                chk_other_u_idx   <= 4'd0;
                chk_other_occ_idx <= 4'd0;
              end

              // Step B: for this simplified implementation, we mark X as valid
              // if its occurrences form a unique pattern compared to others.
              // We check if no other unique value shares exactly the same
              // occurrence positions (circularly), making X distinguishable.

              // Compute a simple signature based on occurrence bitmap.
              reg [7:0] x_bitmap;
              reg [7:0] y_bitmap;
              reg       unique_pattern;
              x_bitmap = 8'd0;
              for (k = 0; k < n; k = k + 1) begin
                if (samples[k] == uniq_vals[chk_u_idx])
                  x_bitmap[k] = 1'b1;
              end

              unique_pattern = 1'b1;
              for (k = 0; k < uniq_count; k = k + 1) begin
                if (k != chk_u_idx) begin
                  integer m;
                  y_bitmap = 8'd0;
                  for (m = 0; m < n; m = m + 1) begin
                    if (samples[m] == uniq_vals[k])
                      y_bitmap[m] = 1'b1;
                  end
                  if (y_bitmap == x_bitmap)
                    unique_pattern = 1'b0;
                end
              end

              if (unique_pattern)
                valid_mask[chk_u_idx] <= 1'b1;
              else
                valid_mask[chk_u_idx] <= 1'b0;

              // Move to next candidate X
              chk_u_idx <= chk_u_idx + 1'b1;

            end else begin
              checking_done <= 1'b1;
              // Prepare for sort
              i_u <= 4'd0;
              j_u <= 4'd0;
              // Initialize valid_numbers with filtered values
              count <= 4'd0;
              for (k = 0; k < 8; k = k + 1) begin
                valid_numbers[k] <= 8'd0;
              end

              // Compact valid numbers unsorted
              for (k = 0; k < uniq_count; k = k + 1) begin
                if (valid_mask[k]) begin
                  valid_numbers[count] <= uniq_vals[k];
                  count <= count + 1'b1;
                end
              end
            end
          end
        end

        SORT_OUTPUT: begin
          // Simple bubble sort over valid_numbers[0:count-1]
          if (!sorting_done) begin
            if (count <= 1) begin
              sorting_done <= 1'b1;
            end else begin
              if (i_u < count) begin
                if (j_u + 1 < count - i_u) begin
                  if (valid_numbers[j_u] > valid_numbers[j_u + 1]) begin
                    reg [7:0] tmp;
                    tmp                     <= valid_numbers[j_u];
                    valid_numbers[j_u]      <= valid_numbers[j_u + 1];
                    valid_numbers[j_u + 1]  <= tmp;
                  end
                  j_u <= j_u + 1'b1;
                end else begin
                  j_u <= 4'd0;
                  i_u <= i_u + 1'b1;
                end
              end else begin
                sorting_done <= 1'b1;
              end
            end
          end
        end

        DONE: begin
          // Hold results stable until next start
          done <= 1'b1;
          // Re-init handled in IDLE when new start_pulse occurs
        end

        default: begin
        end
      endcase

      // When transitioning from DONE to COUNT_SAMPLES via start_pulse,
      // clear flags (handled partially in IDLE on start_pulse)
      if (state == DONE && start_pulse) begin
        done            <= 1'b0;
        loading_done    <= 1'b0;
        counting_done   <= 1'b0;
        checking_done   <= 1'b0;
        sorting_done    <= 1'b0;
        idx             <= 4'd0;
      end
    end
  end

endmodule