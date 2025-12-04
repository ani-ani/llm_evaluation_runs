module secure_telecom_network (
  input  clk,
  input  rst_n,
  input  start,                // pulse high to start
  input  [2:0] num_buildings,  // 1..8 (n)
  input  [3:0] num_edges,      // 0..16 (m)
  input  [2:0] num_insecure,   // 0..8 (p)
  input  [7:0] insecure_mask,  // [0]=bldg1 ... [7]=bldg8
  input  [2:0] edge_src[0:15], // source building per edge (1..8 mapped to 0..7)
  input  [2:0] edge_dst[0:15], // destination building per edge
  input  [15:0] edge_cost[0:15], // edge cost

  output reg [15:0] total_cost,
  output reg done
);

  // Internal state machine states
  localparam S_IDLE      = 3'b000;
  localparam S_SORT      = 3'b001;
  localparam S_SORT_WAIT = 3'b010;
  localparam S_MST       = 3'b011;
  localparam S_MST_WAIT  = 3'b100;
  localparam S_VALIDATE  = 3'b101;
  localparam S_DONE      = 3'b110;

  // Internal registers and memories
  reg [2:0] state, next_state;
  reg [7:0] cycle_counter; // counts cycles within a stage (up to 255)
  reg busy;
  reg ready_ack; // acknowledge start pulse in this cycle

  // Edge buffers
  reg [2:0]  in_src [0:15];
  reg [2:0]  in_dst [0:15];
  reg [15:0] in_cost[0:15];
  reg [2:0]  m;

  // Sorting support (insertion sort over up to 16 edges)
  reg [2:0]  sort_i, sort_j;
  reg [2:0]  s_src [0:15];
  reg [2:0]  s_dst [0:15];
  reg [15:0] s_cost[0:15];

  // Kruskal/Union-Find arrays
  reg [2:0] parent[0:7]; // union-find parent (0..7 building ids)
  reg [2:0] rankv  [0:7];
  reg [1:0] degree [0:7]; // degree counters (max 2 used for constraint; can be up to 7 if needed)
  reg [2:0] edges_used;
  reg [15:0] current_cost;
  reg find_u, find_v;
  reg [2:0] fu, fv;
  reg ru, rv;
  reg can_add_edge;
  reg [2:0] num_buildings_r; // keep a copy of n
  reg [2:0] num_insecure_r;  // keep a copy of p
  reg [7:0] insecure_mask_r; // keep a copy

  // Convenience function to check if building i is insecure
  function is_insecure;
    input [2:0] i; // 0..7
    is_insecure = insecure_mask_r[i];
  endfunction

  // Union-Find functions
  function [2:0] find_root;
    input [2:0] x;
    reg [2:0] y;
    begin
      y = x;
      while (parent[y] != y) y = parent[y];
      // Path compression
      find_root = y;
    end
  endfunction

  function is_same_set;
    input [2:0] a, b;
    is_same_set = (find_root(a) == find_root(b));
  endfunction

  function union_sets;
    input [2:0] a, b;
    reg [2:0] ra, rb;
    begin
      ra = find_root(a);
      rb = find_root(b);
      if (ra == rb) begin
        union_sets = 1'b0; // already in same set
      end else begin
        // Union by rank
        if (rankv[ra] < rankv[rb]) begin
          parent[ra] = rb;
        end else if (rankv[ra] > rankv[rb]) begin
          parent[rb] = ra;
        end else begin
          parent[rb] = ra;
          rankv[ra] = rankv[ra] + 1;
        end
        union_sets = 1'b1;
      end
    end
  endfunction

  // Edge attempt helper (assumes edge is valid wrt insecure constraints externally)
  function try_add_edge;
    input [2:0] u, v;
    reg [2:0] ru, rv;
    reg can;
    begin
      ru = find_root(u);
      rv = find_root(v);
      can = 1'b1;
      // Check cycle
      if (ru == rv) can = 1'b0;
      // Check degree constraints (insecure nodes must be degree <= 1, secure <= 7)
      if (degree[u] >= (is_insecure(u) ? 2'd1 : 2'd7)) can = 1'b0;
      if (degree[v] >= (is_insecure(v) ? 2'd1 : 2'd7)) can = 1'b0;
      // Cannot connect two insecure nodes directly (would give both degree >=1 but they become internal to each other)
      if (is_insecure(u) && is_insecure(v)) can = 1'b0;
      try_add_edge = can;
    end
  endfunction

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      busy <= 1'b0;
      done <= 1'b0;
      total_cost <= 16'hFFFF;
      edges_used <= 3'b0;
      current_cost <= 16'h0;
      cycle_counter <= 8'h00;
      ready_ack <= 1'b0;
      m <= 3'b0;
      num_buildings_r <= 3'b0;
      num_insecure_r <= 3'b0;
      insecure_mask_r <= 8'h00;
      // reset internal arrays
      for (int i=0;i<8;i++) begin
        parent[i] <= i[2:0];
        rankv[i] <= 2'b00;
        degree[i] <= 2'b00;
      end
      for (int i=0;i<16;i++) begin
        in_src[i] <= 3'b0;
        in_dst[i] <= 3'b0;
        in_cost[i] <= 16'h0;
        s_src[i] <= 3'b0;
        s_dst[i] <= 3'b0;
        s_cost[i] <= 16'h0;
      end
      sort_i <= 3'b0;
      sort_j <= 3'b0;
    end else begin
      // edge-triggered start capture
      if (start && !busy) begin
        ready_ack <= 1'b1;
      end else begin
        ready_ack <= 1'b0;
      end

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (ready_ack) begin
            // Capture inputs
            num_buildings_r <= num_buildings;
            num_insecure_r <= num_insecure;
            insecure_mask_r <= insecure_mask;
            m <= num_edges; // up to 16
            for (int i=0;i<16;i++) begin
              in_src[i] <= edge_src[i];
              in_dst[i] <= edge_dst[i];
              in_cost[i] <= edge_cost[i];
            end
            // reset DSU and counters
            for (int i=0;i<8;i++) begin
              parent[i] <= i[2:0];
              rankv[i]   <= 2'b00;
              degree[i]  <= 2'b00;
            end
            edges_used <= 3'b0;
            current_cost <= 16'h0;
            // init sorting buffers
            for (int i=0;i<16;i++) begin
              s_src[i]  <= 3'b0;
              s_dst[i]  <= 3'b0;
              s_cost[i] <= 16'hFFFF; // max cost for unused slots
            end
            // copy only valid edges into sort buffer
            for (int i=0;i<8;i++) begin // safe default; will be overwritten if m>8
              s_src[i]  <= 3'b0;
              s_dst[i]  <= 3'b0;
              s_cost[i] <= 16'hFFFF;
            end
            for (int i=0;i<16;i++) begin
              if (i < m) begin
                s_src[i]  <= in_src[i];
                s_dst[i]  <= in_dst[i];
                s_cost[i] <= in_cost[i];
              end
            end
            sort_i <= 3'b0;
            sort_j <= 3'b0;
            cycle_counter <= 8'h0;
            busy <= 1'b1;
            state <= S_SORT;
          end else begin
            state <= S_IDLE;
            busy <= 1'b0;
          end
        end

        // Stage 1: Insertion sort of up to 16 edges (stable, ascending by cost)
        S_SORT: begin
          // One compare-exchange per cycle (i,j at a time)
          if (sort_i < m) begin
            if (sort_j > 0 && s_cost[sort_j-1] > s_cost[sort_j]) begin
              // swap
              s_cost[sort_j] <= s_cost[sort_j-1];
              s_cost[sort_j-1] <= s_cost[sort_j]; // will fix below
            end
          end
          state <= S_SORT_WAIT;
        end
        S_SORT_WAIT: begin
          // perform swap correctly on this cycle (handles the compare result from S_SORT)
          if (sort_i < m) begin
            if (sort_j > 0 && s_cost[sort_j-1] > s_cost[sort_j]) begin
              // swap elements j-1 and j
              s_src[sort_j]  <= s_src[sort_j-1];
              s_dst[sort_j]  <= s_dst[sort_j-1];
              s_cost[sort_j] <= s_cost[sort_j-1];

              s_src[sort_j-1]  <= s_src[sort_j];
              s_dst[sort_j-1]  <= s_dst[sort_j];
              s_cost[sort_j-1] <= s_cost[sort_j];
            end
            if (sort_j < (m-1)) begin
              sort_j <= sort_j + 1;
              state <= S_SORT;
            end else begin
              sort_j <= 3'b0;
              sort_i <= sort_i + 1;
              state <= S_SORT;
            end
          end else begin
            // Sort complete, move to MST processing
            sort_i <= 3'b0;
            sort_j <= 3'b0;
            cycle_counter <= 8'h0;
            state <= S_MST;
          end
        end

        // Stage 2: Kruskal-like MST construction with constraints
        S_MST: begin
          if (edges_used < (num_buildings_r - 1)) begin
            if (cycle_counter < m) begin
              // Attempt to add sorted edge cycle_counter
              // Evaluate quickly on combinatorial path but add on next cycle to keep timing simple
              find_u <= 1'b1; find_v <= 1'b1;
              fu <= s_src[cycle_counter];
              fv <= s_dst[cycle_counter];
              ru <= find_root(fu);
              rv <= find_root(fv);
              // precompute can_add_edge
              can_add_edge <= 1'b0;
              if (ru != rv) begin // not same set
                if (degree[fu] < (is_insecure(fu) ? 2'd1 : 2'd7) && degree[fv] < (is_insecure(fv) ? 2'd1 : 2'd7)) begin
                  if (!(is_insecure(fu) && is_insecure(fv))) begin
                    can_add_edge <= 1'b1;
                  end
                end
              end
              state <= S_MST_WAIT;
            end else begin
              // processed all edges, but not enough edges to connect -> fail
              total_cost <= 16'hFFFF;
              done <= 1'b1;
              state <= S_DONE;
            end
          end else begin
            // enough edges picked -> go to validation
            state <= S_VALIDATE;
          end
        end
        S_MST_WAIT: begin
          if (can_add_edge) begin
            // Add edge: union sets and update degrees/cost
            // Update DSU
            if (union_sets(fu, fv)) begin
              // Increase degrees
              degree[fu] <= degree[fu] + 1;
              degree[fv] <= degree[fv] + 1;
              current_cost <= current_cost + s_cost[cycle_counter];
              edges_used <= edges_used + 1;
            end
          end
          // advance to next edge
          cycle_counter <= cycle_counter + 1;
          state <= S_MST;
        end

        // Stage 3: Validate connectivity and insecure constraints
        S_VALIDATE: begin
          // Check if all nodes are connected and insecure nodes have degree 1 (or 0 allowed only if p==0)
          // quick checks: for each node i>0, must be in same set as 0
          // Also, if p>0, ensure every insecure node has degree >=1
          // We'll do a small iterative test in this stage (single cycle pass is OK with combinational checks)
          reg ok;
          reg [2:0] r0;
          ok = 1'b1;
          r0 = find_root(3'b0);
          for (int i=1;i<8;i++) begin
            if (i < num_buildings_r) begin
              if (find_root(i) != r0) ok = 1'b0;
            end
          end
          // insecure degree check
          if (ok) begin
            for (int i=0;i<8;i++) begin
              if (is_insecure(i)) begin
                if (num_insecure_r > 0) begin
                  if (degree[i] == 2'b00) ok = 1'b0; // insecure must be connected
                end
                // Also ensure not violating leaf constraint (should never happen due to can_add_edge gating)
                if (degree[i] > 2'd1) ok = 1'b0;
              end
            end
          end
          if (ok) begin
            total_cost <= current_cost;
            done <= 1'b1;
            state <= S_DONE;
          end else begin
            total_cost <= 16'hFFFF;
            done <= 1'b1;
            state <= S_DONE;
          end
        end

        S_DONE: begin
          // Hold done for one cycle or until new start; this implementation holds done high until a new start arrives.
          if (start) begin
            // if a new start comes in during DONE, go back to IDLE to relatch inputs
            state <= S_IDLE;
            busy <= 1'b0;
          end else begin
            state <= S_DONE;
            busy <= 1'b0;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end

endmodule
