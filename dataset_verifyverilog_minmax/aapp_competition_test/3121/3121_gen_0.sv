module cave_pathfinder(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Start computation (pulse high)
  input [15:0] unnars_attack, // Unnar's attack points (A) scaled to 16-bit
  input [15:0] unnars_health, // Unnar's initial health (H) scaled to 16-bit
  input [3:0] num_nodes, // Number of areas (n), max 8 (value 1-8)
  input [3:0] num_passages, // Number of passages (m), max 16
  input [63:0] passages [0:15], // Packed passage data (4x16-bit fields per passage) [from(3:0), to(3:0), enemy_a(15:0), enemy_h(15:0)]
  output reg [15:0] max_health, // Best found health (0 if no path)
  output reg done, // High when computation complete
  output reg oh_no // High when no valid path found
);

  // State machine states
  localparam IDLE   = 3'b000;
  localparam INIT   = 3'b001;
  localparam STACK  = 3'b010;
  localparam EXPLORE= 3'b011;
  localparam BACKTRK= 3'b100;
  localparam FINISH = 3'b101;

  // DFS stack for up to 8 nodes
  localparam MAX_DEPTH = 8;
  typedef struct packed {
    logic [2:0] node;         // 3 bits sufficient for 0..7
    logic [2:0] neighbor_ptr; // which neighbor we are trying next (0..15)
    logic [7:0] visited_mask; // visited nodes for this frame
    logic [15:0] cur_health;  // health upon entering this node
    logic        health_valid;// health valid flag (0 when current path invalid)
  } stack_t;

  logic [2:0] state;
  stack_t stack [0:MAX_DEPTH-1];
  logic [2:0] sp;     // stack pointer (0 means empty)
  logic [2:0] max_nodes_r; // num_nodes-1 cached
  logic found_any;    // any valid path found to target
  logic [2:0] target_node;
  logic [2:0] start_node;

  // Helper: indexed reading from passages array safely
  // Uses 0 when index >= num_passages to avoid uninitialized reads
  function [63:0] read_passage(logic [3:0] idx);
    logic [3:0] sel;
    sel = (idx < num_passages) ? idx : 4'd0;
    return passages[sel];
  endfunction

  // Helper: given a node, find the first outgoing passage index (0..15) or 16 if none
  function [3:0] first_edge_of_node(logic [2:0] node);
    logic [3:0] i;
    logic [63:0] p;
    for (i = 0; i < 16; i = i + 1) begin
      p = read_passage(i);
      if (p[3:0] == node) begin
        return i;
      end
    end
    return 4'd16; // no edge
  endfunction

  // Helper: fetch the 'from' field of passage i (4 bits), safe indexed
  function [3:0] edge_from(logic [3:0] i);
    return read_passage(i)[3:0];
  endfunction

  // Helper: fetch the 'to' field of passage i (4 bits), safe indexed
  function [3:0] edge_to(logic [3:0] i);
    return read_passage(i)[7:4];
  endfunction

  // Helper: fetch the enemy attack (16 bits), safe indexed
  function [15:0] edge_enemy_a(logic [3:0] i);
    return read_passage(i)[23:8];
  endfunction

  // Helper: fetch the enemy health (16 bits), safe indexed
  function [15:0] edge_enemy_h(logic [3:0] i);
    return read_passage(i)[39:24];
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done  <= 1'b0;
      oh_no <= 1'b0;
      max_health <= 16'd0;
      found_any <= 1'b0;
      sp <= 3'd0;
      // Clear stack
      for (int k = 0; k < MAX_DEPTH; k++) begin
        stack[k] <= '0;
      end
    end else begin
      case (state)
        IDLE: begin
          done  <= 1'b0;
          oh_no <= 1'b0;
          max_health <= 16'd0;
          found_any <= 1'b0;
          sp <= 3'd0;
          for (int k = 0; k < MAX_DEPTH; k++) stack[k] <= '0;
          if (start) begin
            // cache derived parameters
            max_nodes_r <= (num_nodes > 4'd0) ? (num_nodes - 1'b1) : 4'd0; // safety; normally 1..8
            target_node <= (num_nodes > 4'd0) ? (num_nodes - 1'b1) : 4'd0;
            start_node  <= 3'd0; // node 1 (index 0)
            state <= INIT;
          end else begin
            state <= IDLE;
          end
        end

        INIT: begin
          // Prepare initial stack frame for the start node if graph is non-empty
          if (num_nodes == 4'd0) begin
            state <= FINISH; // degenerate case
          end else begin
            stack[0].node          <= start_node;
            stack[0].neighbor_ptr  <= first_edge_of_node(start_node);
            stack[0].visited_mask  <= (1 << start_node);
            stack[0].cur_health    <= unnars_health;
            stack[0].health_valid  <= (unnars_health > 16'd0);
            sp <= 3'd1;
            state <= EXPLORE;
          end
        end

        EXPLORE: begin
          if (sp == 3'd0) begin
            // Stack underflow -> finished all exploration
            state <= FINISH;
          end else begin
            stack_t cur = stack[sp-1];
            // Check if we reached target node
            if (cur.node == target_node) begin
              // Update best solution if current health is valid and better
              if (cur.health_valid) begin
                if (!found_any || (cur.cur_health > max_health)) begin
                  max_health <= cur.cur_health;
                end
                found_any <= 1'b1;
              end
              // Backtrack to continue search
              state <= BACKTRK;
            end else begin
              // Explore neighbors from current node
              if (cur.neighbor_ptr < 4'd16) begin
                // Get the candidate edge; if 'from' doesn't match, skip it
                logic [3:0] e_idx;
                logic [3:0] from_n, to_n;
                logic [15:0] e_a, e_h;
                logic valid_from;
                logic valid_edge;
                logic to_not_visited;
                logic [15:0] rounds_needed, new_health;
                logic take_damage, path_still_valid;

                e_idx = cur.neighbor_ptr;
                from_n = edge_from(e_idx);
                to_n   = edge_to(e_idx);
                e_a    = edge_enemy_a(e_idx);
                e_h    = edge_enemy_h(e_idx);
                valid_from = (from_n == cur.node);

                // Only consider this edge if it originates from current node
                if (valid_from) begin
                  // Compute if this edge is usable: node not visited in this path, and path health still valid before fighting
                  to_not_visited = ~cur.visited_mask[to_n];
                  // Fight computation (combinational)
                  // rounds_needed = ceil(e_h / unnars_attack) = (e_h + A - 1) / A
                  rounds_needed = (e_h + unnars_attack - 1) / unnars_attack;
                  take_damage   = (rounds_needed - 1) * e_a;
                  new_health    = cur.cur_health - take_damage;
                  path_still_valid = cur.health_valid && (new_health >= 16'd1) && (unnars_attack > 16'd0);
                  valid_edge = to_not_visited && path_still_valid;
                end else begin
                  valid_edge = 1'b0;
                end

                // Update neighbor pointer for next cycle
                stack[sp-1].neighbor_ptr <= cur.neighbor_ptr + 1;

                if (valid_edge) begin
                  // Push next node onto stack
                  stack[sp].node          <= to_n;
                  stack[sp].neighbor_ptr  <= first_edge_of_node(to_n);
                  stack[sp].visited_mask  <= cur.visited_mask | (1 << to_n);
                  stack[sp].cur_health    <= new_health;
                  stack[sp].health_valid  <= 1'b1;
                  sp <= sp + 1;
                end
                // If not valid_edge, loop again in EXPLORE with updated neighbor_ptr
                state <= EXPLORE;
              end else begin
                // No more neighbors from this node -> backtrack
                state <= BACKTRK;
              end
            end
          end
        end

        BACKTRK: begin
          // Pop stack and continue
          if (sp > 3'd0) begin
            sp <= sp - 1;
            state <= EXPLORE;
          end else begin
            // Should not happen, but guard
            state <= FINISH;
          end
        end

        FINISH: begin
          // Final outputs
          done <= 1'b1;
          if (found_any) begin
            oh_no <= 1'b0;
            // max_health already holds the best found
          end else begin
            oh_no <= 1'b1;
            max_health <= 16'd0;
          end
          // Remain here until start pulse (or reset)
          if (!start) begin
            state <= IDLE;
          end else begin
            state <= FINISH;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end
endmodule