module courier_partition_optimizer(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] x [0:7],
  input  [3:0] y [0:7],
  input  [2:0] num_customers,
  output reg [4:0] min_max_time,
  output reg       done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE           = 2'b00,
    CALC_DIST      = 2'b01,
    EVAL_PARTITIONS= 2'b10,
    DONE_STATE     = 2'b11
  } state_t;

  state_t state, next_state;

  // Precomputed pair index to (i,j) mapping (for 8 customers max: 28 pairs)
  // pair indices: 0..27
  // We store i,j as 3-bit each
  reg [2:0] pi_i [0:27];
  reg [2:0] pi_j [0:27];

  // Distance storage: 5-bit (0..30) for each pair
  reg [4:0] dist [0:27];

  // Counters and registers
  reg [5:0] pair_idx;           // 0..27 (needs 5 bits, use 6 for safety)
  reg [7:0] partition;          // partition bitmask
  reg [7:0] max_mask;           // mask for existing customers (lower N bits set)
  reg [7:0] part_count;         // counter from 1 to max_mask-1

  reg [4:0] best_value;         // global best (min over partitions of smaller max)

  // For partition evaluation
  reg [2:0] cu_i, cu_j;         // current pair indices i,j
  reg [4:0] d_cur;              // current distance
  reg [4:0] maxA, maxB;         // max intra-group distances for groups A and B
  reg       pair_valid;         // indicates if current pair is valid (both in set)

  // Evaluate loop over all 28 pairs for each partition
  reg [5:0] eval_pair_idx;      // 0..27

  // Helper wires
  wire [2:0] N = num_customers; // 3..8

  // Manhattan distance computation helper (combinational)
  function automatic [4:0] manhattan_dist(
    input [3:0] x1,
    input [3:0] y1,
    input [3:0] x2,
    input [3:0] y2
  );
    reg [4:0] dx, dy;
    begin
      if (x1 >= x2) dx = x1 - x2; else dx = x2 - x1;
      if (y1 >= y2) dy = y1 - y2; else dy = y2 - y1;
      manhattan_dist = dx + dy;
    end
  endfunction

  // Combinational: generate max_mask based on num_customers (lower N bits = 1)
  always @* begin
    case (N)
      3'd0: max_mask = 8'b0000_0000;
      3'd1: max_mask = 8'b0000_0001;
      3'd2: max_mask = 8'b0000_0011;
      3'd3: max_mask = 8'b0000_0111;
      3'd4: max_mask = 8'b0000_1111;
      3'd5: max_mask = 8'b0001_1111;
      3'd6: max_mask = 8'b0011_1111;
      3'd7: max_mask = 8'b0111_1111;
      default: max_mask = 8'b1111_1111; // N=8
    endcase
  end

  // Pre-load pair index mapping (constant) using initial block
  // (Synthesizable for ASIC when treated as constant ROM)
  initial begin
    // (i,j) pairs for i<j, i,j in 0..7 in lexicographic order
    // 0: (0,1)
    pi_i[0] = 3'd0; pi_j[0] = 3'd1;
    // 1: (0,2)
    pi_i[1] = 3'd0; pi_j[1] = 3'd2;
    // 2: (0,3)
    pi_i[2] = 3'd0; pi_j[2] = 3'd3;
    // 3: (0,4)
    pi_i[3] = 3'd0; pi_j[3] = 3'd4;
    // 4: (0,5)
    pi_i[4] = 3'd0; pi_j[4] = 3'd5;
    // 5: (0,6)
    pi_i[5] = 3'd0; pi_j[5] = 3'd6;
    // 6: (0,7)
    pi_i[6] = 3'd0; pi_j[6] = 3'd7;

    // 7: (1,2)
    pi_i[7] = 3'd1; pi_j[7] = 3'd2;
    // 8: (1,3)
    pi_i[8] = 3'd1; pi_j[8] = 3'd3;
    // 9: (1,4)
    pi_i[9] = 3'd1; pi_j[9] = 3'd4;
    // 10: (1,5)
    pi_i[10] = 3'd1; pi_j[10] = 3'd5;
    // 11: (1,6)
    pi_i[11] = 3'd1; pi_j[11] = 3'd6;
    // 12: (1,7)
    pi_i[12] = 3'd1; pi_j[12] = 3'd7;

    // 13: (2,3)
    pi_i[13] = 3'd2; pi_j[13] = 3'd3;
    // 14: (2,4)
    pi_i[14] = 3'd2; pi_j[14] = 3'd4;
    // 15: (2,5)
    pi_i[15] = 3'd2; pi_j[15] = 3'd5;
    // 16: (2,6)
    pi_i[16] = 3'd2; pi_j[16] = 3'd6;
    // 17: (2,7)
    pi_i[17] = 3'd2; pi_j[17] = 3'd7;

    // 18: (3,4)
    pi_i[18] = 3'd3; pi_j[18] = 3'd4;
    // 19: (3,5)
    pi_i[19] = 3'd3; pi_j[19] = 3'd5;
    // 20: (3,6)
    pi_i[20] = 3'd3; pi_j[20] = 3'd6;
    // 21: (3,7)
    pi_i[21] = 3'd3; pi_j[21] = 3'd7;

    // 22: (4,5)
    pi_i[22] = 3'd4; pi_j[22] = 3'd5;
    // 23: (4,6)
    pi_i[23] = 3'd4; pi_j[23] = 3'd6;
    // 24: (4,7)
    pi_i[24] = 3'd4; pi_j[24] = 3'd7;

    // 25: (5,6)
    pi_i[25] = 3'd5; pi_j[25] = 3'd6;
    // 26: (5,7)
    pi_i[26] = 3'd5; pi_j[26] = 3'd7;

    // 27: (6,7)
    pi_i[27] = 3'd6; pi_j[27] = 3'd7;
  end

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CALC_DIST;
      end

      CALC_DIST: begin
        if (pair_idx == 6'd27)
          next_state = EVAL_PARTITIONS;
      end

      EVAL_PARTITIONS: begin
        // When all partitions done, go DONE
        // Last valid partition is (max_mask-1), we treat both 0 and max_mask as invalid
        if (part_count == max_mask - 1 && eval_pair_idx == 6'd27)
          next_state = DONE_STATE;
      end

      DONE_STATE: begin
        // Wait for start to be deasserted then next start
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Main sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pair_idx      <= 6'd0;
      part_count    <= 8'd0;
      partition     <= 8'd0;
      eval_pair_idx <= 6'd0;
      best_value    <= 5'h1F; // max 31
      min_max_time  <= 5'd0;
      done          <= 1'b0;
      maxA          <= 5'd0;
      maxB          <= 5'd0;
    end else begin
      done <= 1'b0;

      case (state)
        IDLE: begin
          // Prepare for new run on start
          if (start) begin
            pair_idx      <= 6'd0;
            best_value    <= 5'h1F; // large initial value
            part_count    <= 8'd1;  // start from 1
            eval_pair_idx <= 6'd0;
            maxA          <= 5'd0;
            maxB          <= 5'd0;
          end
        end

        CALC_DIST: begin
          // Only compute for pairs where both indices < N
          cu_i  = pi_i[pair_idx];
          cu_j  = pi_j[pair_idx];
          if (cu_i < N && cu_j < N)
            dist[pair_idx] <= manhattan_dist(x[cu_i], y[cu_i], x[cu_j], y[cu_j]);
          else
            dist[pair_idx] <= 5'd0;

          if (pair_idx == 6'd27)
            pair_idx <= 6'd27; // hold; next_state will move on
          else
            pair_idx <= pair_idx + 6'd1;

          // Initialize partition-related registers when transitioning (implicitly next cycle)
          if (pair_idx == 6'd27) begin
            part_count    <= 8'd1;
            eval_pair_idx <= 6'd0;
            maxA          <= 5'd0;
            maxB          <= 5'd0;
          end
        end

        EVAL_PARTITIONS: begin
          // Skip invalid partitions: 0 and max_mask
          if (eval_pair_idx == 6'd0) begin
            // On first cycle of a new partition load its mask
            partition = part_count & max_mask;
            // Skip if all-zero or all-one (no valid split): advance part_count
            if (partition == 8'd0 || partition == max_mask) begin
              if (part_count == max_mask - 1) begin
                // will exit in next_state when eval_pair_idx==27; ensure eval_pair_idx set
                eval_pair_idx <= 6'd27;
              end else begin
                part_count    <= part_count + 8'd1;
                eval_pair_idx <= 6'd0;
              end
              maxA <= 5'd0;
              maxB <= 5'd0;
            end else begin
              // Valid partition: initialize per-partition maxima
              maxA <= 5'd0;
              maxB <= 5'd0;
              eval_pair_idx <= 6'd1; // start evaluating from pair 0 in next block below
            end
          end else begin
            // Evaluate pairs for current valid partition
            cu_i = pi_i[eval_pair_idx - 6'd1];
            cu_j = pi_j[eval_pair_idx - 6'd1];

            // Only consider pairs within existing customers (< N)
            if (cu_i < N && cu_j < N) begin
              pair_valid = 1'b0;
              // Check membership in groups based on partition bits
              if (partition[cu_i] && partition[cu_j]) begin
                // Both in group A
                pair_valid = 1'b1;
                d_cur = dist[eval_pair_idx - 6'd1];
                if (d_cur > maxA) maxA <= d_cur;
              end else if (!partition[cu_i] && !partition[cu_j]) begin
                // Both in group B
                pair_valid = 1'b1;
                d_cur = dist[eval_pair_idx - 6'd1];
                if (d_cur > maxB) maxB <= d_cur;
              end
            end

            // Move to next pair
            if (eval_pair_idx == 6'd28) begin
              // All 28 pairs processed for this partition
              // Compute smaller of maxA, maxB and update best_value
              if (maxA < maxB) d_cur = maxA; else d_cur = maxB;
              if (d_cur < best_value) best_value <= d_cur;

              // Advance to next partition
              if (part_count == max_mask - 1) begin
                // Last partition, stay; next_state will go DONE
                part_count    <= part_count;
                eval_pair_idx <= 6'd27; // keep stable
              end else begin
                part_count    <= part_count + 8'd1;
                eval_pair_idx <= 6'd0; // will trigger loading new partition
              end
            end else begin
              eval_pair_idx <= eval_pair_idx + 6'd1;
            end
          end
        end

        DONE_STATE: begin
          done         <= 1'b1;
          min_max_time <= best_value;
          // Wait for next start pulse (handled in next_state/IDLE)
        end

        default: ;
      endcase
    end
  end

endmodule