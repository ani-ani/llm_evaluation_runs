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

  // FSM states
  typedef enum logic [2:0] {IDLE=3'b000, COUNT_SAMPLES=3'b001, CHECK_CONDITION=3'b010, SORT_OUTPUT=3'b011, DONE=3'b100} state_t;
  state_t state_q, state_d;

  // Internal storage
  reg [3:0] n_reg, n_d;
  reg [7:0] first_n_mask_q, first_n_mask_d; // bits set for first n positions
  reg [3:0] count_occ_q [0:255]; // count of each value over first n elements (max occurrences of 8)
  reg [3:0] count_occ_d [0:255];
  reg [7:0] occ_mask_q [0:255];    // bitmask of positions where value occurs (in first n)
  reg [7:0] occ_mask_d [0:255];
  reg [7:0] adj1_mask_q [0:255];   // immediate neighbors in first-n window
  reg [7:0] adj1_mask_d [0:255];
  reg [7:0] d2_mask_q [0:255];     // distance-2 neighbors within first-n window
  reg [7:0] d2_mask_d [0:255];

  reg [7:0] valid_candidates_q, valid_candidates_d; // bitmask of values that are candidates

  reg [7:0] nums [0:7];   // values that are candidates
  reg [7:0] nums_next [0:7];
  reg [2:0] num_cnt_q, num_cnt_d;

  integer i, j, k, p;
  reg [7:0] val, pos;
  reg [7:0] cand, y;
  reg [3:0] cnt, cnt_y;
  reg [7:0] d2_x, d2_y;
  reg [7:0] sup_mask;
  reg superset, valid_for_y, unique_per_count;
  reg bubble_swap;

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= IDLE;
      n_reg <= 4'd0;
      first_n_mask_q <= 8'd0;
      num_cnt_q <= 3'd0;
      valid_candidates_q <= 8'd0;
      // Clear arrays
      for (i = 0; i < 256; i++) begin
        count_occ_q[i] <= 4'd0;
        occ_mask_q[i] <= 8'd0;
        adj1_mask_q[i] <= 8'd0;
        d2_mask_q[i] <= 8'd0;
      end
      for (i = 0; i < 8; i++) begin
        valid_numbers[i] <= 8'd0;
      end
      count <= 4'd0;
      done <= 1'b0;
    end else begin
      state_q <= state_d;
      n_reg <= n_d;
      first_n_mask_q <= first_n_mask_d;
      num_cnt_q <= num_cnt_d;
      valid_candidates_q <= valid_candidates_d;
      for (i = 0; i < 256; i++) begin
        count_occ_q[i] <= count_occ_d[i];
        occ_mask_q[i] <= occ_mask_d[i];
        adj1_mask_q[i] <= adj1_mask_d[i];
        d2_mask_q[i] <= d2_mask_d[i];
      end
      for (i = 0; i < 8; i++) begin
        nums[i] <= nums_next[i];
        valid_numbers[i] <= 8'd0; // registered output storage
      end
      count <= num_cnt_d; // registered output
      done <= (state_d == DONE); // registered output
    end
  end

  // Combinational next-state and datapath
  always_comb begin
    // Defaults
    state_d = state_q;
    n_d = n_reg;
    first_n_mask_d = first_n_mask_q;
    num_cnt_d = num_cnt_q;
    valid_candidates_d = valid_candidates_q;

    for (i = 0; i < 256; i++) begin
      count_occ_d[i] = count_occ_q[i];
      occ_mask_d[i] = occ_mask_q[i];
      adj1_mask_d[i] = adj1_mask_q[i];
      d2_mask_d[i] = d2_mask_q[i];
    end

    for (i = 0; i < 8; i++) begin
      nums_next[i] = nums[i];
    end

    unique_per_count = 1'b1;

    case (state_q)
      IDLE: begin
        // Clear outputs
        first_n_mask_d = 8'd0;
        valid_candidates_d = 8'd0;
        num_cnt_d = 3'd0;
        for (i = 0; i < 256; i++) begin
          count_occ_d[i] = 4'd0;
          occ_mask_d[i] = 8'd0;
          adj1_mask_d[i] = 8'd0;
          d2_mask_d[i] = 8'd0;
        end
        for (i = 0; i < 8; i++) begin
          nums_next[i] = 8'd0;
        end
        if (start) begin
          n_d = (|n) ? n : 4'd0; // latch n
          state_d = COUNT_SAMPLES;
        end else begin
          state_d = IDLE;
        end
      end

      COUNT_SAMPLES: begin
        // Build masks and statistics for first n elements (circular)
        first_n_mask_d = (n_reg == 4'd0) ? 8'd0 : (8'b1 << n_reg) - 8'b1;
        for (i = 0; i < 256; i++) begin
          count_occ_d[i] = 4'd0;
          occ_mask_d[i] = 8'd0;
          adj1_mask_d[i] = 8'd0;
          d2_mask_d[i] = 8'd0;
        end
        if (n_reg == 4'd0) begin
          valid_candidates_d = 8'd0;
          num_cnt_d = 3'd0;
          state_d = DONE;
        end else begin
          for (i = 0; i < n_reg; i++) begin
            pos = i[2:0]; // 0..7
            val = array[pos];
            count_occ_d[val] = count_occ_q[val] + 1;
            occ_mask_d[val] = occ_mask_q[val] | (8'b1 << pos);
            // Immediate neighbor: pos-1 (circular)
            adj1_mask_d[val] = adj1_mask_q[val] | (8'b1 << ((pos + 7) & 3'b111));
            // Distance-2 neighbors will be added after all positions are known to avoid duplicates
          end
          // Add distance-2 neighbors
          for (i = 0; i < n_reg; i++) begin
            pos = i[2:0];
            val = array[pos];
            d2_mask_d[val] = d2_mask_q[val] | (8'b1 << ((pos + 6) & 3'b111)) | (8'b1 << ((pos + 1) & 3'b111));
          end
          state_d = CHECK_CONDITION;
        end
      end

      CHECK_CONDITION: begin
        valid_candidates_d = 8'd0;
        num_cnt_d = 3'd0;
        // Find candidates: for each X, all Y must have the same set of X as only superset
        for (i = 0; i < 256; i++) begin
          cnt = count_occ_q[i];
          if (cnt == 4'd0) begin
            // Not present in first n; not a candidate
          end else begin
            d2_x = d2_mask_q[i];
            valid_for_y = 1'b1;
            // Check every Y (0..255)
            for (j = 0; j < 256; j++) begin
              cnt_y = count_occ_q[j];
              if (cnt_y == 4'd0) continue; // Y not present => condition vacuously true
              d2_y = d2_mask_q[j];
              sup_mask = 8'd0;
              for (k = 0; k < 256; k++) begin
                if (count_occ_q[k] == 4'd0) continue;
                if (count_occ_q[k] == cnt_y) begin
                  if ((d2_mask_q[k] & d2_y) == d2_y) begin
                    sup_mask[k] = 1'b1;
                  end
                end
              end
              // Exactly one candidate for this Y
              if ($countones(sup_mask) != 1) begin
                valid_for_y = 1'b0;
                break;
              end
            end
            if (valid_for_y) begin
              valid_candidates_d[i] = 1'b1;
            end
          end
        end
        // Prepare nums array for sorting and check uniqueness per count group
        num_cnt_d = 3'd0;
        unique_per_count = 1'b1;
        for (i = 0; i < 256; i++) begin
          if (valid_candidates_d[i]) begin
            nums_next[num_cnt_d] = i[7:0];
            num_cnt_d = num_cnt_d + 1;
          end
        end
        // For every count present among candidates, ensure exactly one candidate has that count
        for (i = 0; i < 256; i++) begin
          if (valid_candidates_d[i]) begin
            cnt = count_occ_q[i];
            // Count how many candidates share this cnt
            for (j = i + 1; j < 256; j++) begin
              if (valid_candidates_d[j] && (count_occ_q[j] == cnt)) begin
                unique_per_count = 1'b0;
                break;
              end
            end
            if (!unique_per_count) break;
          end
        end
        if (!unique_per_count) begin
          valid_candidates_d = 8'd0;
          num_cnt_d = 3'd0;
        end
        state_d = SORT_OUTPUT;
      end

      SORT_OUTPUT: begin
        // Bubble sort nums_next[0..num_cnt_q-1] in ascending order
        for (i = 0; i < 8; i++) begin
          nums_next[i] = nums[i];
        end
        for (i = 0; i < 7; i++) begin
          bubble_swap = 1'b0;
          for (j = 0; j < (7 - i); j++) begin
            if (nums[j] > nums[j+1]) begin
              val = nums[j];
              nums_next[j] = nums[j+1];
              nums_next[j+1] = val;
              bubble_swap = 1'b1;
            end else begin
              nums_next[j] = nums[j];
              nums_next[j+1] = nums[j+1];
            end
          end
          if (!bubble_swap) begin
            for (k = 0; k < 8; k++) nums_next[k] = nums[k];
            break;
          end
        end
        state_d = DONE;
      end

      DONE: begin
        // Hold results until next start
        state_d = start ? DONE : IDLE;
      end

      default: state_d = IDLE;
    endcase
  end

  // Registered outputs: valid_numbers, count, done are updated in the always_ff block
endmodule
