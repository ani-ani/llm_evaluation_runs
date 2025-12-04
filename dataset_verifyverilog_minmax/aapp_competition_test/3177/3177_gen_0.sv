module swap_sort_min_steps (
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0][1:0] initial_perm,    // 4 elements, each 2 bits (values 0-3)
  input  [5:0][3:0] allowed_swaps,   // up to 6 swaps: (A_i, B_i), each 2 bits
  input  [2:0]       m_swaps,        // number of allowed swaps (0-6)
  output reg [3:0]   min_steps,      // min swaps needed (0-15)
  output reg         done            // high when result ready
);

  // ------ Internal types ------
  typedef logic [7:0] perm8_t;  // 4 values x 2 bits
  typedef logic [23:0] bitmask24_t;

  // ------ Constants ------
  localparam int N_ELMS   = 4;
  localparam int MAX_STEPS = 4'd15; // Upper bound of swaps we track

  // ------ Helper functions ------
  function bit is_sorted (input perm8_t s);
    // returns 1'b1 if s represents [0,1,2,3]
    // s[7:6] -> element 0, s[5:4] -> element 1, s[3:2] -> element 2, s[1:0] -> element 3
    return (s[7:6] == 2'd0) && (s[5:4] == 2'd1) && (s[3:2] == 2'd2) && (s[1:0] == 2'd3);
  endfunction

  function perm8_t apply_swap (input perm8_t s, input [1:0] a, input [1:0] b);
    // swap positions a and b in the permutation
    logic [1:0] va, vb;
    va = (a == 2'd0) ? s[7:6] :
         (a == 2'd1) ? s[5:4] :
         (a == 2'd2) ? s[3:2] : s[1:0];
    vb = (b == 2'd0) ? s[7:6] :
         (b == 2'd1) ? s[5:4] :
         (b == 2'd2) ? s[3:2] : s[1:0];
    // Write-back swapped values
    apply_swap = s;
    case (a)
      2'd0: apply_swap[7:6] = vb;
      2'd1: apply_swap[5:4] = vb;
      2'd2: apply_swap[3:2] = vb;
      2'd3: apply_swap[1:0] = vb;
    endcase
    case (b)
      2'd0: apply_swap[7:6] = va;
      2'd1: apply_swap[5:4] = va;
      2'd2: apply_swap[3:2] = va;
      2'd3: apply_swap[1:0] = va;
    endcase
  endfunction

  // Return index (0..23) of the given permutation among sorted permutations, else 24.
  // Uses a compact decision tree.
  function [5:0] perm_index (input perm8_t s);
    logic [1:0] p0, p1, p2, p3;
    p0 = s[7:6]; p1 = s[5:4]; p2 = s[3:2]; p3 = s[1:0];

    // Quick exit if already sorted
    if (is_sorted(s)) begin
      perm_index = 6'd0;
      return;
    end

    // p0=0 cases (there are 6 permutations starting with 0)
    if (p0 == 2'd0) begin
      if (p1 == 2'd1) begin
        // 0,1,2,3 -> 0; 0,1,3,2 -> 1
        if (p2 == 2'd2) perm_index = (p3 == 2'd2) ? 6'd0 : 6'd1; // impossible p3==2 here, but kept for completeness
        else           perm_index = (p3 == 2'd2) ? 6'd2 : 6'd3; // 0,2,1,3->2; 0,2,3,1->3; 0,3,1,2->4; 0,3,2,1->5
      end else if (p1 == 2'd2) begin
        // 0,2,1,3->2; 0,2,3,1->3
        if (p2 == 2'd1) perm_index = (p3 == 2'd3) ? 6'd2 : 6'd4; // 0,2,1,3->2; 0,2,1,3 unreachable p3!=3; 0,2,3,1->3 already captured
        else           perm_index = (p3 == 2'd1) ? 6'd3 : 6'd5; // 0,2,3,1->3; 0,3,2,1->5
      end else begin // p1 == 3
        // 0,3,1,2->4; 0,3,2,1->5
        if (p2 == 2'd1) perm_index = 6'd4; // 0,3,1,2
        else           perm_index = 6'd5; // 0,3,2,1
      end
      return;
    end

    // p0=1 cases (another 6)
    if (p0 == 2'd1) begin
      // 1,0,2,3 -> 6; 1,0,3,2 -> 7; 1,2,0,3 -> 8; 1,2,3,0 -> 9; 1,3,0,2 -> 10; 1,3,2,0 -> 11
      if (p1 == 2'd0) begin
        if (p2 == 2'd2) perm_index = (p3 == 2'd3) ? 6'd6 : 6'd7; // 1,0,2,3->6; 1,0,3,2->7
        else           perm_index = 6'd7; // remaining (shouldn't hit)
      end else if (p1 == 2'd2) begin
        if (p2 == 2'd0) perm_index = (p3 == 2'd3) ? 6'd8 : 6'd12; // 1,2,0,3->8; 1,2,3,0->9 captured later
        else           perm_index = (p3 == 2'd0) ? 6'd9 : 6'd13;
      end else begin // p1 == 3
        if (p2 == 2'd0) perm_index = 6'd10; // 1,3,0,2
        else           perm_index = 6'd11; // 1,3,2,0
      end
      return;
    end

    // p0=2 cases (another 6)
    if (p0 == 2'd2) begin
      // 2,0,1,3->12; 2,0,3,1->13; 2,1,0,3->14; 2,1,3,0->15; 2,3,0,1->16; 2,3,1,0->17
      if (p1 == 2'd0) begin
        perm_index = (p2 == 2'd1) ? ((p3 == 2'd3) ? 6'd12 : 6'd14) : ((p3 == 2'd1) ? 6'd13 : 6'd15);
      end else if (p1 == 2'd1) begin
        perm_index = (p2 == 2'd0) ? ((p3 == 2'd3) ? 6'd14 : 6'd15) : ((p3 == 2'd0) ? 6'd15 : 6'd17);
      end else begin // p1 == 3
        perm_index = (p2 == 2'd0) ? 6'd16 : 6'd17;
      end
      return;
    end

    // p0=3 cases (last 6)
    // 3,0,1,2->18; 3,0,2,1->19; 3,1,0,2->20; 3,1,2,0->21; 3,2,0,1->22; 3,2,1,0->23
    if (p1 == 2'd0) begin
      perm_index = (p2 == 2'd1) ? 6'd18 : 6'd19;
    end else if (p1 == 2'd1) begin
      perm_index = (p2 == 2'd0) ? 6'd20 : 6'd21;
    end else begin // p1 == 2
      perm_index = (p2 == 2'd0) ? 6'd22 : 6'd23;
    end
  endfunction

  // ------ Registers and wires ------
  typedef enum logic [2:0] {
    IDLE       = 3'b000,
    BFS_CHECK  = 3'b001,
    BFS_EXPAND = 3'b010
  } fsm_state_t;

  fsm_state_t fsm_state, fsm_next;

  perm8_t init_state;
  perm8_t curr_state;
  perm8_t queue_r [0:23];
  perm8_t queue_nxt [0:23];
  logic [4:0] head_r, head_nxt; // 5 bits to hold 0..23
  logic [4:0] tail_r, tail_nxt;
  logic [4:0] head_next_r, head_next_nxt; // head for next depth
  logic [4:0] tail_next_r, tail_next_nxt;
  bitmask24_t visited_r, visited_nxt;
  logic [3:0] steps_r, steps_nxt;    // current BFS depth
  logic [3:0] steps_next_r, steps_next_nxt; // next BFS depth
  logic [2:0] swap_idx_r, swap_idx_nxt;
  logic queue_full, queue_empty, all_expanded;
  logic finished, can_expand_more;

  // ------ Combinational logic ------
  // Flatten initial permutation to 8-bit perm8_t
  always_comb begin
    init_state = {initial_perm[0], initial_perm[1], initial_perm[2], initial_perm[3]}; // MSB..LSB
  end

  // decode allowed swaps: (A_i,B_i) = allowed_swaps[i][3:2], allowed_swaps[i][1:0]
  logic [1:0] swap_a [0:5];
  logic [1:0] swap_b [0:5];
  always_comb begin
    for (int i = 0; i < 6; i++) begin
      swap_a[i] = allowed_swaps[i][3:2];
      swap_b[i] = allowed_swaps[i][1:0];
    end
  end

  assign queue_full   = (tail_nxt == 5'd24);  // will be computed in next-state block when using tail_nxt
  assign queue_empty  = (head_r   == tail_r);
  assign all_expanded = (head_r   == head_next_r);
  assign can_expand_more = (steps_r < MAX_STEPS);

  // ------ Next-state logic for BFS ------
  // Current state: dequeues happen in BFS_CHECK, expansions in BFS_EXPAND
  // Queue: single port; we use head_r/tail_r for current depth, head_next_r/tail_next_r for next depth
  always_comb begin
    // Defaults (keep current values unless updated)
    fsm_next         = fsm_state;
    curr_state       = curr_state;
    head_nxt         = head_r;
    tail_nxt         = tail_r;
    head_next_nxt    = head_next_r;
    tail_next_nxt    = tail_next_r;
    visited_nxt      = visited_r;
    steps_nxt        = steps_r;
    steps_next_nxt   = steps_next_r;
    swap_idx_nxt     = swap_idx_r;
    min_steps        = min_steps;
    done             = 1'b0;

    // Queue next array default copy
    for (int i = 0; i < 24; i++) queue_nxt[i] = queue_r[i];

    unique case (fsm_state)
      IDLE: begin
        // Wait for start
        if (start) begin
          // initialize
          curr_state    = init_state;
          visited_nxt   = 1 << perm_index(init_state);
          head_nxt      = 5'd0;
          tail_nxt      = 5'd0;
          head_next_nxt = 5'd0;
          tail_next_nxt = 5'd0;
          steps_nxt     = 4'd0;
          steps_next_nxt= 4'd1;
          swap_idx_nxt  = 3'd0;
          for (int i = 0; i < 24; i++) queue_nxt[i] = 8'b0;
          // If already sorted, done in 0 steps
          if (is_sorted(init_state)) begin
            min_steps = 4'd0;
            done      = 1'b1;
            fsm_next  = IDLE;
          end else begin
            fsm_next  = BFS_CHECK;
          end
        end else begin
          // remain idle
          min_steps = 4'd0;
          done      = 1'b0;
        end
      end

      BFS_CHECK: begin
        // Dequeue a state to inspect
        if (queue_empty) begin
          // No more states in current frontier: move to next frontier
          head_nxt      = head_next_r;
          tail_nxt      = tail_next_r;
          head_next_nxt = head_nxt;
          tail_next_nxt = head_nxt;
          steps_nxt     = steps_next_r;
          // If next frontier is empty, we're done
          if (head_nxt == tail_nxt) begin
            // Not found within allowed steps: return max_steps (15) as upper bound
            min_steps = MAX_STEPS;
            done      = 1'b1;
            fsm_next  = IDLE;
          end else begin
            // Continue BFS for next depth
            swap_idx_nxt = 3'd0;
            // Stay in BFS_CHECK to dequeue the first element of the new frontier
          end
        end else begin
          // Dequeue and test
          curr_state = queue_r[head_r];
          head_nxt   = head_r + 1'b1;
          if (is_sorted(curr_state)) begin
            min_steps = steps_r;
            done      = 1'b1;
            fsm_next  = IDLE;
          end else begin
            fsm_next  = BFS_EXPAND;
          end
        end
      end

      BFS_EXPAND: begin
        // Expand current_state via allowed swaps at index swap_idx_r
        if (swap_idx_r < m_swaps) begin
          // try this swap
          perm8_t neighbor = apply_swap(curr_state, swap_a[swap_idx_r], swap_b[swap_idx_r]);
          if (!visited_nxt[perm_index(neighbor)]) begin
            // mark visited and enqueue to next frontier if we still have depth budget
            visited_nxt[perm_index(neighbor)] = 1'b1;
            if (can_expand_more) begin
              queue_nxt[tail_next_r] = neighbor;
              tail_next_nxt = tail_next_r + 1'b1;
            end
          end
          swap_idx_nxt = swap_idx_r + 1'b1; // next swap for this state
          fsm_next     = BFS_EXPAND;        // remain in expand until all swaps tried
        end else begin
          // Done expanding this state; go back to dequeuing next one
          fsm_next = BFS_CHECK;
        end
      end

      default: fsm_next = IDLE;
    endcase

    // Update queue array (write-through)
    // It is already copied at the top; updates are written in BFS_EXPAND/INIT paths.
  end

  // ------ Sequential logic ------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      fsm_state       <= IDLE;
      curr_state      <= 8'b0;
      head_r          <= 5'd0;
      tail_r          <= 5'd0;
      head_next_r     <= 5'd0;
      tail_next_r     <= 5'd0;
      visited_r       <= 24'b0;
      steps_r         <= 4'd0;
      steps_next_r    <= 4'd0;
      swap_idx_r      <= 3'd0;
      for (int i = 0; i < 24; i++) queue_r[i] <= 8'b0;
      min_steps       <= 4'd0;
      done            <= 1'b0;
    end else begin
      fsm_state       <= fsm_next;
      curr_state      <= curr_state;
      head_r          <= head_nxt;
      tail_r          <= tail_nxt;
      head_next_r     <= head_next_nxt;
      tail_next_r     <= tail_next_nxt;
      visited_r       <= visited_nxt;
      steps_r         <= steps_nxt;
      steps_next_r    <= steps_next_nxt;
      swap_idx_r      <= swap_idx_nxt;
      for (int i = 0; i < 24; i++) queue_r[i] <= queue_nxt[i];
      min_steps       <= min_steps;
      done            <= done;
    end
  end

endmodule