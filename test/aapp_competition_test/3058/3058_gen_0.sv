module evolution_validator(
  input clk,
  input rst_n,
  input start,
  input [15:0] current_seq,
  input [7:0][15:0] fossil_seqs,
  input [3:0] num_fossils,
  output reg possible,
  output reg [3:0] s1,
  output reg [3:0] s2,
  output reg [7:0] path1_mask,
  output reg [7:0] path2_mask,
  output reg done
);

  // ------------------------------------------------------------
  // Internal encodings and parameters
  // ------------------------------------------------------------
  localparam MAX_FOSSILS = 8;
  localparam SEQ_BITS    = 16; // 8 chars * 2 bits

  // State machine encoding
  typedef enum logic [2:0] {
    ST_IDLE   = 3'd0,
    ST_BUILD  = 3'd1,
    ST_ENUM   = 3'd2,
    ST_CHECK  = 3'd3,
    ST_DONE   = 3'd4
  } state_t;

  state_t state, next_state;

  // Register to hold sorted fossil indices by length (descending for chain building)
  // and their lengths.
  reg [2:0] lengths   [0:MAX_FOSSILS-1];
  reg [2:0] sorted_idx[0:MAX_FOSSILS-1];

  // Parent-child adjacency: parent_of[j][i] = 1 if fossil j can be parent of fossil i
  // (i.e., seq_i can be formed from seq_j by inserting one char);
  // plus edges from fossils to current_seq.
  reg parent_of [0:MAX_FOSSILS-1][0:MAX_FOSSILS-1];
  reg parent_to_curr[0:MAX_FOSSILS-1];

  // Pre-calculated candidate flags: valid fossils (length <= current_seq length)
  reg valid_fossil[0:MAX_FOSSILS-1];

  // Enumeration variables for subset partitioning
  reg [7:0] subset;        // current subset for path1
  reg [7:0] best_p1_mask;  // best path1 found so far
  reg [7:0] best_p2_mask;  // best path2 found so far
  reg [3:0] best_s1;
  reg [3:0] best_s2;
  reg found_any;

  // Counters / indices
  reg [7:0] enum_counter;  // up to 255 -> covers all subsets of 8 fossils
  reg [3:0] i_idx;
  reg [3:0] j_idx;

  // Temporary registers used in BUILD and CHECK phases
  reg [15:0] seq_i, seq_j;
  reg [2:0] len_i, len_j;

  // Function: compute length (0..8) from 16-bit, where '00' is considered empty and
  // sequence is prefix-terminated by first '00' pair or max 8 chars.
  function automatic [2:0] seq_length(input [15:0] seq);
    integer k;
    begin
      seq_length = 3'd0;
      for (k = 0; k < 8; k = k + 1) begin
        if (seq[(2*k)+:2] != 2'b00)
          seq_length = seq_length + 3'd1;
        else
          disable for;
      end
    end
  endfunction

  // Function: check if child can be obtained from parent by inserting exactly one char.
  // Both sequences encoded as 2-bit chars, 8 chars max, prefix-terminated by 00.
  function automatic is_insert_parent(
    input [15:0] parent,
    input [2:0]  len_p,
    input [15:0] child,
    input [2:0]  len_c
  );
    integer ip, ic;
    reg diff_used;
    begin
      if (len_c != (len_p + 3'd1)) begin
        is_insert_parent = 1'b0;
      end else begin
        ip = 0;
        ic = 0;
        diff_used = 1'b0;
        is_insert_parent = 1'b1;
        while (ip < len_p && is_insert_parent) begin
          if (ic >= len_c) begin
            is_insert_parent = 1'b0;
          end else if (parent[(2*ip)+:2] == child[(2*ic)+:2]) begin
            ip = ip + 1;
            ic = ic + 1;
          end else if (!diff_used) begin
            // Skip one char in child as the inserted char
            diff_used = 1'b1;
            ic = ic + 1;
          end else begin
            is_insert_parent = 1'b0;
          end
        end
        if (is_insert_parent) begin
          // After matching all parent chars, we may have at most one extra child char
          if (!diff_used) begin
            if ((ic + 1) != len_c)
              is_insert_parent = 1'b0;
          end else begin
            if (ic != len_c)
              is_insert_parent = 1'b0;
          end
        end
      end
    end
  endfunction

  // Function: get max chain length ending at current_seq using fossils in mask.
  // Uses parent_of and parent_to_curr relations.
  function automatic [3:0] max_chain_len(
    input [7:0] mask
  );
    reg [3:0] dp[0:MAX_FOSSILS-1];
    integer i, j;
    reg [3:0] best;
    begin
      // Initialize dp for fossils in mask
      for (i = 0; i < MAX_FOSSILS; i = i + 1) begin
        if (mask[i] && valid_fossil[i])
          dp[i] = 4'd1; // each fossil alone
        else
          dp[i] = 4'd0;
      end

      // Relax in order of increasing length
      // Simple O(N^2) since N<=8
      for (i = 0; i < MAX_FOSSILS; i = i + 1) begin
        if (mask[i] && valid_fossil[i]) begin
          for (j = 0; j < MAX_FOSSILS; j = j + 1) begin
            if (mask[j] && valid_fossil[j]) begin
              if (parent_of[j][i] && dp[j] != 4'd0) begin
                if (dp[j] + 4'd1 > dp[i])
                  dp[i] = dp[j] + 4'd1;
              end
            end
          end
        end
      end

      // Find best chain that can connect to current_seq
      best = 4'd0;
      for (i = 0; i < MAX_FOSSILS; i = i + 1) begin
        if (mask[i] && valid_fossil[i] && parent_to_curr[i] && dp[i] > 0) begin
          if (dp[i] > best)
            best = dp[i];
        end
      end
      max_chain_len = best;
    end
  endfunction

  // ------------------------------------------------------------
  // Sequential logic: state, control, and computations
  // ------------------------------------------------------------

  // Asynchronous active-low reset and state update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= ST_IDLE;
      possible    <= 1'b0;
      done        <= 1'b0;
      s1          <= 4'd0;
      s2          <= 4'd0;
      path1_mask  <= 8'd0;
      path2_mask  <= 8'd0;
      best_p1_mask<= 8'd0;
      best_p2_mask<= 8'd0;
      best_s1     <= 4'd0;
      best_s2     <= 4'd0;
      found_any   <= 1'b0;
      enum_counter<= 8'd0;
      i_idx       <= 4'd0;
      j_idx       <= 4'd0;
    end else begin
      state <= next_state;

      case (state)
        ST_IDLE: begin
          done       <= 1'b0;
          possible   <= 1'b0;
          if (start) begin
            // Initialize for BUILD
            i_idx        <= 4'd0;
            j_idx        <= 4'd0;
            found_any    <= 1'b0;
            best_p1_mask <= 8'd0;
            best_p2_mask <= 8'd0;
            best_s1      <= 4'd0;
            best_s2      <= 4'd0;

            // Precompute lengths and validity
            for (int k = 0; k < MAX_FOSSILS; k = k + 1) begin
              if (k < num_fossils) begin
                lengths[k]      <= seq_length(fossil_seqs[k]);
                valid_fossil[k] <= (seq_length(fossil_seqs[k]) <= seq_length(current_seq));
              end else begin
                lengths[k]      <= 3'd0;
                valid_fossil[k] <= 1'b0;
              end
            end
          end
        end

        ST_BUILD: begin
          // Build parent_of and parent_to_curr over multiple cycles
          // We iterate i_idx,j_idx pairs to fill adjacency.
          // Use nested-like iteration across cycles.

          // Default: no changes unless within bounds
          if (i_idx < num_fossils && j_idx < num_fossils) begin
            seq_i <= fossil_seqs[i_idx];
            seq_j <= fossil_seqs[j_idx];
            len_i <= lengths[i_idx];
            len_j <= lengths[j_idx];

            // Clear once at start of BUILD (i_idx==0 && j_idx==0)
            if (i_idx == 0 && j_idx == 0) begin
              for (int a = 0; a < MAX_FOSSILS; a = a + 1) begin
                parent_to_curr[a] <= 1'b0;
                for (int b = 0; b < MAX_FOSSILS; b = b + 1) begin
                  parent_of[a][b] <= 1'b0;
                end
              end
            end

            // Compute parent_of relation: j -> i if len_i = len_j+1 and insert relation
            if (valid_fossil[i_idx] && valid_fossil[j_idx]) begin
              if (len_i == (len_j + 3'd1)) begin
                if (is_insert_parent(seq_j, len_j, seq_i, len_i)) begin
                  parent_of[j_idx][i_idx] <= 1'b1;
                end
              end
            end

            // Compute parent_to_curr for i_idx
            if (valid_fossil[i_idx]) begin
              if (seq_length(current_seq) == (len_i + 3'd1)) begin
                if (is_insert_parent(fossil_seqs[i_idx], len_i, current_seq, seq_length(current_seq))) begin
                  parent_to_curr[i_idx] <= 1'b1;
                end
              end
            end

            // Advance j_idx, then i_idx
            if (j_idx + 1 < num_fossils) begin
              j_idx <= j_idx + 1;
            end else begin
              j_idx <= 4'd0;
              if (i_idx + 1 < num_fossils)
                i_idx <= i_idx + 1;
            end
          end
        end

        ST_ENUM: begin
          // Enumerate subset for path1; remaining fossils go to path2.
          // enum_counter runs from 0 to (1<<num_fossils)-1 or up to 255.
          subset <= enum_counter;

          // Compute masks from subset
          reg [7:0] mask1;
          reg [7:0] mask2;

          mask1 = 8'd0;
          mask2 = 8'd0;
          for (int k = 0; k < MAX_FOSSILS; k = k + 1) begin
            if (k < num_fossils) begin
              if (subset[k]) begin
                mask1[k] = 1'b1;
                mask2[k] = 1'b0;
              end else begin
                mask1[k] = 1'b0;
                mask2[k] = 1'b1;
              end
            end else begin
              mask1[k] = 1'b0;
              mask2[k] = 1'b0;
            end
          end

          // Evaluate chains for this partition
          reg [3:0] c1;
          reg [3:0] c2;
          c1 = max_chain_len(mask1);
          c2 = max_chain_len(mask2);

          // Accept if both paths reach current (non-zero length if any fossil used
          // or zero if mask empty is allowed). At least one path must connect if
          // there are fossils; here we allow zero-length if mask has no fossils.
          // We prioritize larger total (c1 + c2).

          reg [3:0] used_count1;
          reg [3:0] used_count2;
          used_count1 = 4'd0;
          used_count2 = 4'd0;
          for (int k = 0; k < MAX_FOSSILS; k = k + 1) begin
            if (mask1[k]) used_count1 = used_count1 + 4'd1;
            if (mask2[k]) used_count2 = used_count2 + 4'd1;
          end

          // Require that all fossils are assigned (mask1 or mask2) and that
          // any fossil that can potentially lead must be in a path with a chain.
          // For simplicity we accept any partition; maximize total chain lengths.

          if ((c1 + c2) > (best_s1 + best_s2)) begin
            best_s1      <= c1;
            best_s2      <= c2;
            best_p1_mask <= mask1;
            best_p2_mask <= mask2;
            found_any    <= 1'b1;
          end

          // Increment enumeration counter
          enum_counter <= enum_counter + 8'd1;
        end

        ST_CHECK: begin
          // After enumeration, decide outputs
          if (found_any && (best_s1 != 4'd0 || best_s2 != 4'd0)) begin
            possible   <= 1'b1;
            path1_mask <= best_p1_mask;
            path2_mask <= best_p2_mask;
            s1         <= best_s1;
            s2         <= best_s2;
          end else begin
            possible   <= 1'b0;
            path1_mask <= 8'd0;
            path2_mask <= 8'd0;
            s1         <= 4'd0;
            s2         <= 4'd0;
          end
        end

        ST_DONE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // ------------------------------------------------------------
  // Next-state logic
  // ------------------------------------------------------------
  always @* begin
    next_state = state;

    case (state)
      ST_IDLE: begin
        if (start)
          next_state = ST_BUILD;
      end

      ST_BUILD: begin
        // When finished iterating all i_idx,j_idx combinations
        if ((i_idx >= num_fossils) || (num_fossils == 0)) begin
          // Prepare enumeration
          next_state = ST_ENUM;
        end
      end

      ST_ENUM: begin
        // Stop after all subsets up to 2^num_fossils or 256 cycles (enum_counter wraps)
        if (enum_counter == (8'd0 - 8'd1)) begin
          next_state = ST_CHECK;
        end
      end

      ST_CHECK: begin
        next_state = ST_DONE;
      end

      ST_DONE: begin
        if (!start) // wait for start to be deasserted
          next_state = ST_IDLE;
      end

      default: begin
        next_state = ST_IDLE;
      end
    endcase
  end

endmodule