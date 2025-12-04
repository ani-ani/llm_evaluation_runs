module lang_divider (
  input clk,
  input rst_n,
  input start,
  input [1:0] n,
  input [1:0] m,
  input [15:0] grid_data,
  output reg valid,
  output reg [15:0] lang_a,
  output reg [15:0] lang_b,
  output reg [15:0] lang_c,
  output reg impossible_flag
);

  // State machine
  typedef enum logic [1:0] {S_IDLE=2'b00, S_CHECK=2'b01, S_DONE=2'b10} state_t;
  state_t state, next_state;
  reg [1:0] pattern_idx;
  integer i, j, k;

  // Internal masks per pattern (16-bit per language, row-major in lower n*m bits)
  logic [15:0] patA[3];
  logic [15:0] patB[3];
  logic [15:0] patC[3];

  // Masks that match grid_data bits
  logic [15:0] ones_mask;   // cells where grid_data bit == 1
  logic [15:0] twos_mask;   // cells where grid_data bit == 2 (we encode 2 as 2'b10)
  logic [15:0] active_mask; // valid cells based on n,m (n rows x m cols)

  // Working masks for the currently checked pattern
  logic [15:0] curA, curB, curC;
  logic [15:0] cur1, cur2;

  // BFS queue (max 16 entries)
  logic [4:0] q[16];
  logic [4:0] q_head, q_tail;
  logic [15:0] visited;
  logic [15:0] frontier, next_frontier;
  logic [4:0] comp_count;
  logic [4:0] bfs_index;

  // Helpers: build active cell mask for n rows and m cols
  function [15:0] active_cells(input [1:0] rn, input [1:0] cn);
    integer r, c;
    active_cells = 16'b0;
    for (r = 0; r < 4; r++) begin
      for (c = 0; c < 4; c++) begin
        if (r < rn && c < cn) begin
          active_cells[(r*4)+c] = 1'b1;
        end
      end
    end
  endfunction

  // Pattern 1: vertical thirds -> A=left cols, B=center cols, C=right cols
  function [47:0] pattern1_masks(input [1:0] rn, input [1:0] cn);
    integer r, c;
    logic [15:0] A, B, C;
    A = 16'b0; B = 16'b0; C = 16'b0;
    for (r = 0; r < 4; r++) begin
      for (c = 0; c < 4; c++) begin
        if (r < rn && c < cn) begin
          if (c < (cn/3))       A[(r*4)+c] = 1'b1;
          else if (c < (2*cn/3)) B[(r*4)+c] = 1'b1;
          else                   C[(r*4)+c] = 1'b1;
        end
      end
    end
    pattern1_masks = {A, B, C};
  endfunction

  // Pattern 2: horizontal thirds -> A=top rows, B=middle rows, C=bottom rows
  function [47:0] pattern2_masks(input [1:0] rn, input [1:0] cn);
    integer r, c;
    logic [15:0] A, B, C;
    A = 16'b0; B = 16'b0; C = 16'b0;
    for (r = 0; r < 4; r++) begin
      for (c = 0; c < 4; c++) begin
        if (r < rn && c < cn) begin
          if (r < (rn/3))       A[(r*4)+c] = 1'b1;
          else if (r < (2*rn/3)) B[(r*4)+c] = 1'b1;
          else                   C[(r*4)+c] = 1'b1;
        end
      end
    end
    pattern2_masks = {A, B, C};
  endfunction

  // Pattern 3: border vs inner -> A=border, B=inner (C unused)
  function [48:0] pattern3_masks(input [1:0] rn, input [1:0] cn);
    integer r, c;
    logic [15:0] A, B;
    A = 16'b0; B = 16'b0;
    for (r = 0; r < 4; r++) begin
      for (c = 0; c < 4; c++) begin
        if (r < rn && c < cn) begin
          if (r==0 || r==(rn-1) || c==0 || c==(cn-1)) A[(r*4)+c] = 1'b1;
          else                                         B[(r*4)+c] = 1'b1;
        end
      end
    end
    pattern3_masks = {A, B, 16'b0};
  endfunction

  // BFS over cells within a mask; return 1 if they form a single connected component
  function connectivity_ok(input [15:0] mask, input [15:0] active);
    logic [15:0] local_active;
    logic [4:0] q_loc[16];
    logic [4:0] head_loc, tail_loc;
    logic [15:0] visited_loc, frontier_loc, next_frontier_loc;
    logic [4:0] comps;
    integer qi;
    if (mask == 16'b0) begin
      connectivity_ok = 1'b1; // no cells, trivially connected
      return;
    end
    local_active = mask & active;
    if (local_active == 16'b0) begin
      connectivity_ok = 1'b0; // mask has 1s but none are active (shouldn't happen)
      return;
    end
    // Find first set bit as start
    for (i = 0; i < 16; i++) begin
      if (local_active[i]) begin
        q_loc[0] = i[4:0];
        head_loc = 5'd0;
        tail_loc = 5'd1;
        break;
      end
    end
    visited_loc = 16'b0;
    visited_loc[q_loc[0]] = 1'b1;
    comps = 5'd0;
    // Count connected components within mask
    while (1) begin
      comps = comps + 1;
      frontier_loc = 16'b0;
      frontier_loc[q_loc[head_loc]] = 1'b1;
      // BFS from the queue start index head_loc
      while (head_loc != tail_loc) begin
        bfs_index = q_loc[head_loc];
        head_loc = head_loc + 1;
        // Explore neighbors in 4 directions (only within the 4x4 grid)
        // Left neighbor
        if (bfs_index % 5 != 0) begin
          i = bfs_index - 1;
          if (local_active[i] && !visited_loc[i]) begin
            visited_loc[i] = 1'b1;
            q_loc[tail_loc] = i;
            tail_loc = tail_loc + 1;
          end
        end
        // Right neighbor
        if ((bfs_index % 5) != 4) begin
          i = bfs_index + 1;
          if (local_active[i] && !visited_loc[i]) begin
            visited_loc[i] = 1'b1;
            q_loc[tail_loc] = i;
            tail_loc = tail_loc + 1;
          end
        end
        // Up neighbor
        if (bfs_index >= 5) begin
          i = bfs_index - 5;
          if (local_active[i] && !visited_loc[i]) begin
            visited_loc[i] = 1'b1;
            q_loc[tail_loc] = i;
            tail_loc = tail_loc + 1;
          end
        end
        // Down neighbor
        if (bfs_index < 11) begin // 4x4 grid, last row starts at 12, so < 12 implies a down neighbor exists
          i = bfs_index + 5;
          if (local_active[i] && !visited_loc[i]) begin
            visited_loc[i] = 1'b1;
            q_loc[tail_loc] = i;
            tail_loc = tail_loc + 1;
          end
        end
      end // end while head != tail
      // After finishing a component, if there are still unvisited mask bits, start a new component
      next_frontier_loc = local_active & (~visited_loc);
      if (next_frontier_loc == 16'b0) break;
      // find first unvisited bit
      for (qi = 0; qi < 16; qi++) begin
        if (next_frontier_loc[qi]) begin
          q_loc[0] = qi[4:0];
          head_loc = 5'd0;
          tail_loc = 5'd1;
          visited_loc[qi] = 1'b1;
          break;
        end
      end
    end // end counting components
    connectivity_ok = (comps == 5'd1);
  endfunction

  // Combinational evaluation of the current pattern candidate
  logic ok_cur;
  logic bits1_exist, bits2_exist, twos_two_langs;
  logic [15:0] bits2_A, bits2_B, bits2_C;
  logic [1:0] twos_count;

  always_comb begin
    // Precompute masks for the three patterns
    {patA[0], patB[0], patC[0]} = pattern1_masks(n, m);
    {patA[1], patB[1], patC[1]} = pattern2_masks(n, m);
    {patA[2], patB[2], patC[2]} = pattern3_masks(n, m);

    // Active cells and input 1/2 masks
    active_mask = active_cells(n, m);
    ones_mask  =  grid_data & active_mask; // where input has 1s
    twos_mask  = ({16{grid_data[1]}} & active_mask); // bit 1 set => value 2

    // Select current pattern by pattern_idx
    curA = patA[pattern_idx];
    curB = patB[pattern_idx];
    curC = patC[pattern_idx];

    cur1 = ones_mask;
    cur2 = twos_mask;

    // Check language rules for this pattern
    // Condition: If 1s exist -> only one language among {A,B,C} has ones; if 2s exist -> at least two languages among {A,B,C} have twos
    bits1_exist = (cur1 != 16'b0);
    bits2_exist = (cur2 != 16'b0);

    bits2_A = cur2 & curA;
    bits2_B = cur2 & curB;
    bits2_C = cur2 & curC;
    twos_count = ($countbits(bits2_A, 1'b1) > 0) + ($countbits(bits2_B, 1'b1) > 0) + ($countbits(bits2_C, 1'b1) > 0);
    twos_two_langs = (twos_count >= 2);

    // If both 1s and 2s are present, evaluate both constraints; if only one is present, only its constraint applies
    ok_cur = 1'b1;
    if (bits1_exist) begin
      // Count languages that have at least one 1 in their region
      logic [1:0] cnt1;
      cnt1 = ($countbits(cur1 & curA, 1'b1) > 0) + ($countbits(cur1 & curB, 1'b1) > 0) + ($countbits(cur1 & curC, 1'b1) > 0);
      ok_cur = (cnt1 == 1);
    end
    if (bits2_exist && ok_cur) begin
      ok_cur = twos_two_langs;
    end

    // Connectivity: each language that has at least one cell assigned (in 1s or 2s) must be a single connected region
    if (ok_cur) begin
      logic maskA, maskB, maskC;
      logic conA, conB, conC;
      maskA = ((cur1 & curA) != 16'b0) || ((cur2 & curA) != 16'b0);
      maskB = ((cur1 & curB) != 16'b0) || ((cur2 & curB) != 16'b0);
      maskC = ((cur1 & curC) != 16'b0) || ((cur2 & curC) != 16'b0);
      conA = connectivity_ok((cur1 & curA) | (cur2 & curA), active_mask);
      conB = connectivity_ok((cur1 & curB) | (cur2 & curB), active_mask);
      conC = connectivity_ok((cur1 & curC) | (cur2 & curC), active_mask);
      ok_cur = ( (!maskA || conA) && (!maskB || conB) && (!maskC || conC) );
    end
  end

  // State updates
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      pattern_idx <= 2'd0;
      valid <= 1'b0;
      lang_a <= 16'b0;
      lang_b <= 16'b0;
      lang_c <= 16'b0;
      impossible_flag <= 1'b0;
    end else begin
      case (state)
        S_IDLE: begin
          valid <= 1'b0;
          impossible_flag <= 1'b0;
          lang_a <= 16'b0;
          lang_b <= 16'b0;
          lang_c <= 16'b0;
          pattern_idx <= 2'd0;
          if (start) state <= S_CHECK;
        end
        S_CHECK: begin
          if (ok_cur) begin
            // Output encodings: 1 -> '1' for that language; 2 -> '1' for that language
            lang_a <= (ones_mask & curA) | (twos_mask & curA);
            lang_b <= (ones_mask & curB) | (twos_mask & curB);
            lang_c <= (ones_mask & curC) | (twos_mask & curC);
            valid <= 1'b1;
            impossible_flag <= 1'b0;
            state <= S_DONE;
          end else begin
            if (pattern_idx < 2'd2) begin
              pattern_idx <= pattern_idx + 1;
            end else begin
              // No valid pattern
              valid <= 1'b0;
              impossible_flag <= 1'b1;
              state <= S_DONE;
            end
          end
        end
        S_DONE: begin
          // Hold outputs stable; wait for start deassert to return to IDLE
          if (!start) state <= S_IDLE;
        end
        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
