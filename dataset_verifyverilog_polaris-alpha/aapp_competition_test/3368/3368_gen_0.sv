module animal_sanctuary_restore(
  input clk,
  input rst_n,
  input start,
  input [1:0] correct_animal [0:3],
  input [1:0] current_count [0:3],
  input [3:0][1:0] current_animals,
  output reg [1:0] result,
  output reg done
);

  // State encoding
  localparam [2:0]
    S_IDLE          = 3'd0,
    S_VERIFY_CORRECT= 3'd1,
    S_BUILD_GRAPH   = 3'd2,
    S_CHECK_CYCLES  = 3'd3,
    S_DONE          = 3'd4;

  localparam [1:0]
    RES_FALSE_ALARM = 2'b00,
    RES_POSSIBLE    = 2'b01,
    RES_IMPOSSIBLE  = 2'b10;

  // Internal registers
  reg [2:0] state, next_state;

  // Slot mapping: idx 0..3 -> current_animals[idx]
  // For each slot/node, we hold the target node index (0..3) or 4 if no valid target.
  reg [2:0] target_node [0:3]; // 3 bits enough to encode 0-4
  reg [2:0] next_target_node [0:3];

  // Used flags for matching animals to enclosures during build
  reg used_enc [0:3];
  reg next_used_enc [0:3];

  // Counters and temps
  reg [2:0] idx;        // generic 0..4
  reg [2:0] next_idx;
  reg [2:0] j;
  reg [2:0] next_j;

  // For VERIFY_CORRECT
  reg all_correct;
  reg next_all_correct;

  // For BUILD_GRAPH
  reg [1:0] cur_animal;
  reg [2:0] free_enc_idx;
  reg found;
  reg next_found;

  // For CHECK_CYCLES
  reg visited [0:3];
  reg next_visited [0:3];
  reg in_cycle [0:3];
  reg next_in_cycle [0:3];
  reg [2:0] cycle_count;
  reg [2:0] next_cycle_count;
  reg [2:0] cur_node;
  reg [2:0] next_cur_node;
  reg [2:0] step_cnt;
  reg [2:0] next_step_cnt;
  reg processing;
  reg next_processing;

  // Sequential state and registers update
  integer k;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      result <= RES_IMPOSSIBLE;
      done <= 1'b0;
      idx <= 3'd0;
      j <= 3'd0;
      all_correct <= 1'b0;
      found <= 1'b0;
      cycle_count <= 3'd0;
      cur_node <= 3'd0;
      step_cnt <= 3'd0;
      processing <= 1'b0;
      for (k = 0; k < 4; k = k + 1) begin
        target_node[k] <= 3'd4; // invalid
        used_enc[k] <= 1'b0;
        visited[k] <= 1'b0;
        in_cycle[k] <= 1'b0;
      end
    end else begin
      state <= next_state;
      idx <= next_idx;
      j <= next_j;
      all_correct <= next_all_correct;
      found <= next_found;
      cycle_count <= next_cycle_count;
      cur_node <= next_cur_node;
      step_cnt <= next_step_cnt;
      processing <= next_processing;
      for (k = 0; k < 4; k = k + 1) begin
        target_node[k] <= next_target_node[k];
        used_enc[k] <= next_used_enc[k];
        visited[k] <= next_visited[k];
        in_cycle[k] <= next_in_cycle[k];
      end
      if (state == S_DONE) begin
        done <= 1'b1;
      end else if (state == S_IDLE && start) begin
        done <= 1'b0;
      end
      // result is driven in combinational next_state logic via blocking assign to result
    end
  end

  // Combinational next-state and control logic
  integer i;
  always @* begin
    // Defaults
    next_state = state;
    next_idx = idx;
    next_j = j;
    next_all_correct = all_correct;
    next_found = found;
    next_cycle_count = cycle_count;
    next_cur_node = cur_node;
    next_step_cnt = step_cnt;
    next_processing = processing;

    // Keep current arrays by default
    for (i = 0; i < 4; i = i + 1) begin
      next_target_node[i] = target_node[i];
      next_used_enc[i] = used_enc[i];
      next_visited[i] = visited[i];
      next_in_cycle[i] = in_cycle[i];
    end

    case (state)
      // Wait for start
      S_IDLE: begin
        if (start) begin
          // Initialize for new run
          next_all_correct = 1'b1;
          next_idx = 3'd0;
          for (i = 0; i < 4; i = i + 1) begin
            next_target_node[i] = 3'd4; // invalid
            next_used_enc[i] = 1'b0;
            next_visited[i] = 1'b0;
            next_in_cycle[i] = 1'b0;
          end
          next_cycle_count = 3'd0;
          next_cur_node = 3'd0;
          next_step_cnt = 3'd0;
          next_processing = 1'b0;
          next_state = S_VERIFY_CORRECT;
        end
      end

      // Check if all animals already in their correct enclosures
      S_VERIFY_CORRECT: begin
        // Iterate over all slots 0..3 (one per cycle)
        if (idx < 3'd4) begin
          if (idx < 3'd4) begin
            if (current_animals[idx] != 2'b00) begin
              // Find enclosure index for this slot (assume one-to-one mapping: slot idx -> some enclosure idx)
              // Here we conservatively require that there exists some enclosure whose correct_animal matches.
              // If none matches, then not all correct.
              reg match;
              match = 1'b0;
              for (i = 0; i < 4; i = i + 1) begin
                if (correct_animal[i] == current_animals[idx]) begin
                  match = 1'b1;
                end
              end
              if (!match) begin
                next_all_correct = 1'b0;
              end
            end
          end
          next_idx = idx + 3'd1;
        end else begin
          // Finished scan
          next_idx = 3'd0;
          if (all_correct) begin
            // All already correct
            next_state = S_DONE;
          end else begin
            // Need to build movement graph
            next_state = S_BUILD_GRAPH;
          end
        end
      end

      // Build mapping from each animal slot to a target enclosure index
      S_BUILD_GRAPH: begin
        if (idx < 3'd4) begin
          cur_animal = current_animals[idx];
          if (cur_animal == 2'b00) begin
            // Empty slot: no edge
            next_target_node[idx] = 3'd4;
            next_idx = idx + 3'd1;
          end else begin
            // Find an unused enclosure whose correct_animal matches cur_animal
            next_found = 1'b0;
            free_enc_idx = 3'd4;
            for (i = 0; i < 4; i = i + 1) begin
              if (!next_used_enc[i] && correct_animal[i] == cur_animal && !next_found) begin
                free_enc_idx = i[2:0];
                next_found = 1'b1;
              end
            end
            if (next_found) begin
              next_target_node[idx] = free_enc_idx;
              next_used_enc[free_enc_idx] = 1'b1;
            end else begin
              // No valid target -> impossible
              result = RES_IMPOSSIBLE;
              next_state = S_DONE;
            end
            if (next_state != S_DONE) begin
              next_idx = idx + 3'd1;
            end
          end
        end else begin
          // All slots processed, go check cycles
          next_idx = 3'd0;
          // Reset visited/in_cycle
          for (i = 0; i < 4; i = i + 1) begin
            next_visited[i] = 1'b0;
            next_in_cycle[i] = 1'b0;
          end
          next_cycle_count = 3'd0;
          next_cur_node = 3'd0;
          next_step_cnt = 3'd0;
          next_processing = 1'b0;
          next_state = S_CHECK_CYCLES;
        end
      end

      // Check if the movement graph forms exactly one cycle covering all non-empty nodes
      S_CHECK_CYCLES: begin
        // Iterate through nodes, start a traversal from each unvisited node that has an outgoing edge
        if (!processing) begin
          if (cur_node < 3'd4) begin
            if (!visited[cur_node] && target_node[cur_node] < 3'd4) begin
              // Start traversal from this node
              next_processing = 1'b1;
              next_step_cnt = 3'd0;
            end else begin
              next_cur_node = cur_node + 3'd1;
            end
          end else begin
            // Finished scanning all nodes
            // Check conditions: exactly one cycle and no other edges outside that cycle
            if (cycle_count == 3'd1) begin
              // Ensure all nodes with edges are in the cycle
              reg ok_all_in_cycle;
              ok_all_in_cycle = 1'b1;
              for (i = 0; i < 4; i = i + 1) begin
                if (target_node[i] < 3'd4 && !in_cycle[i]) begin
                  ok_all_in_cycle = 1'b0;
                end
              end
              if (ok_all_in_cycle) begin
                result = RES_POSSIBLE;
              end else begin
                result = RES_IMPOSSIBLE;
              end
            end else begin
              result = RES_IMPOSSIBLE;
            end
            next_state = S_DONE;
          end
        end else begin
          // processing == 1: follow edges from current cur_node to detect a cycle/path
          reg [2:0] nxt;
          nxt = target_node[cur_node];

          // Mark current as visited (if not yet)
          next_visited[cur_node] = 1'b1;

          if (nxt >= 3'd4) begin
            // Reached node without outgoing edge: singleton or tail -> invalid structure
            result = RES_IMPOSSIBLE;
            next_state = S_DONE;
            next_processing = 1'b0;
          end else if (visited[nxt]) begin
            // Found a cycle close
            // Count nodes in this cycle by walking back via step_cnt approximation
            // For this constrained problem, treat this as one cycle
            next_cycle_count = cycle_count + 3'd1;
            // Mark current node and next as part of a cycle; also, any visited in this traversal considered cycle nodes.
            // Since we don't track per-traversal, conservatively mark all visited nodes as in_cycle when first cycle found.
            if (cycle_count == 3'd0) begin
              for (i = 0; i < 4; i = i + 1) begin
                if (visited[i]) next_in_cycle[i] = 1'b1;
              end
              next_in_cycle[nxt] = 1'b1;
            end
            next_processing = 1'b0;
            next_cur_node = cur_node + 3'd1;
          end else begin
            // Continue along the path
            next_cur_node = nxt;
            next_step_cnt = step_cnt + 3'd1;
            if (step_cnt >= 3'd4) begin
              // Too long path -> invalid (should have cycled or ended)
              result = RES_IMPOSSIBLE;
              next_state = S_DONE;
              next_processing = 1'b0;
            end
          end
        end
      end

      S_DONE: begin
        // Hold result and done until next start or reset
        if (start) begin
          next_state = S_IDLE;
        end
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase

    // Default result if not assigned in branches
    if (state == S_IDLE && !start) begin
      result = RES_IMPOSSIBLE;
    end
  end

endmodule