module spanning_tree_k_blue (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [3:0] m,
  input [2:0] k,
  input [15:0][7:0] edges,
  output reg result,
  output reg done
);
  // Constants
  localparam MAX_N = 8;
  localparam MAX_M = 16;
  localparam LATENCY = 32; // fixed pipeline latency

  // State/utility signals
  reg [5:0] timer;
  reg busy;
  reg started;
  reg [5:0] nxt_timer;
  reg nxt_busy, nxt_done, nxt_started;
  reg [3:0] blue_used_min, blue_used_max;
  reg [3:0] nxt_blue_min, nxt_blue_max;
  integer i;

  // Union-Find: Min-blue (favor Red)
  reg [2:0] uf_min_parent[MAX_N];
  reg [2:0] uf_min_rank[MAX_N];
  // Union-Find: Max-blue (favor Blue)
  reg [2:0] uf_max_parent[MAX_N];
  reg [2:0] uf_max_rank[MAX_N];

  // Find with path compression (function)
  function [2:0] find_min (input [2:0] x);
    if (uf_min_parent[x] != x) begin
      uf_min_parent[x] = find_min(uf_min_parent[x]);
    end
    return uf_min_parent[x];
  endfunction

  function [2:0] find_max (input [2:0] x);
    if (uf_max_parent[x] != x) begin
      uf_max_parent[x] = find_max(uf_max_parent[x]);
    end
    return uf_max_parent[x];
  endfunction

  // Union by rank
  task union_min;
    input [2:0] a, b;
    reg [2:0] ra, rb;
  begin
    ra = find_min(a);
    rb = find_min(b);
    if (ra != rb) begin
      if (uf_min_rank[ra] < uf_min_rank[rb]) begin
        uf_min_parent[ra] = rb;
      end else if (uf_min_rank[ra] > uf_min_rank[rb]) begin
        uf_min_parent[rb] = ra;
      end else begin
        uf_min_parent[rb] = ra;
        uf_min_rank[ra] = uf_min_rank[ra] + 1;
      end
    end
  end
  endtask

  task union_max;
    input [2:0] a, b;
    reg [2:0] ra, rb;
  begin
    ra = find_max(a);
    rb = find_max(b);
    if (ra != rb) begin
      if (uf_max_rank[ra] < uf_max_rank[rb]) begin
        uf_max_parent[ra] = rb;
      end else if (uf_max_rank[ra] > uf_max_rank[rb]) begin
        uf_max_parent[rb] = ra;
      end else begin
        uf_max_parent[rb] = ra;
        uf_max_rank[ra] = uf_max_rank[ra] + 1;
      end
    end
  end
  endtask

  // Main control + pipeline
  always_comb begin
    // Defaults
    nxt_timer = timer;
    nxt_busy = busy;
    nxt_done = done;
    nxt_started = started;
    nxt_blue_min = blue_used_min;
    nxt_blue_max = blue_used_max;

    if (timer < 6'd31) nxt_timer = timer + 1; // wrap to 0 at 32nd tick
    else nxt_timer = 6'd0;

    // On start of computation
    if (start) begin
      nxt_busy = 1'b1;
      nxt_done = 1'b0;
      nxt_started = 1'b1;
      nxt_timer = 6'd0;
      // Initialize DSU structures for this run
      for (i = 0; i < MAX_N; i = i + 1) begin
        uf_min_parent[i] = i[2:0];
        uf_min_rank[i] = 3'd0;
        uf_max_parent[i] = i[2:0];
        uf_max_rank[i] = 3'd0;
      end
      nxt_blue_min = 4'd0;
      nxt_blue_max = 4'd0;
    end else begin
      // Per-cycle edge processing in first 16 cycles
      if (busy && timer < 6'd16) begin
        // Use same iteration index as cycle number for edge selection
        if (i < m) begin
          bit [7:0] byte;
          reg is_blue;
          reg [2:0] node0, node1;
          byte = edges[i];
          is_blue = byte[7];
          node0 = byte[2:0];
          node1 = byte[5:3];

          // Max-blue: prefer blue edges first
          if (is_blue) begin
            reg [2:0] r0, r1;
            r0 = find_max(node0);
            r1 = find_max(node1);
            if (r0 != r1) begin
              union_max(node0, node1);
              nxt_blue_max = blue_used_max + 1;
            end
          end

          // Min-blue: prefer red edges first
          if (!is_blue) begin
            reg [2:0] r0, r1;
            r0 = find_min(node0);
            r1 = find_min(node1);
            if (r0 != r1) begin
              union_min(node0, node1);
              nxt_blue_min = blue_used_min; // no blue added in this branch
            end
          end
        end
      end

      // After 32 cycles, produce result and raise done
      if (busy && timer == 6'd31) begin
        nxt_done = 1'b1;
        nxt_busy = 1'b0;
      end

      // Keep result stable until next start (outside of busy window)
      if (!busy) begin
        nxt_blue_min = blue_used_min;
        nxt_blue_max = blue_used_max;
      end
    end
  end

  // Sequential updates
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      timer <= 6'd0;
      busy <= 1'b0;
      done <= 1'b0;
      started <= 1'b0;
      result <= 1'b0;
      blue_used_min <= 4'd0;
      blue_used_max <= 4'd0;
    end else begin
      timer <= nxt_timer;
      busy <= nxt_busy;
      done <= nxt_done;
      started <= nxt_started;
      // Update result exactly on completion (timer == 31)
      if (busy && timer == 6'd31) begin
        result <= (nxt_blue_min <= k && k <= nxt_blue_max);
      end
      blue_used_min <= nxt_blue_min;
      blue_used_max <= nxt_blue_max;
    end
  end
endmodule
