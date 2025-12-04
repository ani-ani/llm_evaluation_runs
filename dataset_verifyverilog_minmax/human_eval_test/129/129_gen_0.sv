module min_path(
  input clk,
  input rst_n,
  input start,
  input [3:0] grid [0:3][0:3],
  input [3:0] k,
  output reg [63:0] path,
  output reg done
);
  // 4x4 grid, 4-bit per cell, unique values 1..16, minimal path unique

  localparam S_IDLE  = 3'd0;
  localparam S_SEARCH= 3'd1;
  localparam S_COMPARE=3'd2;
  localparam S_UPDATE= 3'd3;
  localparam S_DONE  = 3'd4;

  reg [2:0] state, next_state;

  // DFS stack (max path length = 16)
  reg [63:0] stack_path [0:15];
  reg [4:0]  stack_ptr;
  reg [4:0]  stack_used [0:15];
  reg [3:0]  stack_len [0:15];
  reg [3:0]  next_dir [0:15]; // 0..3 => up,right,down,left
  reg [4:0]  cur_index; // current cell (linear index 0..15)
  reg [63:0] cur_path;  // packed path, LSB = oldest cell
  reg [4:0]  cur_used;  // 16-bit mask packed in 5 bits (bit i => row*4+i visited)
  reg [3:0]  cur_len;   // current path length (cells visited)
  reg [3:0]  best_len;  // length of best found (should equal k when done)
  reg [63:0] best_path; // best lexicographic path

  // linear index helpers
  function [4:0] to_index;
    input [1:0] r, c;
    begin
      to_index = {r, c}; // r*4 + c (r,c are 2-bit)
    end
  endfunction

  function [1:0] idx_row;
    input [4:0] idx;
    begin
      idx_row = idx[4:3];
    end
  endfunction

  function [1:0] idx_col;
    input [4:0] idx;
    begin
      idx_col = idx[1:0];
    end
  endfunction

  // update path (append v to LSB side so that LSBs hold least recent cell)
  function [63:0] append_path;
    input [63:0] p;
    input [3:0]  v;
    begin
      append_path = {p[59:0], v};
    end
  endfunction

  // lexicographic compare on cell values (most significant cell first)
  // return 1 if candidate < best, else 0
  function lex_less;
    input [63:0] cand;
    input [3:0]  len_cand;
    input [63:0] best;
    input [3:0]  len_best;
    integer i;
    reg [3:0] vc, vb;
    begin
      lex_less = 1'b0;
      for (i = 15; i >= 0; i = i - 1) begin
        if (i < len_cand) vc = cand[(i*4)+:4]; else vc = 4'h0;
        if (i < len_best) vb = best[(i*4)+:4]; else vb = 4'h0;
        if (vc < vb) begin
          lex_less = 1'b1;
          break;
        end else if (vc > vb) begin
          lex_less = 1'b0;
          break;
        end
      end
    end
  endfunction

  // neighbor direction encoding: 0=up,1=right,2=down,3=left
  // direction delta for (dr,dc)
  function [1:0] dr_of_dir;
    input [3:0] d;
    begin
      case (d)
        2'd0: dr_of_dir = 2'b11; // -1 (wrap for unsigned)
        2'd1: dr_of_dir = 2'b00; // 0
        2'd2: dr_of_dir = 2'b01; // +1
        2'd3: dr_of_dir = 2'b00; // 0
        default: dr_of_dir = 2'b00;
      endcase
    end
  endfunction

  function [1:0] dc_of_dir;
    input [3:0] d;
    begin
      case (d)
        2'd0: dc_of_dir = 2'b00; // 0
        2'd1: dc_of_dir = 2'b01; // +1
        2'd2: dc_of_dir = 2'b00; // 0
        2'd3: dc_of_dir = 2'b11; // -1 (wrap for unsigned)
        default: dc_of_dir = 2'b00;
      endcase
    end
  endfunction

  // 0..3 ordered by grid value (lex smallest neighbor first)
  function [3:0] cand_dir;
    input [3:0] n; // 0..3
    begin
      case (n)
        4'd0: cand_dir = 4'd0; // up
        4'd1: cand_dir = 4'd1; // right
        4'd2: cand_dir = 4'd2; // down
        4'd3: cand_dir = 4'd3; // left
        default: cand_dir = 4'd0;
      endcase
    end
  endfunction

  function [3:0] neighbor_value;
    input [4:0] idx;
    input [3:0] d;
    reg [1:0] r, c, rn, cn;
    begin
      r = idx_row(idx);
      c = idx_col(idx);
      rn = r + dr_of_dir(d);
      cn = c + dc_of_dir(d);
      neighbor_value = grid[rn][cn];
    end
  endfunction

  function is_inside;
    input [4:0] idx;
    input [3:0] d;
    reg [1:0] r, c, rn, cn;
    begin
      r = idx_row(idx);
      c = idx_col(idx);
      rn = r + dr_of_dir(d);
      cn = c + dc_of_dir(d);
      // inside 0..3 check using unsigned ranges
      is_inside = (rn[1:0] == rn) && (cn[1:0] == cn) && (rn <= 2'd3) && (cn <= 2'd3);
    end
  endfunction

  function [4:0] neighbor_index;
    input [4:0] idx;
    input [3:0] d;
    reg [1:0] r, c, rn, cn;
    begin
      r = idx_row(idx);
      c = idx_col(idx);
      rn = r + dr_of_dir(d);
      cn = c + dc_of_dir(d);
      neighbor_index = to_index(rn, cn);
    end
  endfunction

  function is_visited;
    input [4:0] used;
    input [4:0] idx;
    begin
      is_visited = used[idx[0]]; // bit 0 used as LSB marker; mapping not used
    end
  endfunction

  // Because is_visited uses only bit 0 (incorrect), correct it properly:
  // Override with a correct bit-extract: bit position equals linear index.
  function is_visited_proper;
    input [4:0] used; // We'll use 16-bit vector packed into lower 16 bits of a reg externally
    input [4:0] idx;
    reg [15:0] used_vec;
    begin
      used_vec = used;
      is_visited_proper = used_vec[idx];
    end
  endfunction

  // State machine sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done <= 1'b0;
      path <= 64'd0;
    end else begin
      state <= next_state;
      case (next_state)
        S_IDLE: begin
          done <= 1'b0;
          path <= 64'd0;
        end
        S_DONE: begin
          done <= 1'b1;
          path <= best_path;
        end
        default: begin
          // retain outputs in SEARCH/COMPARE/UPDATE
        end
      endcase
    end
  end

  // Combinational next-state and datapath
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) begin
          // Initialize DFS
          stack_ptr = 5'd0;
          best_len = 4'd0;
          best_path = 64'd0;
          cur_len = 4'd0;
          cur_used = 5'd0; // We'll use 16-bit vector in a separate reg
          cur_path = 64'd0;
          cur_index = 5'd0;
          next_state = S_SEARCH;
        end else begin
          next_state = S_IDLE;
        end
      end

      S_SEARCH: begin
        if (cur_len == k) begin
          next_state = S_COMPARE;
        end else if (stack_ptr == 5'd0 && cur_len == 4'd0) begin
          // Root: try all start cells (choose lex smallest first by value)
          // Build list of (value, index) for 0..15 and sort by value
          // We implement 16-entry network here
          reg [7:0] vals [0:15];
          reg [4:0] inds [0:15];
          reg [7:0] v0,v1,v2,v3,v4,v5,v6,v7,v8,v9,v10,v11,v12,v13,v14,v15;
          reg [4:0] i0,i1,i2,i3,i4,i5,i6,i7,i8,i9,i10,i11,i12,i13,i14,i15;
          integer m, n;
          // Initialize arrays
          for (m=0; m<16; m=m+1) begin
            vals[m] = {4'd0, grid[m/4][m%4]};
            inds[m] = m;
          end
          // Simple bubble sort by value (8-bit value)
          for (m=0; m<16; m=m+1) begin
            for (n=0; n<15-m; n=n+1) begin
              if (vals[n] > vals[n+1]) begin
                v0 = vals[n]; vals[n] = vals[n+1]; vals[n+1] = v0;
                i0 = inds[n]; inds[n] = inds[n+1]; inds[n+1] = i0;
              end
            end
          end
          // Pick lex smallest start cell first (smallest grid value)
          cur_index = inds[0];
          cur_len = 4'd1;
          cur_path = append_path(64'd0, grid[cur_index/4][cur_index%4]);
          cur_used = (16'd1 << cur_index);
          stack_ptr = 5'd1;
          stack_path[0] = cur_path;
          stack_used[0] = cur_used;
          stack_len[0] = cur_len;
          next_dir[0] = 4'd0;
          next_state = S_SEARCH;
        end else begin
          // Explore next neighbor from current position
          if (next_dir[stack_ptr-5'd1] >= 4'd4) begin
            // backtrack
            if (stack_ptr == 5'd1) begin
              // finished this start cell, go to next start cell if any remain
              if (cur_len == 4'd1 && best_len == 4'd0) begin
                next_state = S_SEARCH; // continue to next start cell
              end else begin
                next_state = S_DONE;
              end
            end else begin
              // Restore previous state from stack and continue
              stack_ptr = stack_ptr - 5'd1;
              cur_path = stack_path[stack_ptr-5'd1];
              cur_used = stack_used[stack_ptr-5'd1];
              cur_len  = stack_len[stack_ptr-5'd1];
              cur_index= (cur_len == 4'd0) ? 5'd0 : stack_path[stack_ptr-5'd1][3:0]; // not used when len=0
              next_state = S_SEARCH;
            end
          end else begin
            // consider next candidate in lex order
            // but first, we may have come from a restore; need to re-evaluate
            // We will compute the next neighbor to try
            reg [3:0] d;
            reg [4:0] nidx;
            reg [15:0] used_vec;
            reg [3:0] order [0:3];
            integer j, oi, oj;
            reg [3:0] cand_vals [0:3];
            reg [3:0] cand_dirs [0:3];
            reg found_valid;
            // build candidate list with valid moves only
            for (j=0; j<4; j=j+1) begin
              order[j] = j;
              cand_vals[j] = 4'd0;
              cand_dirs[j] = cand_dir(j);
            end
            for (j=0; j<4; j=j+1) begin
              for (oi=j+1; oi<4; oi=oi+1) begin
                if (cand_vals[order[j]] > cand_vals[order[oi]]) begin
                  order[j] <= order[oi];
                  order[oi] <= order[j];
                end
              end
            end
            // Actually, we need value-based sort; fill cand_vals first
            for (j=0; j<4; j=j+1) begin
              d = cand_dir(j);
              if (is_inside(cur_index, d)) begin
                nidx = neighbor_index(cur_index, d);
                used_vec = cur_used;
                if (!used_vec[nidx]) begin
                  cand_vals[j] = grid[idx_row(nidx)][idx_col(nidx)];
                end else begin
                  cand_vals[j] = 4'd15; // visited => high value to deprioritize
                end
              end else begin
                cand_vals[j] = 4'd15; // outside => high value
              end
            end
            // sort order by cand_vals (stable)
            for (j=0; j<4; j=j+1) begin
              for (oi=j+1; oi<4; oi=oi+1) begin
                if (cand_vals[order[j]] > cand_vals[order[oi]]) begin
                  order[j] <= order[oi];
                  order[oi] <= order[j];
                end
              end
            end
            // advance next_dir to next valid neighbor in lex order
            found_valid = 1'b0;
            for (j=0; j<4; j=j+1) begin
              d = cand_dir(order[j]);
              if (is_inside(cur_index, d)) begin
                nidx = neighbor_index(cur_index, d);
                used_vec = cur_used;
                if (!used_vec[nidx]) begin
                  found_valid = 1'b1;
                  // Commit this move next cycle
                  next_dir[stack_ptr-5'd1] = d;
                  // Push new state
                  stack_path[stack_ptr] = cur_path;
                  stack_used[stack_ptr] = cur_used | (16'd1 << nidx);
                  stack_len[stack_ptr] = cur_len + 4'd1;
                  next_dir[stack_ptr]   = 4'd0;
                  // Update current
                  cur_path = append_path(cur_path, grid[idx_row(nidx)][idx_col(nidx)]);
                  cur_used = cur_used | (16'd1 << nidx);
                  cur_len  = cur_len + 4'd1;
                  cur_index= nidx;
                  stack_ptr= stack_ptr + 5'd1;
                  next_state = S_SEARCH;
                end
              end
            end
            if (!found_valid) begin
              // No more neighbors; backtrack by setting next_dir beyond 3 and handle in next cycle
              next_dir[stack_ptr-5'd1] = 4'd4;
              next_state = S_SEARCH;
            end
          end
        end
      end

      S_COMPARE: begin
        // cur_path length == k; compare with best
        if (best_len == 4'd0 || lex_less(cur_path, k, best_path, best_len)) begin
          best_len  = k;
          best_path = cur_path;
          next_state = S_UPDATE;
        end else begin
          next_state = S_SEARCH;
        end
      end

      S_UPDATE: begin
        next_state = S_SEARCH;
      end

      S_DONE: begin
        next_state = start ? S_DONE : S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end
endmodule
