module pipe_clean_scheduler(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] num_wells,
  input  [2:0] num_pipes,
  input  [15:0] well_x [0:7],
  input  [15:0] well_y [0:7],
  input  [2:0] pipe_start [0:7],
  input  [15:0] pipe_end_x [0:7],
  input  [15:0] pipe_end_y [0:7],
  output reg result,
  output reg done
);

  // Internal signals
  reg [2:0] N; // number of pipes (1-8), latched

  // adjacency matrix: adj[i][j] = 1 if pipe i intersects pipe j (i != j)
  reg [7:0] adj [0:7];

  // colors: 0 = uncolored, 1 or 2 = two colors
  reg [1:0] color [0:7];

  // BFS queue for up to 8 nodes
  reg [2:0] q_mem [0:7];
  reg [2:0] q_head;
  reg [2:0] q_tail;
  reg [3:0] q_count;

  // State machine
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT_ADJ  = 3'd1,
    S_BUILD_ADJ = 3'd2,
    S_BIP_INIT  = 3'd3,
    S_BIP_OUTER = 3'd4,
    S_BIP_BFS   = 3'd5,
    S_DONE      = 3'd6
  } state_t;

  state_t state, next_state;

  // indices for adjacency construction
  reg [2:0] i_idx, j_idx;

  // latched pipe geometry info (integer coordinates)
  reg [11:0] sx_int [0:7];
  reg [11:0] sy_int [0:7];
  reg [11:0] ex_int [0:7];
  reg [11:0] ey_int [0:7];

  // temp values for intersection computation
  reg signed [12:0] ax, ay, bx, by, cx, cy, dx, dy;
  reg signed [25:0] c1, c2, c3, c4;
  reg inter_res;
  reg calculating_intersection;

  // bipartite check variables
  reg [2:0] u_node;
  reg [2:0] v_node;
  reg [2:0] outer_idx;
  reg found_conflict;

  // helper wires/functions
  function automatic signed [25:0] cross_z(
    input signed [12:0] vx1,
    input signed [12:0] vy1,
    input signed [12:0] vx2,
    input signed [12:0] vy2
  );
    begin
      cross_z = vx1 * vy2 - vy1 * vx2;
    end
  endfunction

  // compute orientation cross product (B-A) x (P-A)
  function automatic signed [25:0] orient(
    input signed [12:0] ax_f,
    input signed [12:0] ay_f,
    input signed [12:0] bx_f,
    input signed [12:0] by_f,
    input signed [12:0] px_f,
    input signed [12:0] py_f
  );
    begin
      orient = cross_z(bx_f - ax_f, by_f - ay_f, px_f - ax_f, py_f - ay_f);
    end
  endfunction

  // check if point P lies on segment A-B (inclusive) assuming colinear
  function automatic bit on_segment(
    input signed [12:0] ax_f,
    input signed [12:0] ay_f,
    input signed [12:0] bx_f,
    input signed [12:0] by_f,
    input signed [12:0] px_f,
    input signed [12:0] py_f
  );
    begin
      on_segment = (px_f >= (ax_f < bx_f ? ax_f : bx_f)) &&
                   (px_f <= (ax_f > bx_f ? ax_f : bx_f)) &&
                   (py_f >= (ay_f < by_f ? ay_f : by_f)) &&
                   (py_f <= (ay_f > by_f ? ay_f : by_f));
    end
  endfunction

  // check if two pipes share the same start well (shared node => allowed, not conflict)
  function automatic bit share_start_well(
    input [2:0] i,
    input [2:0] j
  );
    begin
      share_start_well = (pipe_start[i] == pipe_start[j]);
    end
  endfunction

  // synchronous state and control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      result <= 1'b0;
      done <= 1'b0;
      N <= 3'd0;
      i_idx <= 3'd0;
      j_idx <= 3'd0;
      outer_idx <= 3'd0;
      q_head <= 3'd0;
      q_tail <= 3'd0;
      q_count <= 4'd0;
      found_conflict <= 1'b0;
      calculating_intersection <= 1'b0;
      u_node <= 3'd0;
      v_node <= 3'd0;
    end else begin
      state <= next_state;

      // default outputs
      done <= 1'b0;

      case (state)
        S_IDLE: begin
          if (start) begin
            // latch number of pipes (constrain to 1..8, treat 0 as 0 pipes)
            N <= (num_pipes > 3'd7) ? 3'd7 : num_pipes;

            // latch coordinates as integers: use only upper 12 bits (ignore frac)
            // For wells: used only to detect shared wells logically via pipe_start, so no action
            // For pipes: start from well_x/ well_y via pipe_start, end from pipe_end_x/y
            integer pi;
            for (pi = 0; pi < 8; pi = pi + 1) begin
              // start coordinates from associated well
              sx_int[pi] <= well_x[ pipe_start[pi] ][15:4];
              sy_int[pi] <= well_y[ pipe_start[pi] ][15:4];
              // end coordinates directly
              ex_int[pi] <= pipe_end_x[pi][15:4];
              ey_int[pi] <= pipe_end_y[pi][15:4];
            end

            // clear adjacency
            integer r;
            for (r = 0; r < 8; r = r + 1) begin
              adj[r] <= 8'b0;
            end

            i_idx <= 3'd0;
            j_idx <= 3'd1;
            calculating_intersection <= 1'b0;
          end
        end

        S_INIT_ADJ: begin
          // adjacency already cleared in IDLE when start, nothing extra here
        end

        S_BUILD_ADJ: begin
          if (!calculating_intersection) begin
            // setup operands for intersection between pipes i_idx and j_idx
            ax <= $signed({1'b0, sx_int[i_idx]});
            ay <= $signed({1'b0, sy_int[i_idx]});
            bx <= $signed({1'b0, ex_int[i_idx]});
            by <= $signed({1'b0, ey_int[i_idx]});
            cx <= $signed({1'b0, sx_int[j_idx]});
            cy <= $signed({1'b0, sy_int[j_idx]});
            dx <= $signed({1'b0, ex_int[j_idx]});
            dy <= $signed({1'b0, ey_int[j_idx]});
            calculating_intersection <= 1'b1;
          end else begin
            // perform intersection test in this cycle
            // if pipes share same start well, we ignore as non-conflicting
            if (!share_start_well(i_idx, j_idx)) begin
              c1 = orient(ax, ay, bx, by, cx, cy);
              c2 = orient(ax, ay, bx, by, dx, dy);
              c3 = orient(cx, cy, dx, dy, ax, ay);
              c4 = orient(cx, cy, dx, dy, bx, by);

              inter_res = 1'b0;

              // general case
              if (((c1 > 0 && c2 < 0) || (c1 < 0 && c2 > 0)) &&
                  ((c3 > 0 && c4 < 0) || (c3 < 0 && c4 > 0))) begin
                inter_res = 1'b1;
              end else begin
                // colinear and on-segment cases
                if (c1 == 0 && on_segment(ax, ay, bx, by, cx, cy)) inter_res = 1'b1;
                else if (c2 == 0 && on_segment(ax, ay, bx, by, dx, dy)) inter_res = 1'b1;
                else if (c3 == 0 && on_segment(cx, cy, dx, dy, ax, ay)) inter_res = 1'b1;
                else if (c4 == 0 && on_segment(cx, cy, dx, dy, bx, by)) inter_res = 1'b1;
              end

              // If intersection exists and it's not from shared start well, mark adjacency
              if (inter_res) begin
                adj[i_idx][j_idx] <= 1'b1;
                adj[j_idx][i_idx] <= 1'b1;
              end
            end

            // advance indices
            calculating_intersection <= 1'b0;
            if (j_idx + 3'd1 < N) begin
              j_idx <= j_idx + 3'd1;
            end else begin
              if (i_idx + 3'd2 < N) begin
                i_idx <= i_idx + 3'd1;
                j_idx <= (i_idx + 3'd1) + 3'd1; // new j = i+2 (but will be corrected below)
              end else begin
                // finished all pairs
                i_idx <= i_idx;
                j_idx <= j_idx;
              end
            end
          end
        end

        S_BIP_INIT: begin
          // initialize coloring and BFS vars
          integer ci;
          for (ci = 0; ci < 8; ci = ci + 1) begin
            color[ci] <= 2'd0;
          end
          found_conflict <= 1'b0;
          outer_idx <= 3'd0;
          q_head <= 3'd0;
          q_tail <= 3'd0;
          q_count <= 4'd0;
        end

        S_BIP_OUTER: begin
          // In this state we may start BFS for an uncolored node
          if (outer_idx < N) begin
            if (color[outer_idx] == 2'd0) begin
              // start BFS from this node with color 1
              color[outer_idx] <= 2'd1;
              q_mem[0] <= outer_idx;
              q_head <= 3'd0;
              q_tail <= 3'd1;
              q_count <= 4'd1;
            end
          end
        end

        S_BIP_BFS: begin
          if (q_count != 0 && !found_conflict) begin
            // dequeue u_node
            u_node <= q_mem[q_head];
            q_head <= q_head + 3'd1;
            q_count <= q_count - 4'd1;

            // scan all neighbors
            for (v_node = 0; v_node < 8; v_node = v_node + 1) begin
              if (v_node < N && adj[u_node][v_node]) begin
                if (color[v_node] == 2'd0) begin
                  // assign opposite color and enqueue
                  color[v_node] <= (color[u_node] == 2'd1) ? 2'd2 : 2'd1;
                  q_mem[q_tail] <= v_node;
                  q_tail <= q_tail + 3'd1;
                  q_count <= q_count + 4'd1;
                end else if (color[v_node] == color[u_node]) begin
                  found_conflict <= 1'b1;
                end
              end
            end
          end
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // next state logic
  always @(*) begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start) begin
          next_state = S_INIT_ADJ;
        end
      end

      S_INIT_ADJ: begin
        // move immediately to adjacency build if N > 1
        if (N <= 3'd1) begin
          // no edges possible, graph trivially bipartite
          next_state = S_BIP_INIT;
        end else begin
          next_state = S_BUILD_ADJ;
        end
      end

      S_BUILD_ADJ: begin
        // terminate when finished all i<j pairs
        if (!calculating_intersection) begin
          if (N <= 3'd1) begin
            next_state = S_BIP_INIT;
          end else if (i_idx >= N - 3'd1 && j_idx >= N) begin
            next_state = S_BIP_INIT;
          end
        end
      end

      S_BIP_INIT: begin
        next_state = S_BIP_OUTER;
      end

      S_BIP_OUTER: begin
        if (outer_idx >= N) begin
          // done with all nodes
          next_state = S_DONE;
        end else if (color[outer_idx] == 2'd0) begin
          // need BFS from this new component
          next_state = S_BIP_BFS;
        end else begin
          // already colored, go to next outer index
          next_state = S_BIP_OUTER;
        end
      end

      S_BIP_BFS: begin
        if (found_conflict) begin
          next_state = S_DONE;
        end else if (q_count == 0) begin
          // finished BFS for this component, move to next node
          next_state = S_BIP_OUTER;
        end else begin
          // continue BFS
          next_state = S_BIP_BFS;
        end
      end

      S_DONE: begin
        // result based on whether conflict found
        // combinational assignment below
        next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // result logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 1'b0;
    end else begin
      if (state == S_DONE) begin
        result <= ~found_conflict;
      end
    end
  end

endmodule