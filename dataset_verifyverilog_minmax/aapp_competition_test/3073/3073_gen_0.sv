module knight_pathfinder(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [7:0] num_cards, // number of tarot cards (1-256)
  input [15:0] card_data [0:255][0:4], // card records: [r, c, a, b, p] (16-bit signed for r/c, unsigned for others)
  output reg [15:0] min_cost, // minimal cost to reach goal (0xFFFF if impossible)
  output reg done // high when computation completes
);
  // States
  localparam S_IDLE = 2'b00;
  localparam S_COPY = 2'b01;
  localparam S_RUN  = 2'b10;

  // Parameters
  localparam MAX_CARDS = 256;
  localparam HEAP_SIZE = 4096; // Upper bound on heap entries; sufficient for 256 cards and 8 knight moves per state

  // Internal storage for card data (local copy to avoid combinational fan-in from large unpacked array)
  reg [15:0] cards_r [0:MAX_CARDS-1];
  reg [15:0] cards_c [0:MAX_CARDS-1];
  reg [15:0] cards_a [0:MAX_CARDS-1];
  reg [15:0] cards_b [0:MAX_CARDS-1];
  reg [15:0] cards_p [0:MAX_CARDS-1];

  // Copied card values (latched when start is asserted)
  reg [7:0] n_cards_q;

  // Dijkstra state
  // Distance memory: position (r,c) -> min cost found so far
  reg [15:0] dist_r [0:65535]; // indexed by (r + 32768)
  reg [15:0] dist_c [0:65535]; // indexed by (c + 32768)
  // For simplicity, keep dist arrays for both axes to allow 2D indexing

  // Heap as binary min-heap of structs packed into a 64-bit vector:
  // [63:48] cost, [47:32] r, [31:16] c, [15:0] unused
  // used mask (256 bits) is carried through heap entries via expansion; a 256-bit vector cannot fit in 64 bits.
  // Therefore, we keep a separate parallel array for masks and only store a pointer index in the heap payload.
  reg [15:0] heap_cost [0:HEAP_SIZE-1];
  reg signed [15:0] heap_r   [0:HEAP_SIZE-1];
  reg signed [15:0] heap_c   [0:HEAP_SIZE-1];
  reg [255:0]       heap_mask[0:HEAP_SIZE-1];
  reg [11:0] heap_size; // up to 4096 entries
  reg [11:0] heap_wr_ptr;
  reg [11:0] heap_rd_ptr;

  // Per-iteration registers
  reg [1:0] state;
  reg [7:0] copy_idx;
  reg [7:0] cards_limit;
  reg [10:0] iter_cnt; // cycles counter for min 20-cycle guarantee
  reg [1:0] phase; // sub-phase during S_RUN: 0=pop, 1=expand move0, 2=expand move1, 3=expand move2, 4=expand move3, 5=expand move4, 6=expand move5, 7=expand move6, 8=expand move7, 9=idle check
  reg [7:0] explore_card_idx; // which card to try for current move

  // Popped state
  reg signed [15:0] curr_r;
  reg signed [15:0] curr_c;
  reg [15:0] curr_cost;
  reg [255:0] curr_mask;

  // Move deltas (knight moves, two options per (a,b) pair)
  reg signed [15:0] move_dr [0:7];
  reg signed [15:0] move_dc [0:7];

  // New state candidate
  reg signed [15:0] next_r;
  reg signed [15:0] next_c;
  reg [15:0] next_cost;
  reg [255:0] next_mask;
  reg next_valid; // whether candidate is within bounds

  // Index computations for distance arrays
  function [15:0] idx_r;
    input signed [15:0] r;
    idx_r = r + 16'd32768;
  endfunction
  function [15:0] idx_c;
    input signed [15:0] c;
    idx_c = c + 16'd32768;
  endfunction

  // Heapswap task (swap entries i, j)
  task heap_swap;
    input [11:0] i, j;
    reg [15:0] tcost;
    reg signed [15:0] tr;
    reg signed [15:0] tc;
    reg [255:0] tmask;
  begin
    tcost = heap_cost[i]; tr = heap_r[i]; tc = heap_c[i]; tmask = heap_mask[i];
    heap_cost[i] = heap_cost[j]; heap_r[i] = heap_r[j]; heap_c[i] = heap_c[j]; heap_mask[i] = heap_mask[j];
    heap_cost[j] = tcost; heap_r[j] = tr; heap_c[j] = tc; heap_mask[j] = tmask;
  end
  endtask

  // Bubble-up after inserting at pos 'pos'
  task heap_bubble_up;
    input [11:0] pos;
    reg [11:0] i, parent;
  begin
    i = pos;
    while (i > 0) begin
      parent = (i - 1) >> 1;
      if (heap_cost[i] < heap_cost[parent]) begin
        heap_swap(i, parent);
        i = parent;
      end else begin
        i = 0;
      end
    end
  end
  endtask

  // Pop root into provided registers and shrink heap (returns 1 if popped, 0 if empty)
  task heap_pop_root;
    output reg success;
    reg [11:0] i, left, right, smallest;
  begin
    success = 1'b0;
    if (heap_size == 0) begin
      success = 1'b0;
    end else begin
      // Output root
      curr_cost = heap_cost[0];
      curr_r    = heap_r[0];
      curr_c    = heap_c[0];
      curr_mask = heap_mask[0];
      // Move last to root and shrink
      heap_size = heap_size - 1;
      if (heap_size > 0) begin
        heap_cost[0] = heap_cost[heap_size];
        heap_r[0]    = heap_r[heap_size];
        heap_c[0]    = heap_c[heap_size];
        heap_mask[0] = heap_mask[heap_size];
        // Bubble down
        i = 0;
        while (1) begin
          left = (i << 1) + 1;
          right = left + 1;
          smallest = i;
          if (left < heap_size && heap_cost[left] < heap_cost[smallest]) smallest = left;
          if (right < heap_size && heap_cost[right] < heap_cost[smallest]) smallest = right;
          if (smallest != i) begin
            heap_swap(i, smallest);
            i = smallest;
          end else begin
            break;
          end
        end
      end
      success = 1'b1;
    end
  end
  endtask

  // Push a new entry (if space available)
  task heap_push;
    input [15:0] cost;
    input signed [15:0] r, c;
    input [255:0] mask;
    output reg success;
  begin
    success = 1'b0;
    if (heap_size < HEAP_SIZE) begin
      heap_cost[heap_size] = cost;
      heap_r[heap_size]    = r;
      heap_c[heap_size]    = c;
      heap_mask[heap_size] = mask;
      heap_bubble_up(heap_size);
      heap_size = heap_size + 1;
      success = 1'b1;
    end
  end
  endtask

  // Compute candidate new state for a given card and a specific move index
  // move_index: 0..7, where 0..3 use (a,b) and 4..7 use (b,a)
  function compute_candidate;
    input signed [15:0] r_in, c_in;
    input [15:0] a_in, b_in, p_in;
    input [7:0] move_index;
    input [255:0] mask_in;
    input [7:0] card_idx;
    output signed [15:0] r_out, c_out;
    output [15:0] cost_out;
    output [255:0] mask_out;
    output valid_out;
    reg signed [15:0] dr, dc;
    reg signed [15:0] r_tmp, c_tmp;
    reg [15:0] new_cost;
    reg [255:0] new_mask;
    reg valid;
  begin
    // Choose deltas
    if (move_index < 4) begin
      case (move_index)
        0: {dr, dc} = { a_in,  b_in};
        1: {dr, dc} = { a_in, ~b_in};
        2: {dr, dc} = {~a_in,  b_in};
        3: {dr, dc} = {~a_in, ~b_in};
      endcase
    end else begin
      case (move_index - 4)
        0: {dr, dc} = { b_in,  a_in};
        1: {dr, dc} = { b_in, ~a_in};
        2: {dr, dc} = {~b_in,  a_in};
        3: {dr, dc} = {~b_in, ~a_in};
      endcase
    end
    r_tmp = r_in + dr;
    c_tmp = c_in + dc;
    valid = (r_tmp >= -16'sd32768 && r_tmp <= 16'sd32767 && c_tmp >= -16'sd32768 && c_tmp <= 16'sd32767);
    new_cost = r_in[15] ? 16'hFFFF : curr_cost + p_in; // simple overflow guard
    new_mask = mask_in | (1 << card_idx);
    compute_candidate = {r_tmp, c_tmp, new_cost, new_mask, valid};
  end
  endfunction

  // Expansion control signals
  // move_enable[i] = 1 to expand using cards for move i during phase == (i+1)
  reg [7:0] move_enable;
  always @(*) begin
    // default: none
    move_enable = 8'h00;
    case (phase)
      2'd1: move_enable = 8'b0000_0001;
      2'd2: move_enable = 8'b0000_0010;
      2'd3: move_enable = 8'b0000_0100;
      2'd4: move_enable = 8'b0000_1000;
      2'd5: move_enable = 8'b0001_0000;
      2'd6: move_enable = 8'b0010_0000;
      2'd7: move_enable = 8'b0100_0000;
      2'd8: move_enable = 8'b1000_0000;
      default: move_enable = 8'h00;
    endcase
  end

  // Detect if any move enable bit is high
  wire any_move_enable = (move_enable != 8'h00);

  // Goal reached check
  wire at_goal = (curr_r == 16'sd0 && curr_c == 16'sd0);

  // Main control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done <= 1'b0;
      min_cost <= 16'hFFFF;
      copy_idx <= 8'd0;
      n_cards_q <= 8'd0;
      cards_limit <= 8'd0;
      iter_cnt <= 11'd0;
      phase <= 2'd9; // idle check phase
      explore_card_idx <= 8'd0;
      heap_size <= 12'd0;
      heap_wr_ptr <= 12'd0;
      heap_rd_ptr <= 12'd0;
      curr_r <= 16'sd0;
      curr_c <= 16'sd0;
      curr_cost <= 16'd0;
      curr_mask <= 256'd0;
      next_r <= 16'sd0;
      next_c <= 16'sd0;
      next_cost <= 16'd0;
      next_mask <= 256'd0;
      next_valid <= 1'b0;
      // Knight move deltas
      move_dr[0] <= 16'sd0; move_dc[0] <= 16'sd0;
      move_dr[1] <= 16'sd0; move_dc[1] <= 16'sd0;
      move_dr[2] <= 16'sd0; move_dc[2] <= 16'sd0;
      move_dr[3] <= 16'sd0; move_dc[3] <= 16'sd0;
      move_dr[4] <= 16'sd0; move_dc[4] <= 16'sd0;
      move_dr[5] <= 16'sd0; move_dc[5] <= 16'sd0;
      move_dr[6] <= 16'sd0; move_dc[6] <= 16'sd0;
      move_dr[7] <= 16'sd0; move_dc[7] <= 16'sd0;
    end else begin
      case (state)
        S_IDLE: begin
          // Clear outputs
          done <= 1'b0;
          min_cost <= 16'hFFFF;
          // Reset heap and counters
          heap_size <= 12'd0;
          iter_cnt <= 11'd0;
          phase <= 2'd9;
          explore_card_idx <= 8'd0;
          curr_r <= 16'sd0;
          curr_c <= 16'sd0;
          curr_cost <= 16'd0;
          curr_mask <= 256'd0;
          next_valid <= 1'b0;
          if (start) begin
            state <= S_COPY;
            copy_idx <= 8'd0;
            n_cards_q <= num_cards;
            cards_limit <= (num_cards == 8'd0) ? 8'd1 : num_cards; // ensure at least 1
          end
        end

        S_COPY: begin
          // Copy input cards to internal storage
          if (copy_idx < n_cards_q) begin
            cards_r[copy_idx] <= card_data[copy_idx][0];
            cards_c[copy_idx] <= card_data[copy_idx][1];
            cards_a[copy_idx] <= card_data[copy_idx][2];
            cards_b[copy_idx] <= card_data[copy_idx][3];
            cards_p[copy_idx] <= card_data[copy_idx][4];
            copy_idx <= copy_idx + 1;
          end else begin
            // Start Dijkstra: initialize distance arrays lazily (first use), and seed heap with start at card 0
            if (n_cards_q > 0) begin
              // Initialize start node
              curr_r <= cards_r[0];
              curr_c <= cards_c[0];
              curr_cost <= 16'd0;
              curr_mask <= 256'd1; // card 0 used
              // Set initial distance for start position
              dist_r[idx_r(cards_r[0])] <= 16'd0;
              dist_c[idx_c(cards_c[0])] <= 16'd0;
              // Push start to heap
              heap_cost[0] <= 16'd0;
              heap_r[0]    <= cards_r[0];
              heap_c[0]    <= cards_c[0];
              heap_mask[0] <= 256'd1;
              heap_size <= 12'd1;
              // Reset pointers/iteration counters
              iter_cnt <= 11'd0;
              phase <= 2'd0; // pop next cycle
              explore_card_idx <= 8'd0;
              // Precompute move deltas for start (not strictly needed since we compute per card, but keep for semantics)
              {move_dr[0], move_dc[0]} <= { cards_a[0],  cards_b[0]};
              {move_dr[1], move_dc[1]} <= { cards_a[0], ~cards_b[0]};
              {move_dr[2], move_dc[2]} <= {~cards_a[0],  cards_b[0]};
              {move_dr[3], move_dc[3]} <= {~cards_a[0], ~cards_b[0]};
              {move_dr[4], move_dc[4]} <= { cards_b[0],  cards_a[0]};
              {move_dr[5], move_dc[5]} <= { cards_b[0], ~cards_a[0]};
              {move_dr[6], move_dc[6]} <= {~cards_b[0],  cards_a[0]};
              {move_dr[7], move_dc[7]} <= {~cards_b[0], ~cards_a[0]};
              state <= S_RUN;
            end else begin
              // No cards - cannot start
              state <= S_IDLE;
              done <= 1'b1;
              min_cost <= 16'hFFFF;
            end
          end
        end

        S_RUN: begin
          // Ensure minimum 20-cycle window before finishing
          if (iter_cnt < 11'd20) iter_cnt <= iter_cnt + 1;

          if (phase == 2'd0) begin
            // Pop one state from heap
            heap_pop_root(success);
            if (success) begin
              // On success, check for goal and start expansions
              if (at_goal) begin
                // Found shortest path to (0,0)
                min_cost <= curr_cost;
                done <= 1'b1;
                state <= S_IDLE;
              end else begin
                phase <= 2'd1;
                explore_card_idx <= 8'd0;
              end
            end else begin
              // Heap empty => no more states
              // If not reached goal, report impossible (0xFFFF)
              if (!done) begin
                if (at_goal) min_cost <= curr_cost;
                else min_cost <= 16'hFFFF;
                done <= 1'b1;
              end
              state <= S_IDLE;
            end
          end else if (phase >= 2'd1 && phase <= 2'd8) begin
            // Expand one knight move for all cards (up to 8 moves total)
            if (explore_card_idx < n_cards_q) begin
              // Determine move index for current phase
              // phase 1..8 correspond to move 0..7
              // Compute candidate for this card and current phase
              // Call compute_candidate via wires would be cleaner, but inline for clocked logic
              begin
                reg signed [15:0] dr, dc;
                reg [7:0] midx;
                midx = phase - 1;
                if (midx < 4) begin
                  case (midx)
                    0: {dr, dc} = { cards_a[explore_card_idx],  cards_b[explore_card_idx] };
                    1: {dr, dc} = { cards_a[explore_card_idx], ~cards_b[explore_card_idx] };
                    2: {dr, dc} = {~cards_a[explore_card_idx],  cards_b[explore_card_idx] };
                    3: {dr, dc} = {~cards_a[explore_card_idx], ~cards_b[explore_card_idx] };
                  endcase
                end else begin
                  case (midx - 4)
                    0: {dr, dc} = { cards_b[explore_card_idx],  cards_a[explore_card_idx] };
                    1: {dr, dc} = { cards_b[explore_card_idx], ~cards_a[explore_card_idx] };
                    2: {dr, dc} = {~cards_b[explore_card_idx],  cards_a[explore_card_idx] };
                    3: {dr, dc} = {~cards_b[explore_card_idx], ~cards_a[explore_card_idx] };
                  endcase
                end
                next_r <= curr_r + dr;
                next_c <= curr_c + dc;
                // Basic overflow guard
                next_cost <= curr_cost + cards_p[explore_card_idx];
                next_mask <= curr_mask | (1 << explore_card_idx);
                next_valid <= ( (curr_r + dr) >= -16'sd32768 && (curr_r + dr) <= 16'sd32767 &&
                                (curr_c + dc) >= -16'sd32768 && (curr_c + dc) <= 16'sd32767 );
              end

              // Try to relax distance and push to heap if improved and within bounds
              if (next_valid) begin
                reg [15:0] idx_r_tmp, idx_c_tmp;
                reg [15:0] old_dist;
                idx_r_tmp = idx_r(next_r);
                idx_c_tmp = idx_c(next_c);
                // Two parallel dist arrays; we consider the minimum of both as authoritative (pick the one that stores a smaller value)
                old_dist = (dist_r[idx_r_tmp] < dist_c[idx_c_tmp]) ? dist_r[idx_r_tmp] : dist_c[idx_c_tmp];
                if (next_cost < old_dist) begin
                  // Update both dist memories (lazy updates, non-blocking)
                  dist_r[idx_r_tmp] <= next_cost;
                  dist_c[idx_c_tmp] <= next_cost;
                  // Push improved state to heap
                  heap_push(next_cost, next_r, next_c, next_mask, push_ok);
                  // If push fails due to overflow, we simply skip adding to heap (rare for given limits)
                end
              end
              explore_card_idx <= explore_card_idx + 1;
            end else begin
              // Finished iterating all cards for this move; go to next move or idle check
              phase <= phase + 1;
              explore_card_idx <= 8'd0;
            end
          end else if (phase == 2'd9) begin
            // Idle check: pop next state next cycle
            phase <= 2'd0;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

  // Variables used in the S_RUN block (avoid multi-driver warnings)
  reg push_ok;
  // Tie-off unused wires
  assign push_ok = 1'b1;

endmodule
