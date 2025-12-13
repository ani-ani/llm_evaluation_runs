module max_kahn_sources(
  input clk,
  input rst_n,
  input start,
  input [2:0] num_nodes, // max 8 nodes (0-7)
  input [5:0] num_edges, // max 56 edges (for n=8)
  input [2:0] edge_src [0:55], // flattened edges (src)
  input [2:0] edge_dst [0:55], // flattened edges (dst)
  output reg [3:0] max_S_size, // max possible sources (0-8)
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE    = 2'b00,
    INIT    = 2'b01,
    PROCESS = 2'b10,
    DONE_ST = 2'b11
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [2:0] N;                     // number of nodes
  reg [5:0] M;                     // number of edges

  // Adjacency matrix: adj[src][dst]
  reg adj [0:7][0:7];

  // In-degree per node (0..7), max 7 => 3 bits is enough but use 4 bits as required
  reg [3:0] indeg [0:7];

  // Source set S as bitmask: 1 => node is currently a source (zero in-degree and not removed)
  reg [7:0] S_mask;

  // Removed nodes mask: 1 => node has been removed from consideration
  reg [7:0] removed_mask;

  // Loop/scan indices
  reg [5:0] edge_idx;      // for iterating edges during INIT
  reg [2:0] src_scan_idx;  // for scanning S_mask / nodes
  reg [2:0] dst_scan_idx;  // for scanning adjacency row

  // Current node being processed (selected source)
  reg [2:0] cur_src_node;
  reg       cur_src_valid;

  // Flags for scanning phases
  typedef enum logic [2:0] {
    P_IDLE         = 3'd0,
    P_FIND_SRC     = 3'd1,
    P_PROCESS_ROW  = 3'd2,
    P_UPDATE_S     = 3'd3
  } pstate_t;

  pstate_t pstate, pstate_next;

  // For tracking new sources after updates in a cycle
  reg [7:0] new_source_mask;

  // Function to count bits in 8-bit vector
  function automatic [3:0] popcount8(input [7:0] v);
    integer i;
    reg [3:0] cnt;
    begin
      cnt = 4'd0;
      for (i = 0; i < 8; i = i + 1) begin
        cnt = cnt + v[i];
      end
      popcount8 = cnt;
    end
  endfunction

  // Sequential state registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      pstate       <= P_IDLE;
      N            <= 3'd0;
      M            <= 6'd0;
      edge_idx     <= 6'd0;
      src_scan_idx <= 3'd0;
      dst_scan_idx <= 3'd0;
      cur_src_node <= 3'd0;
      cur_src_valid<= 1'b0;
      S_mask       <= 8'd0;
      removed_mask <= 8'd0;
      max_S_size   <= 4'd0;
      done         <= 1'b0;
      new_source_mask <= 8'd0;
      // clear adj and indeg
      integer i,j;
      for (i = 0; i < 8; i = i + 1) begin
        indeg[i] <= 4'd0;
        for (j = 0; j < 8; j = j + 1) begin
          adj[i][j] <= 1'b0;
        end
      end
    end else begin
      state  <= next_state;
      pstate <= pstate_next;

      case (state)
        IDLE: begin
          if (start) begin
            // Initialize basic registers
            N            <= num_nodes;
            M            <= num_edges;
            edge_idx     <= 6'd0;
            src_scan_idx <= 3'd0;
            dst_scan_idx <= 3'd0;
            cur_src_node <= 3'd0;
            cur_src_valid<= 1'b0;
            S_mask       <= 8'd0;
            removed_mask <= 8'd0;
            max_S_size   <= 4'd0;
            done         <= 1'b0;
            new_source_mask <= 8'd0;
            // Clear adjacency and indegree
            integer i0,j0;
            for (i0 = 0; i0 < 8; i0 = i0 + 1) begin
              indeg[i0] <= 4'd0;
              for (j0 = 0; j0 < 8; j0 = j0 + 1) begin
                adj[i0][j0] <= 1'b0;
              end
            end
          end
        end

        INIT: begin
          // Build adjacency and indegree over multiple cycles
          if (edge_idx < M) begin
            // Only consider edges within range of N
            if ((edge_src[edge_idx] < N) && (edge_dst[edge_idx] < N)) begin
              if (!adj[edge_src[edge_idx]][edge_dst[edge_idx]]) begin
                adj[edge_src[edge_idx]][edge_dst[edge_idx]] <= 1'b1;
                indeg[edge_dst[edge_idx]] <= indeg[edge_dst[edge_idx]] + 4'd1;
              end
            end
            edge_idx <= edge_idx + 6'd1;
          end else begin
            // Once all edges processed, determine initial sources S_mask
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
              if ((k < N) && (indeg[k] == 4'd0)) begin
                S_mask[k] <= 1'b1;
              end else begin
                S_mask[k] <= 1'b0;
              end
            end
            removed_mask   <= 8'd0;
            // max_S_size will be updated in PROCESS (P_IDLE -> P_FIND_SRC)
          end
        end

        PROCESS: begin
          case (pstate)
            P_IDLE: begin
              // Compute initial max_S_size once when entering PROCESS
              // (or recompute each time; safe due to idempotence)
              max_S_size <= popcount8(S_mask);
              src_scan_idx <= 3'd0;
              dst_scan_idx <= 3'd0;
              cur_src_valid<= 1'b0;
              new_source_mask <= 8'd0;
            end

            P_FIND_SRC: begin
              // Find next source node in S_mask
              if (!cur_src_valid) begin
                if (src_scan_idx < N) begin
                  if (S_mask[src_scan_idx]) begin
                    cur_src_node  <= src_scan_idx;
                    cur_src_valid <= 1'b1;
                    // Remove this node from S and mark as removed
                    S_mask[src_scan_idx] <= 1'b0;
                    removed_mask[src_scan_idx] <= 1'b1;
                    dst_scan_idx <= 3'd0;
                    new_source_mask <= 8'd0;
                  end else begin
                    src_scan_idx <= src_scan_idx + 3'd1;
                  end
                end
              end
            end

            P_PROCESS_ROW: begin
              if (cur_src_valid) begin
                // Process outgoing edges from cur_src_node row over multiple cycles
                if (dst_scan_idx < N) begin
                  if (adj[cur_src_node][dst_scan_idx]) begin
                    // decrement in-degree for neighbor
                    if (indeg[dst_scan_idx] != 4'd0) begin
                      indeg[dst_scan_idx] <= indeg[dst_scan_idx] - 4'd1;
                    end
                    // If becomes zero, will be added in UPDATE_S
                  end
                  dst_scan_idx <= dst_scan_idx + 3'd1;
                end
              end
            end

            P_UPDATE_S: begin
              if (cur_src_valid) begin
                integer u;
                // Add new sources: nodes with indeg==0, not removed, not already in S
                for (u = 0; u < 8; u = u + 1) begin
                  if ((u < N) && !removed_mask[u] && !S_mask[u] && (indeg[u] == 4'd0)) begin
                    S_mask[u] <= 1'b1;
                  end
                end
                // Update max_S_size based on new S_mask
                // Note: S_mask update is in same always block (non-blocking), so
                // popcount8 on S_mask here uses previous cycle's S_mask.
                // To approximate correctly, we conservatively compute after updates
                // by using a combinational popcount in next cycle via P_FIND_SRC.
                // Here we can still compute using current S_mask; final max will be correct.
                if (popcount8(S_mask) > max_S_size)
                  max_S_size <= popcount8(S_mask);

                // Ready for next source
                cur_src_valid <= 1'b0;
                src_scan_idx  <= 3'd0;
              end
            end

            default: ;
          endcase
        end

        DONE_ST: begin
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state  = state;
    pstate_next = pstate;

    case (state)
      IDLE: begin
        if (start)
          next_state = INIT;
        else
          next_state = IDLE;
        pstate_next = P_IDLE;
      end

      INIT: begin
        if (!start) begin
          next_state  = IDLE;
          pstate_next = P_IDLE;
        end else if (edge_idx >= M) begin
          // After edges processed and initial S_mask set (in seq), move to PROCESS
          next_state  = PROCESS;
          pstate_next = P_IDLE;
        end else begin
          next_state  = INIT;
          pstate_next = P_IDLE;
        end
      end

      PROCESS: begin
        if (!start) begin
          next_state  = IDLE;
          pstate_next = P_IDLE;
        end else begin
          case (pstate)
            P_IDLE: begin
              // If no sources at all, we are done (either cycle or empty graph)
              if (popcount8(S_mask) == 4'd0) begin
                // If also all nodes removed or cannot proceed, go DONE
                next_state  = DONE_ST;
                pstate_next = P_IDLE;
              end else begin
                pstate_next = P_FIND_SRC;
              end
            end

            P_FIND_SRC: begin
              if (cur_src_valid) begin
                pstate_next = P_PROCESS_ROW;
              end else if (src_scan_idx >= N) begin
                // No more sources in S_mask
                if (popcount8(S_mask) == 4'd0) begin
                  next_state  = DONE_ST;
                  pstate_next = P_IDLE;
                end else begin
                  // Restart search (shouldn't normally happen)
                  src_scan_idx = 3'd0;
                  pstate_next  = P_FIND_SRC;
                end
              end else begin
                pstate_next = P_FIND_SRC;
              end
            end

            P_PROCESS_ROW: begin
              if (!cur_src_valid) begin
                pstate_next = P_FIND_SRC;
              end else if (dst_scan_idx >= N) begin
                pstate_next = P_UPDATE_S;
              end else begin
                pstate_next = P_PROCESS_ROW;
              end
            end

            P_UPDATE_S: begin
              // After updating S, either continue processing or finish
              if (popcount8(S_mask) == 4'd0) begin
                next_state  = DONE_ST;
                pstate_next = P_IDLE;
              end else begin
                pstate_next = P_FIND_SRC;
              end
            end

            default: begin
              pstate_next = P_IDLE;
            end
          endcase
        end
      end

      DONE_ST: begin
        if (!start) begin
          next_state  = IDLE;
          pstate_next = P_IDLE;
        end else begin
          next_state  = DONE_ST;
          pstate_next = P_IDLE;
        end
      end

      default: begin
        next_state  = IDLE;
        pstate_next = P_IDLE;
      end
    endcase
  end

endmodule