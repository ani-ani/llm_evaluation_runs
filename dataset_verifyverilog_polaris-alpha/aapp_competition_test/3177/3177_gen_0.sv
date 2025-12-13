module swap_sort_min_steps(
  input clk,
  input rst_n,
  input start,
  input [3:0][1:0] initial_perm,  // 4 elements, values 1-4
  input [5:0][3:0] allowed_swaps, // up to 6 swaps, each {idxA[1:0],idxB[1:0]}
  input [2:0] m_swaps,            // number of valid swaps (0-6)
  output reg [3:0] min_steps,     // minimum swaps needed (0-15)
  output reg done                 // high when computation complete
);

  // States for FSM
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_POP       = 3'd2,
    S_CHECK_GOAL= 3'd3,
    S_GEN_SWAP  = 3'd4,
    S_CHECK_END = 3'd5,
    S_DONE      = 3'd6
  } state_t;

  state_t state, next_state;

  // Encoding of permutation: 4 elements * 2 bits = 8-bit code
  // queue for BFS: up to 24 permutations
  localparam int Q_SIZE = 24;

  reg [7:0] queue_perm   [0:Q_SIZE-1];
  reg [3:0] queue_dist   [0:Q_SIZE-1];
  reg [4:0] head;    // 0..24
  reg [4:0] tail;    // 0..24

  // visited bitmap for 24 possible permutations
  reg [23:0] visited;

  // current working variables
  reg [7:0] cur_perm;
  reg [3:0] cur_dist;

  // swap generation index
  reg [2:0] swap_idx;  // 0..6

  // internal wires/regs
  reg [7:0] init_code;
  reg [7:0] swapped_perm;
  reg       is_goal;
  reg       already_visited;
  reg [4:0] perm_index; // 0..23

  // Function: encode permutation (4x2b) into 8-bit code
  function automatic [7:0] encode_perm(input [3:0][1:0] p);
    encode_perm = {p[3], p[2], p[1], p[0]};
  endfunction

  // Function: decode 8-bit into permutation array (combinational, local use only)
  function automatic [3:0][1:0] decode_perm(input [7:0] code);
    decode_perm[0] = code[1:0];
    decode_perm[1] = code[3:2];
    decode_perm[2] = code[5:4];
    decode_perm[3] = code[7:6];
  endfunction

  // Function: check goal (sorted permutation 1,2,3,4 => 2'b01,10,11,100 but clipped to 2b => 1..4)
  function automatic logic is_sorted(input [7:0] code);
    // expected: 01,10,11,100(=4 -> 2'b100 but we only have 2 bits, spec states values 1-4 in 2 bits)
    // So mapping is straight 2'b01,10,11,100? In 2 bits max is 3. But spec says 1-4 in 2 bits; assume 2-bit enc: 1->00,2->01,3->10,4->11 is more typical.
    // Use canonical ascending pattern for given encoding of initial_perm.
    // To avoid encoding ambiguity, assume sorted = (1,2,3,4) as given literally:
    // values: 1->2'b01, 2->2'b10, 3->2'b11, 4->2'b00 is inconsistent, so instead simply decode and compare relationally.
    automatic [3:0][1:0] p;
    p = decode_perm(code);
    // Compare numerically using their 2-bit values, treat as 1..4 permutation, just check increasing order by numeric value
    is_sorted = (p[0] < p[1]) && (p[1] < p[2]) && (p[2] < p[3]);
  endfunction

  // Function: compute unique index (0..23) for a permutation via Lehmer code (factoradic)
  function automatic [4:0] perm_to_index(input [7:0] code);
    automatic [3:0][1:0] p;
    automatic int i,j;
    automatic int less_cnt;
    automatic int val_i, val_j;
    automatic int idx;
    p = decode_perm(code);
    idx = 0;
    // assume elements are distinct 2-bit values 0..3 representing 4 unique symbols
    for (i = 0; i < 4; i++) begin
      less_cnt = 0;
      val_i = p[i];
      for (j = i+1; j < 4; j++) begin
        val_j = p[j];
        if (val_j < val_i)
          less_cnt++;
      end
      // Factoradic weights: [3!,2!,1!,0!] = [6,2,1,1]
      case (i)
        0: idx = idx + less_cnt * 6;
        1: idx = idx + less_cnt * 2;
        2: idx = idx + less_cnt * 1;
        default: idx = idx;
      endcase
    end
    perm_to_index = idx[4:0];
  endfunction

  // Function: apply one allowed swap to a permutation code
  function automatic [7:0] apply_swap(
    input [7:0] code,
    input [3:0] swap_desc // {idxA[1:0],idxB[1:0]}
  );
    automatic [3:0][1:0] p;
    automatic [1:0] a_idx;
    automatic [1:0] b_idx;
    automatic [1:0] tmp;
    p = decode_perm(code);
    a_idx = swap_desc[3:2];
    b_idx = swap_desc[1:0];
    if (a_idx < 4 && b_idx < 4 && a_idx != b_idx) begin
      tmp = p[a_idx];
      p[a_idx] = p[b_idx];
      p[b_idx] = tmp;
    end
    apply_swap = encode_perm(p);
  endfunction

  // Combinational helper: compute goal flag for current permutation
  always @* begin
    is_goal = is_sorted(cur_perm);
  end

  // Main FSM next-state logic
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_POP;
      end

      S_POP: begin
        // If queue empty -> done, else proceed
        if (head == tail)
          next_state = S_DONE;
        else
          next_state = S_CHECK_GOAL;
      end

      S_CHECK_GOAL: begin
        if (is_goal)
          next_state = S_DONE;
        else
          next_state = S_GEN_SWAP;
      end

      S_GEN_SWAP: begin
        // iterate swaps one per cycle; when finished -> S_CHECK_END
        if (swap_idx >= m_swaps)
          next_state = S_CHECK_END;
        else
          next_state = S_GEN_SWAP;
      end

      S_CHECK_END: begin
        next_state = S_POP;
      end

      S_DONE: begin
        if (!start)
          next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  integer k;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= S_IDLE;
      head      <= 5'd0;
      tail      <= 5'd0;
      visited   <= 24'd0;
      min_steps <= 4'd0;
      done      <= 1'b0;
      cur_perm  <= 8'd0;
      cur_dist  <= 4'd0;
      swap_idx  <= 3'd0;
      for (k = 0; k < Q_SIZE; k = k + 1) begin
        queue_perm[k] <= 8'd0;
        queue_dist[k] <= 4'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // nothing else; S_INIT will set up
          end
        end

        S_INIT: begin
          // initialize BFS with initial_perm
          init_code = encode_perm(initial_perm);
          head      <= 5'd0;
          tail      <= 5'd1;
          queue_perm[0] <= init_code;
          queue_dist[0] <= 4'd0;
          visited       <= 24'd0;
          perm_index    <= perm_to_index(init_code);
          if (perm_index < 24)
            visited[perm_index] <= 1'b1;
          min_steps <= 4'd0;
          done      <= 1'b0;
        end

        S_POP: begin
          if (head == tail) begin
            // queue empty: no reachable goal, encode as 15 (max per spec)
            min_steps <= 4'd15;
            done      <= 1'b1;
          end else begin
            cur_perm <= queue_perm[head];
            cur_dist <= queue_dist[head];
            head     <= head + 5'd1;
          end
          swap_idx <= 3'd0;
        end

        S_CHECK_GOAL: begin
          if (is_goal) begin
            min_steps <= cur_dist;
            done      <= 1'b1;
          end
        end

        S_GEN_SWAP: begin
          if (!done && (swap_idx < m_swaps)) begin
            // apply one allowed swap per cycle
            swapped_perm = apply_swap(cur_perm, allowed_swaps[swap_idx]);
            perm_index   = perm_to_index(swapped_perm);
            if (perm_index < 24) begin
              already_visited = visited[perm_index];
            end else begin
              already_visited = 1'b1; // treat invalid as visited
            end

            if (!already_visited && (swapped_perm != cur_perm)) begin
              // mark visited and enqueue
              visited[perm_index] <= 1'b1;
              if (tail < Q_SIZE) begin
                queue_perm[tail] <= swapped_perm;
                queue_dist[tail] <= cur_dist + 4'd1;
                tail             <= tail + 5'd1;
              end
            end

            swap_idx <= swap_idx + 3'd1;
          end
        end

        S_CHECK_END: begin
          // No direct actions; transitions to S_POP
        end

        S_DONE: begin
          // hold result until start deasserted and asserted again
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule