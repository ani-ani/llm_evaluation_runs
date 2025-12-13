module directed_strong_connect(
  input        clk,
  input        rst_n,
  input        start,
  input  [15:0] adj_matrix,
  output reg        possible,
  output reg [15:0] directed_graph,
  output reg        done
);

  // State encoding
  localparam S_IDLE  = 2'b00;
  localparam S_SCAN  = 2'b01;
  localparam S_DONE  = 2'b10;

  reg [1:0]  state;
  reg [3:0]  edge_idx;        // 0..15 to cover all matrix positions
  reg        bridge_found;

  // Registers for BFS / connectivity check
  reg [3:0] visited;
  reg [3:0] queue;
  reg [3:0] next_queue;

  // Helper wires
  wire [1:0] r = edge_idx[3:2];
  wire [1:0] c = edge_idx[1:0];

  // Extract bit from matrix
  function automatic bit get_bit;
    input [15:0] m;
    input [1:0]  rr;
    input [1:0]  cc;
    begin
      get_bit = m[{rr,cc}];
    end
  endfunction

  // Build effective adjacency with a single edge removed (symmetrically)
  function automatic [15:0] remove_edge;
    input [15:0] m;
    input [1:0]  rr;
    input [1:0]  cc;
    reg   [15:0] t;
    begin
      t = m;
      if (rr != cc) begin
        if (m[{rr,cc}]) begin
          t[{rr,cc}] = 1'b0;
          t[{cc,rr}] = 1'b0;
        end
      end
      remove_edge = t;
    end
  endfunction

  // BFS from node 0 using effective adjacency (one edge removed)
  function automatic bit is_connected_after_removal;
    input [15:0] m;
    input [1:0]  rr;
    input [1:0]  cc;
    reg   [15:0] eff;
    reg   [3:0]  vis;
    reg   [3:0]  cur_q;
    reg   [3:0]  nxt_q;
    integer iter;
    begin
      eff   = remove_edge(m, rr, cc);
      vis   = 4'b0001; // start from node 0
      cur_q = 4'b0001;

      // Iterate up to 4 BFS layers (graph has 4 nodes)
      for (iter = 0; iter < 4; iter = iter + 1) begin
        nxt_q = 4'b0000;
        if (cur_q == 4'b0000)
          break;

        // From node 0
        if (cur_q[0]) begin
          if (eff[{2'd0,2'd1}] && !vis[1]) begin vis[1] = 1'b1; nxt_q[1] = 1'b1; end
          if (eff[{2'd0,2'd2}] && !vis[2]) begin vis[2] = 1'b1; nxt_q[2] = 1'b1; end
          if (eff[{2'd0,2'd3}] && !vis[3]) begin vis[3] = 1'b1; nxt_q[3] = 1'b1; end
        end

        // From node 1
        if (cur_q[1]) begin
          if (eff[{2'd1,2'd0}] && !vis[0]) begin vis[0] = 1'b1; nxt_q[0] = 1'b1; end
          if (eff[{2'd1,2'd2}] && !vis[2]) begin vis[2] = 1'b1; nxt_q[2] = 1'b1; end
          if (eff[{2'd1,2'd3}] && !vis[3]) begin vis[3] = 1'b1; nxt_q[3] = 1'b1; end
        end

        // From node 2
        if (cur_q[2]) begin
          if (eff[{2'd2,2'd0}] && !vis[0]) begin vis[0] = 1'b1; nxt_q[0] = 1'b1; end
          if (eff[{2'd2,2'd1}] && !vis[1]) begin vis[1] = 1'b1; nxt_q[1] = 1'b1; end
          if (eff[{2'd2,2'd3}] && !vis[3]) begin vis[3] = 1'b1; nxt_q[3] = 1'b1; end
        end

        // From node 3
        if (cur_q[3]) begin
          if (eff[{2'd3,2'd0}] && !vis[0]) begin vis[0] = 1'b1; nxt_q[0] = 1'b1; end
          if (eff[{2'd3,2'd1}] && !vis[1]) begin vis[1] = 1'b1; nxt_q[1] = 1'b1; end
          if (eff[{2'd3,2'd2}] && !vis[2]) begin vis[2] = 1'b1; nxt_q[2] = 1'b1; end
        end

        cur_q = nxt_q;
      end

      // Connected if all 4 nodes are visited (assuming original graph connected)
      is_connected_after_removal = (vis == 4'b1111);
    end
  endfunction

  // Build directed graph: all edges directed away from node 0.
  // For each undirected edge {i,j}: if i==0 -> 0->j, if j==0 -> 0->i, else i->j.
  function automatic [15:0] build_directed;
    input [15:0] m;
    reg   [15:0] d;
    begin
      d = 16'b0;
      // Edge 0-1
      if (m[{2'd0,2'd1}]) d[{2'd0,2'd1}] = 1'b1;
      // Edge 0-2
      if (m[{2'd0,2'd2}]) d[{2'd0,2'd2}] = 1'b1;
      // Edge 0-3
      if (m[{2'd0,2'd3}]) d[{2'd0,2'd3}] = 1'b1;

      // For edges not involving node 0, just pick i->j with i<j
      // Edge 1-2
      if (m[{2'd1,2'd2}]) d[{2'd1,2'd2}] = 1'b1;
      // Edge 1-3
      if (m[{2'd1,2'd3}]) d[{2'd1,2'd3}] = 1'b1;
      // Edge 2-3
      if (m[{2'd2,2'd3}]) d[{2'd2,2'd3}] = 1'b1;

      build_directed = d;
    end
  endfunction

  // Sequential control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= S_IDLE;
      edge_idx       <= 4'd0;
      bridge_found   <= 1'b0;
      possible       <= 1'b0;
      directed_graph <= 16'b0;
      done           <= 1'b0;
    end else begin
      case (state)
        S_IDLE: begin
          done         <= 1'b0;
          possible     <= 1'b0;
          bridge_found <= 1'b0;
          edge_idx     <= 4'd0;
          if (start) begin
            state <= S_SCAN;
          end
        end

        S_SCAN: begin
          // For each undirected edge (i<j), check if it's a bridge.
          // Only test once per pair when r<c.
          if (!bridge_found) begin
            if ((r < c) && get_bit(adj_matrix, r, c)) begin
              if (!is_connected_after_removal(adj_matrix, r, c)) begin
                bridge_found <= 1'b1;
              end
            end
          end

          if (edge_idx == 4'd15) begin
            // All entries processed
            if (bridge_found) begin
              possible       <= 1'b0;
              directed_graph <= 16'b0;
            end else begin
              possible       <= 1'b1;
              directed_graph <= build_directed(adj_matrix);
            end
            done   <= 1'b1;
            state  <= S_DONE;
          end else begin
            edge_idx <= edge_idx + 4'd1;
          end
        end

        S_DONE: begin
          // Hold results until start is deasserted and asserted again
          if (!start) begin
            state <= S_IDLE;
          end
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule