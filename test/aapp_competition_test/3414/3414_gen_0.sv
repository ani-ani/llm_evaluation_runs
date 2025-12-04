module min_turning_circuit(
  input clk,
  input rst_n,
  input start,
  input [3:0] node_count,
  input [3:0] edge_count,
  input [15:0] node_x [0:7],
  input [15:0] node_y [0:7],
  input [2:0] edges [0:15][0:1],
  output reg [31:0] min_angle,
  output reg done
);

  // ---------------------------------------------------------------------------
  // Parameters and localparams
  // ---------------------------------------------------------------------------
  localparam Q = 16;                 // Q16.16 fractional bits
  localparam ONE = 32'd1 << Q;       // 1.0 in Q16.16
  localparam PI  = 32'd205887;       // ~3.141592 * 2^16 (approx)
  localparam TWO_PI = 32'd411775;    // ~6.283185 * 2^16 (approx)

  localparam S_IDLE      = 3'd0;
  localparam S_INIT      = 3'd1;
  localparam S_PREP      = 3'd2;
  localparam S_SEARCH    = 3'd3;
  localparam S_EVAL      = 3'd4;
  localparam S_DONE      = 3'd5;

  // ---------------------------------------------------------------------------
  // Internal storage
  // ---------------------------------------------------------------------------

  // Edge endpoints (flattened for convenience)
  // edges[i][0] = start node, edges[i][1] = end node
  reg [2:0] edge_u [0:15];
  reg [2:0] edge_v [0:15];

  // Precomputed edge direction angles at each node.
  // For each edge e and local direction (0 = u->v, 1 = v->u), store outgoing angle.
  // angle[e][dir] in Q16.16, range [-PI, PI].
  reg [31:0] edge_angle [0:15][0:1];

  // For each node, list incident edges and directions (dir=0 if node is u, 1 if node is v).
  // Max degree 4 per spec; store up to 4 edges per node.
  reg [3:0] node_deg   [0:7];
  reg [3:0] node_edge_index [0:7][0:3];
  reg       node_edge_dir   [0:7][0:3];

  // Eulerian circuit search state
  reg [3:0] used_edge [0:15];   // simple usage flags (0=unused, 1=used)

  reg [4:0] path_pos;           // up to 16 edges (0..15)
  reg [3:0] path_edge [0:16];   // store edge index for each step
  reg       path_rev  [0:16];   // store direction: 0 = forward (u->v), 1 = reverse (v->u)

  // Stack-based DFS for brute force enumeration
  // At each depth d, we store which option index we are exploring.
  reg [2:0] choice_idx [0:16]; // up to 4 incident edges per node (3 bits suffice)

  reg [31:0] current_turn_sum;
  reg [31:0] best_turn_sum;
  reg        best_valid;

  reg [2:0] state, next_state;

  // Counters for preparation / search
  integer i, j;

  // ---------------------------------------------------------------------------
  // Fixed-point helper functions
  // ---------------------------------------------------------------------------

  // Fixed-point absolute value
  function automatic [31:0] qabs(input [31:0] x);
    begin
      if (x[31]) qabs = -x; else qabs = x;
    end
  endfunction

  // Normalize angle to [-PI, PI]
  function automatic [31:0] norm_angle(input [31:0] ang);
    reg signed [31:0] a;
    begin
      a = ang;
      // bring into (-2PI,2PI) crudely
      if (a >  TWO_PI) a = a - TWO_PI;
      if (a < -TWO_PI) a = a + TWO_PI;
      // then into [-PI,PI]
      if (a >  PI) a = a - TWO_PI;
      else if (a < -PI) a = a + TWO_PI;
      norm_angle = a;
    end
  endfunction

  // atan2 approximation returning Q16.16 in [-PI, PI]
  // Piecewise polynomial approximation (sufficient for this context)
  function automatic [31:0] atan2_q16(input signed [31:0] y, input signed [31:0] x);
    reg signed [31:0] ax, ay, r, angle;
    reg signed [31:0] c1, c2;
    reg signed [31:0] pi_q, pi_half_q;
    reg signed [31:0] num, den;
    begin
      pi_q      = PI;
      pi_half_q = PI >>> 1; // PI/2
      c1 = 32'sd51472;      // ~0.785398*2^16 (pi/4)
      c2 = 32'sd19065;      // ~0.290, tuned coefficient
      ax = (x[31]) ? -x : x;
      ay = (y[31]) ? -y : y;

      if (ax == 0 && ay == 0) begin
        angle = 32'sd0;
      end else begin
        if (ax >= ay) begin
          // r = y/x in Q16.16
          if (x != 0) begin
            num = (y <<< Q);
            den = x;
            r = num / den;
          end else begin
            r = 32'sd0;
          end
          angle = r * c2;
          angle = angle >>> Q;
          angle = angle + c1;
        end else begin
          // r = x/y
          if (y != 0) begin
            num = (x <<< Q);
            den = y;
            r = num / den;
          end else begin
            r = 32'sd0;
          end
          angle = r * c2;
          angle = angle >>> Q;
          angle = pi_half_q - angle;
        end

        // quadrant corrections
        if (x < 0 && y >= 0) begin
          // QII
          angle = pi_q - angle;
        end else if (x < 0 && y < 0) begin
          // QIII
          angle = angle - pi_q;
        end else if (x >= 0 && y < 0) begin
          // QIV
          angle = -angle;
        end
      end
      atan2_q16 = angle;
    end
  endfunction

  // Compute angle of vector from (x1,y1) to (x2,y2)
  function automatic [31:0] edge_dir_angle(
    input [15:0] x1,
    input [15:0] y1,
    input [15:0] x2,
    input [15:0] y2
  );
    reg signed [31:0] dx, dy;
    begin
      dx = $signed({1'b0,x2}) - $signed({1'b0,x1});
      dy = $signed({1'b0,y2}) - $signed({1'b0,y1});
      // Treat inputs as already Q16.16 scaled positions
      edge_dir_angle = atan2_q16(dy, dx);
    end
  endfunction

  // Turning angle between two directed edges (prev -> curr) sharing a node.
  function automatic [31:0] turn_angle(
    input [31:0] prev_ang,
    input [31:0] curr_ang
  );
    reg signed [31:0] d;
    begin
      d = $signed(curr_ang) - $signed(prev_ang);
      d = norm_angle(d);
      turn_angle = qabs(d);
    end
  endfunction

  // ---------------------------------------------------------------------------
  // Synchronous state register
  // ---------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      done        <= 1'b0;
      min_angle   <= 32'hFFFFFFFF;
      best_turn_sum <= 32'hFFFFFFFF;
      best_valid  <= 1'b0;
    end else begin
      state <= next_state;
    end
  end

  // ---------------------------------------------------------------------------
  // Main FSM and datapath
  // ---------------------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // reset all runtime regs
      for (i = 0; i < 16; i = i + 1) begin
        used_edge[i] <= 4'd0;
        edge_u[i]    <= 3'd0;
        edge_v[i]    <= 3'd0;
        edge_angle[i][0] <= 32'd0;
        edge_angle[i][1] <= 32'd0;
      end
      for (i = 0; i < 8; i = i + 1) begin
        node_deg[i] <= 4'd0;
        for (j = 0; j < 4; j = j + 1) begin
          node_edge_index[i][j] <= 4'd0;
          node_edge_dir[i][j]   <= 1'b0;
        end
      end
      for (i = 0; i <= 16; i = i + 1) begin
        path_edge[i]  <= 4'd0;
        path_rev[i]   <= 1'b0;
        choice_idx[i] <= 3'd0;
      end
      path_pos         <= 5'd0;
      current_turn_sum <= 32'd0;
      done             <= 1'b0;
      min_angle        <= 32'hFFFFFFFF;
      best_turn_sum    <= 32'hFFFFFFFF;
      best_valid       <= 1'b0;

    end else begin
      case (state)
        // -------------------------------------------------------------------
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize containers
            for (i = 0; i < 8; i = i + 1) begin
              node_deg[i] <= 4'd0;
              for (j = 0; j < 4; j = j + 1) begin
                node_edge_index[i][j] <= 4'd0;
                node_edge_dir[i][j]   <= 1'b0;
              end
            end
            for (i = 0; i < edge_count; i = i + 1) begin
              edge_u[i] <= edges[i][0];
              edge_v[i] <= edges[i][1];
              used_edge[i] <= 4'd0;
            end
            best_turn_sum <= 32'hFFFFFFFF;
            best_valid    <= 1'b0;
            min_angle     <= 32'hFFFFFFFF;
          end
        end

        // -------------------------------------------------------------------
        // Build node incidence lists and precompute edge angles (multi-cycle)
        // -------------------------------------------------------------------
        S_INIT: begin
          // Build degree and adjacency lists
          for (i = 0; i < edge_count; i = i + 1) begin
            // for u endpoint
            node_edge_index[edge_u[i]][node_deg[edge_u[i]]] <= i[3:0];
            node_edge_dir[edge_u[i]][node_deg[edge_u[i]]]   <= 1'b0; // dir 0: u->v
            node_deg[edge_u[i]] <= node_deg[edge_u[i]] + 1'b1;

            // for v endpoint
            node_edge_index[edge_v[i]][node_deg[edge_v[i]]] <= i[3:0];
            node_edge_dir[edge_v[i]][node_deg[edge_v[i]]]   <= 1'b1; // dir 1: v->u
            node_deg[edge_v[i]] <= node_deg[edge_v[i]] + 1'b1;
          end
        end

        S_PREP: begin
          // Precompute directional angles for each edge
          for (i = 0; i < edge_count; i = i + 1) begin
            edge_angle[i][0] <= edge_dir_angle(
              node_x[edge_u[i]], node_y[edge_u[i]],
              node_x[edge_v[i]], node_y[edge_v[i]]
            );
            edge_angle[i][1] <= edge_dir_angle(
              node_x[edge_v[i]], node_y[edge_v[i]],
              node_x[edge_u[i]], node_y[edge_u[i]]
            );
          end

          // Initialize DFS from edge 0, direction 0 (arbitrary start for Eulerian circuit)
          path_pos            <= 5'd0;
          path_edge[0]        <= 4'd0;
          path_rev[0]         <= 1'b0;
          used_edge[0]        <= 4'd1;
          choice_idx[0]       <= 3'd0;
          current_turn_sum    <= 32'd0;
        end

        // -------------------------------------------------------------------
        // Depth-first brute force enumeration of Eulerian circuits
        // -------------------------------------------------------------------
        S_SEARCH: begin
          if (path_pos == edge_count - 1) begin
            // All edges used; check closure at starting node
            // Last edge end should match start of first edge to form a circuit
            reg [2:0] start_s, start_e;
            reg       start_dir;
            reg [2:0] last_s, last_e;
            reg       last_dir;
            reg [2:0] start_node, last_node;
            reg [31:0] last_ang, first_ang, ta;

            start_s   = edge_u[path_edge[0]];
            start_e   = edge_v[path_edge[0]];
            start_dir = path_rev[0];
            start_node = (start_dir == 1'b0) ? start_s : start_e;

            last_s    = edge_u[path_edge[path_pos]];
            last_e    = edge_v[path_edge[path_pos]];
            last_dir  = path_rev[path_pos];
            last_node = (last_dir == 1'b0) ? last_e : last_s;

            if (last_node == start_node) begin
              // Optionally include turning between last and first for full circuit
              last_ang  = edge_angle[path_edge[path_pos]][last_dir];
              first_ang = edge_angle[path_edge[0]][path_rev[0]];
              ta = turn_angle(last_ang, first_ang);

              if (current_turn_sum + ta < best_turn_sum) begin
                best_turn_sum <= current_turn_sum + ta;
                best_valid    <= 1'b1;
              end
            end

            // Backtrack
            if (path_pos == 0) begin
              // search finished
            end else begin
              used_edge[path_edge[path_pos]] <= 4'd0;
              path_pos <= path_pos - 1'b1;
            end

          end else begin
            // Extend path from current node
            reg [2:0] cur_s, cur_e;
            reg       cur_dir;
            reg [2:0] cur_node;
            reg [2:0] idx;
            reg       found_next;
            reg [3:0] eidx;
            reg       edir;
            reg [31:0] prev_ang, next_ang, ta;

            cur_s   = edge_u[path_edge[path_pos]];
            cur_e   = edge_v[path_edge[path_pos]];
            cur_dir = path_rev[path_pos];
            cur_node = (cur_dir == 1'b0) ? cur_e : cur_s;

            found_next = 1'b0;
            idx = choice_idx[path_pos];

            while (idx < node_deg[cur_node] && !found_next) begin
              eidx = node_edge_index[cur_node][idx];
              edir = node_edge_dir[cur_node][idx];

              if (!used_edge[eidx]) begin
                // choose this edge as next
                found_next = 1'b1;
                choice_idx[path_pos] <= idx + 1'b1;

                // set next step
                path_pos <= path_pos + 1'b1;
                path_edge[path_pos + 1'b1] <= eidx[3:0];
                // direction is such that we leave cur_node
                if (edir == 1'b0) begin
                  // node is u -> direction 0 means from u to v, ok
                  path_rev[path_pos + 1'b1] <= 1'b0;
                end else begin
                  // node is v -> direction 1 means from v to u
                  path_rev[path_pos + 1'b1] <= 1'b1;
                end
                used_edge[eidx] <= 4'd1;

                // update turning sum
                prev_ang = edge_angle[path_edge[path_pos]][path_rev[path_pos]];
                next_ang = edge_angle[eidx][path_rev[path_pos + 1'b1]];
                ta = turn_angle(prev_ang, next_ang);
                current_turn_sum <= current_turn_sum + ta;

                // reset choice index for new depth
                choice_idx[path_pos + 1'b1] <= 3'd0;
              end else begin
                idx = idx + 1'b1;
              end
            end

            if (!found_next) begin
              // no extension found -> backtrack
              if (path_pos == 0) begin
                // root backtracked -> done handled in next_state logic
              end else begin
                // subtract last turn contribution when backing up
                reg [31:0] back_prev_ang, back_curr_ang, back_ta;
                back_prev_ang = edge_angle[path_edge[path_pos-1]][path_rev[path_pos-1]];
                back_curr_ang = edge_angle[path_edge[path_pos]][path_rev[path_pos]];
                back_ta = turn_angle(back_prev_ang, back_curr_ang);
                if (current_turn_sum >= back_ta)
                  current_turn_sum <= current_turn_sum - back_ta;
                else
                  current_turn_sum <= 32'd0;

                used_edge[path_edge[path_pos]] <= 4'd0;
                path_pos <= path_pos - 1'b1;
              end
            end
          end
        end

        // -------------------------------------------------------------------
        S_EVAL: begin
          if (best_valid) begin
            min_angle <= best_turn_sum;
          end else begin
            min_angle <= 32'hFFFFFFFF;
          end
        end

        // -------------------------------------------------------------------
        S_DONE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Next state logic (purely combinational)
  // ---------------------------------------------------------------------------
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_INIT;
      end
      S_INIT: begin
        next_state = S_PREP;
      end
      S_PREP: begin
        next_state = S_SEARCH;
      end
      S_SEARCH: begin
        // Finish when backtracked from root with no more choices
        if (path_pos == 0 && choice_idx[0] >= node_deg[(path_rev[0] ? edge_v[path_edge[0]] : edge_u[path_edge[0]])]) begin
          next_state = S_EVAL;
        end
      end
      S_EVAL: begin
        next_state = S_DONE;
      end
      S_DONE: begin
        if (!start) next_state = S_IDLE;
      end
      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule