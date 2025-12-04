module max_stable_edges(
  input clk,
  input rst_n,
  input start,
  input [3:0] node_count,
  input [3:0] gov_count,
  input [3:0] gov_list [0:3],
  input [6:0] edge_count,
  input [15:0] edge_mask [0:15],
  output reg [6:0] max_edges,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    S_IDLE         = 3'd0,
    S_COMP_SEARCH  = 3'd1,
    S_SIZE_CALC    = 3'd2,
    S_RESULT_CALC  = 3'd3,
    S_DONE         = 3'd4
  } state_t;

  // Internal registers
  state_t state;
  logic [3:0] k;                 // Floyd‑Warshall intermediate index
  logic [15:0] reach[0:15];      // Reachability mask for each node
  logic [3:0] comp_id[0:15];    // Component identifier per node
  logic [3:0] comp_cnt;          // Number of distinct components
  logic [4:0] comp_size[0:15];  // Size of each component
  logic [15:0] comp_mask[0:15]; // Mask of nodes belonging to each component
  logic [4:0] max_comp_size;     // Size of the largest component
  logic [6:0] sum_clique_edges; // Σ size_i·(size_i‑1)/2
  logic [6:0] sum_int_raw;       // Raw internal edge count (each edge counted twice)
  logic [6:0] sum_int_edges;     // Σ existing edges inside components
  logic [6:0] total_possible;   // Total possible edges after completion
  logic [6:0] max_edges_next;
  logic done_next;

  // Combinational block to compute the final result
  always_comb begin
    // Compute Σ size_i·(size_i‑1)/2
    sum_clique_edges = 7'd0;
    for (int i = 0; i < 16; i++) begin
      if (i < comp_cnt) begin
        logic [4:0] s;
        s = comp_size[i];
        sum_clique_edges = sum_clique_edges + ((s * (s - 1)) >> 1);
      end
    end
    // Compute internal edge count (each edge counted twice)
    sum_int_raw = 7'd0;
    for (int i = 0; i < 16; i++) begin
      if (i < node_count) begin
        sum_int_raw = sum_int_raw + $countones(edge_mask[i] & comp_mask[comp_id[i]]);
      end
    end
    sum_int_edges = sum_int_raw >> 1;
    // Total possible edges after clique-completion
    total_possible = sum_clique_edges + (max_comp_size * (node_count - max_comp_size));
    // Compute max additional edges, clamp to zero if underflow
    int tmp;
    tmp = $signed(total_possible) - $signed(edge_count) - $signed(sum_int_edges);
    if (tmp < 0) max_edges_next = 7'd0;
    else         max_edges_next = tmp[6:0];
    done_next = 1'b1;
  end

  // Main state machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      done  <= 1'b0;
      max_edges <= 7'd0;
      k <= 4'd0;
      for (int i = 0; i < 16; i++) begin
        reach[i] <= 16'd0;
        comp_id[i] <= 4'd0;
        comp_size[i] <= 5'd0;
        comp_mask[i] <= 16'd0;
      end
      comp_cnt <= 4'd0;
      max_comp_size <= 5'd0;
    end else begin
      case (state)
        S_IDLE: begin
          done  <= 1'b0;
          max_edges <= 7'd0;
          if (start) begin
            // Initialise reachability matrix
            for (int i = 0; i < 16; i++) begin
              if (i < node_count) begin
                reach[i] <= (16'b1 << i) | edge_mask[i];
              end else begin
                reach[i] <= 16'd0;
              end
            end
            // Clear component data (will be recomputed in S_SIZE_CALC)
            for (int i = 0; i < 16; i++) begin
              comp_id[i] <= 4'd0;
              comp_size[i] <= 5'd0;
              comp_mask[i] <= 16'd0;
            end
            comp_cnt <= 4'd0;
            max_comp_size <= 5'd0;
            k <= 4'd0;
            state <= S_COMP_SEARCH;
          end
        end
        S_COMP_SEARCH: begin
          // One step of Floyd‑Warshall for intermediate k
          for (int i = 0; i < 16; i++) begin
            logic [15:0] new_reach;
            if (i < node_count) begin
              new_reach = reach[i];
              if (reach[i][k]) new_reach = reach[i] | reach[k];
              reach[i] <= new_reach;
            end else begin
              reach[i] <= 16'd0;
            end
          end
          if (k == (node_count - 1)) begin
            state <= S_SIZE_CALC;
            k <= 4'd0;
          end else begin
            k <= k + 1;
          end
        end
        S_SIZE_CALC: begin
          // Determine component ids, masks and sizes
          for (int i = 0; i < 16; i++) begin
            comp_id[i] <= 4'd0;
            comp_size[i] <= 5'd0;
            comp_mask[i] <= 16'd0;
          end
          comp_cnt <= 4'd0;
          for (int i = 0; i < 16; i++) begin
            if (i < node_count) begin
              // Find the smallest node j that is reachable from i (canonical component id)
              logic [3:0] cid;
              cid = 4'd0;
              for (int j = 0; j < 16; j++) begin
                if (reach[i][j]) begin
                  cid = j[3:0];
                  break;
                end
              end
              comp_id[i] <= cid;
              comp_mask[cid] <= comp_mask[cid] | (16'b1 << i);
              comp_size[cid] <= comp_size[cid] + 5'd1;
            end
          end
          // Compute number of components and max component size
          max_comp_size <= 5'd0;
          for (int i = 0; i < 16; i++) begin
            if (comp_size[i] > max_comp_size) max_comp_size <= comp_size[i];
            if (comp_size[i] > 0) comp_cnt <= i + 1;
          end
          state <= S_RESULT_CALC;
        end
        S_RESULT_CALC: begin
          // Combinational block already computed the values
          max_edges <= max_edges_next;
          done <= done_next;
          state <= S_DONE;
        end
        S_DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= S_IDLE;
            done <= 1'b0;
          end
        end
        default: state <= S_IDLE;
      endcase
    end
  end

endmodule