module minimal_tunnel_cost(
  input clk,
  input rst_n,
  input start,
  input signed [7:0] x [0:3],
  input signed [7:0] y [0:3],
  input signed [7:0] z [0:3],
  output reg [9:0] total_cost,
  output reg done
);

  // Internal registers
  reg [5:0] cycle_cnt;
  reg running;

  // Coordinate latches
  reg signed [7:0] x_l [0:3];
  reg signed [7:0] y_l [0:3];
  reg signed [7:0] z_l [0:3];

  // Edge cost regs (6 edges)
  reg [5:0] edge_cost [0:5];

  // Edge index structs (encoded as {u[1:0], v[1:0]})
  reg [3:0] edge_uv [0:5];

  // Union-Find parent array for 4 nodes
  reg [1:0] parent [0:3];

  // Selected MST edge count and accumulated cost
  reg [1:0] mst_edges;
  reg [9:0] mst_cost;

  // State encoding
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_LATCH  = 3'd1,
    S_GEN    = 3'd2,
    S_SORT   = 3'd3,
    S_MST    = 3'd4,
    S_WAIT   = 3'd5,
    S_DONE   = 3'd6
  } state_t;

  state_t state, next_state;

  // Helper function: absolute value of signed 8-bit
  function automatic [7:0] abs8(input signed [7:0] v);
    begin
      abs8 = (v[7]) ? (~v + 1'b1) : v;
    end
  endfunction

  // Helper: min of three 8-bit values (result fits in 6 bits for |diff| <= 255)
  function automatic [5:0] min3_8_to6(
    input [7:0] a,
    input [7:0] b,
    input [7:0] c
  );
    reg [7:0] m1;
    reg [7:0] m2;
    begin
      m1 = (a < b) ? a : b;
      m2 = (m1 < c) ? m1 : c;
      min3_8_to6 = m2[5:0];
    end
  endfunction

  // Union-Find: find with simple 2-level path compression (sufficient for N=4)
  function automatic [1:0] uf_find(
    input [1:0] n,
    input [1:0] p0,
    input [1:0] p1,
    input [1:0] p2,
    input [1:0] p3
  );
    reg [1:0] p;
    begin
      case (n)
        2'd0: p = p0;
        2'd1: p = p1;
        2'd2: p = p2;
        default: p = p3;
      endcase
      if (p == n) begin
        uf_find = n;
      end else begin
        case (p)
          2'd0: uf_find = p0;
          2'd1: uf_find = p1;
          2'd2: uf_find = p2;
          default: uf_find = p3;
        endcase
      end
    end
  endfunction

  // Sequential state / counter / main control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      running     <= 1'b0;
      cycle_cnt   <= 6'd0;
      total_cost  <= 10'd0;
      done        <= 1'b0;
      mst_cost    <= 10'd0;
      mst_edges   <= 2'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          total_cost <= 10'd0;
          mst_cost   <= 10'd0;
          mst_edges  <= 2'd0;
          running    <= 1'b0;
          cycle_cnt  <= 6'd0;
          if (start) begin
            running   <= 1'b1;
          end
        end

        S_LATCH: begin
          // Latch inputs once at start
          x_l[0] <= x[0]; x_l[1] <= x[1]; x_l[2] <= x[2]; x_l[3] <= x[3];
          y_l[0] <= y[0]; y_l[1] <= y[1]; y_l[2] <= y[2]; y_l[3] <= y[3];
          z_l[0] <= z[0]; z_l[1] <= z[1]; z_l[2] <= z[2]; z_l[3] <= z[3];

          // Initialize cycle counter
          cycle_cnt <= 6'd1;
        end

        S_GEN: begin
          // Generate all 6 edges costs
          // Edge indices: 0:(0,1),1:(0,2),2:(0,3),3:(1,2),4:(1,3),5:(2,3)
          edge_uv[0] <= {2'd0,2'd1};
          edge_uv[1] <= {2'd0,2'd2};
          edge_uv[2] <= {2'd0,2'd3};
          edge_uv[3] <= {2'd1,2'd2};
          edge_uv[4] <= {2'd1,2'd3};
          edge_uv[5] <= {2'd2,2'd3};

          edge_cost[0] <= min3_8_to6(
                            abs8(x_l[0]-x_l[1]),
                            abs8(y_l[0]-y_l[1]),
                            abs8(z_l[0]-z_l[1]));
          edge_cost[1] <= min3_8_to6(
                            abs8(x_l[0]-x_l[2]),
                            abs8(y_l[0]-y_l[2]),
                            abs8(z_l[0]-z_l[2]));
          edge_cost[2] <= min3_8_to6(
                            abs8(x_l[0]-x_l[3]),
                            abs8(y_l[0]-y_l[3]),
                            abs8(z_l[0]-z_l[3]));
          edge_cost[3] <= min3_8_to6(
                            abs8(x_l[1]-x_l[2]),
                            abs8(y_l[1]-y_l[2]),
                            abs8(z_l[1]-z_l[2]));
          edge_cost[4] <= min3_8_to6(
                            abs8(x_l[1]-x_l[3]),
                            abs8(y_l[1]-y_l[3]),
                            abs8(z_l[1]-z_l[3]));
          edge_cost[5] <= min3_8_to6(
                            abs8(x_l[2]-x_l[3]),
                            abs8(y_l[2]-y_l[3]),
                            abs8(z_l[2]-z_l[3]));

          cycle_cnt <= cycle_cnt + 6'd1;
        end

        S_SORT: begin
          // Simple fixed-sequence bubble sort for 6 edges (network-like),
          // executed over multiple cycles using running counter.
          // We'll perform compare-swap passes until a fixed number reached.
          // For simplicity and determinism, do one pass step per cycle.

          // We use cycle_cnt steps to walk through a predetermined set
          // of compare-swap operations. After enough steps, array is sorted.

          // Local temporaries
          reg [5:0] c0, c1;
          reg [3:0] u0, u1;

          c0 = 6'd0; // avoid latches (dummy init)
          c1 = 6'd0;
          u0 = 4'd0;
          u1 = 4'd0;

          // Map step index to pair (i,i+1)
          // We'll unroll 5 bubble passes: 5+4+3+2+1 = 15 comparisons.
          // cycle_cnt from previous states is at least 2; offset internally.
          // Use a local step index starting at 0 when entering S_SORT.

          // step = cycle_cnt_sort (0..14)
          // We'll derive by subtracting entry base (which is 2 after S_GEN).

          // Because SystemVerilog does not allow dynamic subtraction inside
          // case labels easily, we'll just use cycle_cnt directly assuming:
          // At entry: cycle_cnt == 2. We'll schedule compares for 15 cycles:
          // cycles 2..16 inclusive.

          if (cycle_cnt >= 6'd2 && cycle_cnt <= 6'd16) begin
            case (cycle_cnt - 6'd2)
              6'd0:  begin c0 = edge_cost[0]; c1 = edge_cost[1]; u0 = edge_uv[0]; u1 = edge_uv[1]; if (c0 > c1) begin edge_cost[0]<=c1; edge_cost[1]<=c0; edge_uv[0]<=u1; edge_uv[1]<=u0; end end
              6'd1:  begin c0 = edge_cost[1]; c1 = edge_cost[2]; u0 = edge_uv[1]; u1 = edge_uv[2]; if (c0 > c1) begin edge_cost[1]<=c1; edge_cost[2]<=c0; edge_uv[1]<=u1; edge_uv[2]<=u0; end end
              6'd2:  begin c0 = edge_cost[2]; c1 = edge_cost[3]; u0 = edge_uv[2]; u1 = edge_uv[3]; if (c0 > c1) begin edge_cost[2]<=c1; edge_cost[3]<=c0; edge_uv[2]<=u1; edge_uv[3]<=u0; end end
              6'd3:  begin c0 = edge_cost[3]; c1 = edge_cost[4]; u0 = edge_uv[3]; u1 = edge_uv[4]; if (c0 > c1) begin edge_cost[3]<=c1; edge_cost[4]<=c0; edge_uv[3]<=u1; edge_uv[4]<=u0; end end
              6'd4:  begin c0 = edge_cost[4]; c1 = edge_cost[5]; u0 = edge_uv[4]; u1 = edge_uv[5]; if (c0 > c1) begin edge_cost[4]<=c1; edge_cost[5]<=c0; edge_uv[4]<=u1; edge_uv[5]<=u0; end end

              6'd5:  begin c0 = edge_cost[0]; c1 = edge_cost[1]; u0 = edge_uv[0]; u1 = edge_uv[1]; if (c0 > c1) begin edge_cost[0]<=c1; edge_cost[1]<=c0; edge_uv[0]<=u1; edge_uv[1]<=u0; end end
              6'd6:  begin c0 = edge_cost[1]; c1 = edge_cost[2]; u0 = edge_uv[1]; u1 = edge_uv[2]; if (c0 > c1) begin edge_cost[1]<=c1; edge_cost[2]<=c0; edge_uv[1]<=u1; edge_uv[2]<=u0; end end
              6'd7:  begin c0 = edge_cost[2]; c1 = edge_cost[3]; u0 = edge_uv[2]; u1 = edge_uv[3]; if (c0 > c1) begin edge_cost[2]<=c1; edge_cost[3]<=c0; edge_uv[2]<=u1; edge_uv[3]<=u0; end end
              6'd8:  begin c0 = edge_cost[3]; c1 = edge_cost[4]; u0 = edge_uv[3]; u1 = edge_uv[4]; if (c0 > c1) begin edge_cost[3]<=c1; edge_cost[4]<=c0; edge_uv[3]<=u1; edge_uv[4]<=u0; end end

              6'd9:  begin c0 = edge_cost[0]; c1 = edge_cost[1]; u0 = edge_uv[0]; u1 = edge_uv[1]; if (c0 > c1) begin edge_cost[0]<=c1; edge_cost[1]<=c0; edge_uv[0]<=u1; edge_uv[1]<=u0; end end
              6'd10: begin c0 = edge_cost[1]; c1 = edge_cost[2]; u0 = edge_uv[1]; u1 = edge_uv[2]; if (c0 > c1) begin edge_cost[1]<=c1; edge_cost[2]<=c0; edge_uv[1]<=u1; edge_uv[2]<=u0; end end
              6'd11: begin c0 = edge_cost[2]; c1 = edge_cost[3]; u0 = edge_uv[2]; u1 = edge_uv[3]; if (c0 > c1) begin edge_cost[2]<=c1; edge_cost[3]<=c0; edge_uv[2]<=u1; edge_uv[3]<=u0; end end

              6'd12: begin c0 = edge_cost[0]; c1 = edge_cost[1]; u0 = edge_uv[0]; u1 = edge_uv[1]; if (c0 > c1) begin edge_cost[0]<=c1; edge_cost[1]<=c0; edge_uv[0]<=u1; edge_uv[1]<=u0; end end
              6'd13: begin c0 = edge_cost[1]; c1 = edge_cost[2]; u0 = edge_uv[1]; u1 = edge_uv[2]; if (c0 > c1) begin edge_cost[1]<=c1; edge_cost[2]<=c0; edge_uv[1]<=u1; edge_uv[2]<=u0; end end

              6'd14: begin c0 = edge_cost[0]; c1 = edge_cost[1]; u0 = edge_uv[0]; u1 = edge_uv[1]; if (c0 > c1) begin edge_cost[0]<=c1; edge_cost[1]<=c0; edge_uv[0]<=u1; edge_uv[1]<=u0; end end

              default: ;
            endcase
          end

          cycle_cnt <= cycle_cnt + 6'd1;
        end

        S_MST: begin
          // Perform Kruskal MST over sorted edges.
          // Implemented sequentially over 6 cycles.

          // Local copies of parents
          reg [1:0] p0, p1, p2, p3;
          reg [1:0] u, v;
          reg [1:0] ru, rv;
          reg [2:0] idx;

          p0 = parent[0];
          p1 = parent[1];
          p2 = parent[2];
          p3 = parent[3];

          idx = cycle_cnt - 6'd17; // expect MST starts when cycle_cnt==17
          if (idx < 3'd6 && mst_edges < 2'd3) begin
            u = edge_uv[idx][3:2];
            v = edge_uv[idx][1:0];

            ru = uf_find(u, p0, p1, p2, p3);
            rv = uf_find(v, p0, p1, p2, p3);

            if (ru != rv) begin
              // Union: attach rv root to ru root
              case (rv)
                2'd0: p0 = ru;
                2'd1: p1 = ru;
                2'd2: p2 = ru;
                2'd3: p3 = ru;
              endcase

              mst_cost  <= mst_cost + edge_cost[idx];
              mst_edges <= mst_edges + 2'd1;
            end

            parent[0] <= p0;
            parent[1] <= p1;
            parent[2] <= p2;
            parent[3] <= p3;
          end

          cycle_cnt <= cycle_cnt + 6'd1;
        end

        S_WAIT: begin
          // Wait until 50 cycles from start
          if (cycle_cnt < 6'd50)
            cycle_cnt <= cycle_cnt + 6'd1;
        end

        S_DONE: begin
          done       <= 1'b1;
          total_cost <= mst_cost;
          running    <= 1'b0;
          // Hold values until next reset/start
        end

        default: ;
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_LATCH;
      end

      S_LATCH: begin
        next_state = S_GEN;
      end

      S_GEN: begin
        next_state = S_SORT;
      end

      S_SORT: begin
        // After finishing 15 compare-swap steps (cycles 2..16), move to MST.
        if (cycle_cnt > 6'd16)
          next_state = S_MST;
      end

      S_MST: begin
        // After examining all 6 edges or reaching 3 MST edges, go to WAIT.
        if ( (cycle_cnt > 6'd22) || (mst_edges == 2'd3) )
          next_state = S_WAIT;
      end

      S_WAIT: begin
        if (cycle_cnt >= 6'd50)
          next_state = S_DONE;
      end

      S_DONE: begin
        // Stay done until a new start with reset, or optionally restart on start
        // Here we require external reset to restart, as spec emphasizes reset.
        next_state = S_DONE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Initialize Union-Find parents when entering MST
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      parent[0] <= 2'd0;
      parent[1] <= 2'd1;
      parent[2] <= 2'd2;
      parent[3] <= 2'd3;
    end else begin
      if (state == S_SORT && next_state == S_MST) begin
        parent[0] <= 2'd0;
        parent[1] <= 2'd1;
        parent[2] <= 2'd2;
        parent[3] <= 2'd3;
        mst_cost  <= 10'd0;
        mst_edges <= 2'd0;
        // Align MST start cycle to current cycle_cnt (expected 17)
      end
    end
  end

endmodule