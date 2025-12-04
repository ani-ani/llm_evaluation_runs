module chemical_element_minimizer(
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  input [4:0] m,
  input [4:0] q,
  input [31:0] elements [31:0],
  output reg [5:0] minimal_purchases,
  output reg done
);

  // Parameters
  localparam MAX_NODES = 6'd32;
  localparam MAX_Q     = 6'd32;
  localparam TOTAL_CYCLES = 6'd34; // fixed latency after start

  // FSM states (simple encoded via cycle counter)
  // We'll use a cycle counter from 0..33 after start asserted.
  reg [5:0] cycle_cnt;
  reg       active; // indicates operation in progress

  // Union-Find storage
  reg [4:0] parent [0:31];
  reg [4:0] rank_arr [0:31];

  // Total components count
  reg [5:0] total_components;

  // Latched inputs
  reg [4:0] n_latched;
  reg [4:0] m_latched;
  reg [4:0] q_latched;

  // Internal for union operation each cycle
  reg [5:0] merge_idx;      // which element index is being processed (0..31)
  reg [4:0] r_id;
  reg [4:0] c_id;
  reg [4:0] idx_r;
  reg [4:0] idx_c;

  // Find with path compression (combinational helper)
  // Note: Implemented iteratively with bounded depth due to 32 elements.
  function automatic [4:0] find_root;
    input [4:0] x;
    reg [4:0] cur;
    reg [4:0] nxt;
    begin
      cur = x;
      // Follow parents until root (parent[i] == i)
      // Max depth <= 31, unrolled as bounded loop
      repeat (32) begin
        nxt = parent[cur];
        if (nxt == cur) begin
          break;
        end else begin
          cur = nxt;
        end
      end
      find_root = cur;
    end
  endfunction

  // Sequential path compression (single-step) performed during union update
  task automatic compress_path;
    input [4:0] x;
    input [4:0] root;
    reg [4:0] cur;
    reg [4:0] nxt;
    begin
      cur = x;
      repeat (32) begin
        nxt = parent[cur];
        if (nxt == cur || nxt == root) begin
          parent[cur] <= root;
          break;
        end else begin
          parent[cur] <= root;
          cur = nxt;
        end
      end
    end
  endtask

  // Synchronous control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all state
      cycle_cnt         <= 6'd0;
      active            <= 1'b0;
      done              <= 1'b0;
      minimal_purchases <= 6'd0;
      total_components  <= 6'd0;
      merge_idx         <= 6'd0;
      n_latched         <= 5'd0;
      m_latched         <= 5'd0;
      q_latched         <= 5'd0;
    end else begin
      // Default
      done <= 1'b0;

      if (!active) begin
        // Wait for start
        if (start) begin
          active    <= 1'b1;
          cycle_cnt <= 6'd0;

          // Latch inputs
          n_latched <= n;
          m_latched <= m;
          q_latched <= q;

          // Initialize union-find structures for n+m nodes
          // nodes: 0 .. (n+m-1); rows 0..(n-1), cols n..(n+m-1)
          // For simplicity init all 32 entries, but only first n+m are used.
          begin : init_loop
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
              parent[i]   <= i[4:0];
              rank_arr[i] <= 5'd0;
            end
          end

          // Initialize components; treat n+m as up to 32
          total_components <= (n + m);
          merge_idx        <= 6'd0;
        end
      end else begin
        // Active: running fixed schedule over 34 cycles
        cycle_cnt <= cycle_cnt + 6'd1;

        // Cycle 0/1: initialization already done on start cycle (cycle_cnt=0 after start)
        // From cycle 1 onward, perform merges for each element index 0..31

        // Process merges for indices 0..31 (one per cycle), even if q < 32; ignore when i >= q
        if (cycle_cnt < MAX_Q) begin
          // Process element at index merge_idx == cycle_cnt
          merge_idx <= cycle_cnt; // align index with cycle

          if (cycle_cnt < q_latched) begin
            // Extract r and c from input element: elements[i][9:5]=row, [4:0]=col
            r_id = elements[cycle_cnt][9:5];
            c_id = elements[cycle_cnt][4:0];

            // Map to node indices: row -> r_id, col -> n_latched + c_id
            idx_r = r_id;
            idx_c = n_latched + c_id;

            if ((idx_r < (n_latched + m_latched)) && (idx_c < (n_latched + m_latched))) begin
              // Perform union-by-rank
              // Find roots (combinational)
              reg [4:0] root_r;
              reg [4:0] root_c;
              root_r = find_root(idx_r);
              root_c = find_root(idx_c);

              if (root_r != root_c) begin
                // Union
                if (rank_arr[root_r] < rank_arr[root_c]) begin
                  parent[root_r] <= root_c;
                  compress_path(idx_r, root_c);
                  compress_path(idx_c, root_c);
                end else if (rank_arr[root_r] > rank_arr[root_c]) begin
                  parent[root_c] <= root_r;
                  compress_path(idx_r, root_r);
                  compress_path(idx_c, root_r);
                end else begin
                  parent[root_c] <= root_r;
                  rank_arr[root_r] <= rank_arr[root_r] + 5'd1;
                  compress_path(idx_r, root_r);
                  compress_path(idx_c, root_r);
                end

                // Decrement total components when a successful merge occurs
                if (total_components != 0)
                  total_components <= total_components - 6'd1;
              end
            end
          end
        end

        // At fixed cycle TOTAL_CYCLES-1 (33), compute result and signal done.
        if (cycle_cnt == (TOTAL_CYCLES - 1)) begin
          // Special case q=0 handled naturally: total_components = n+m; result = total_components -1
          if (total_components > 0)
            minimal_purchases <= total_components - 6'd1;
          else
            minimal_purchases <= 6'd0;

          done   <= 1'b1;
          active <= 1'b0;
        end
      end
    end
  end

endmodule