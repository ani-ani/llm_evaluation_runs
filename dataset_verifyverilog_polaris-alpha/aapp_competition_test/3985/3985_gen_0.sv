module max_operations(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [1:0]  arraysize,
  input  logic [1:0]  paircount,
  input  logic [7:0]  array1,
  input  logic [7:0]  array2,
  input  logic [7:0]  array3,
  input  logic [7:0]  array4,
  input  logic [1:0]  pair1_i,
  input  logic [1:0]  pair1_j,
  input  logic [1:0]  pair2_i,
  input  logic [1:0]  pair2_j,
  input  logic [1:0]  pair3_i,
  input  logic [1:0]  pair3_j,
  input  logic [1:0]  pair4_i,
  input  logic [1:0]  pair4_j,
  output logic [7:0]  result,
  output logic        done
);

  // Parameters
  localparam int NUM_ELEM      = 4;
  localparam int MAX_FACTORS   = 8;       // per element (sufficient for 8-bit numbers)
  localparam int MAX_PAIRS     = 4;
  localparam int MAX_LEFT      = NUM_ELEM * MAX_FACTORS; // worst-case left nodes
  localparam int MAX_RIGHT     = NUM_ELEM * MAX_FACTORS; // worst-case right nodes

  typedef enum logic [2:0] {
    S_IDLE        = 3'd0,
    S_FACTORIZE   = 3'd1,
    S_BUILD_GRAPH = 3'd2,
    S_MATCHING    = 3'd3,
    S_DONE        = 3'd4
  } state_t;

  state_t state, next_state;

  // Store array values
  logic [7:0] arr_val   [0:NUM_ELEM-1];

  // Effective arraysize and paircount (clamped)
  logic [2:0] eff_arraysize;
  logic [2:0] eff_paircount;

  // Pair index storage
  logic [1:0] pair_i    [0:MAX_PAIRS-1];
  logic [1:0] pair_j    [0:MAX_PAIRS-1];

  // Factor storage: for each element, up to MAX_FACTORS prime factors (with multiplicity)
  logic [7:0] factors       [0:NUM_ELEM-1][0:MAX_FACTORS-1];
  logic [3:0] factor_count  [0:NUM_ELEM-1];

  // Factorization control
  logic [2:0] fact_elem_idx;     // 0..3
  logic [7:0] fact_n;
  logic [7:0] fact_div;
  logic       fact_active;

  // Graph representation: adjacency between factor slots via good pairs
  // We index factor slots as (elem_idx, factor_idx).
  // For matching we treat all factor slots of one side of pair as "left" and the other side as "right".
  // To simplify, we build explicit edge list: for each possible left node, list right neighbors.

  // Node mapping per pair: for each edge between element a and b and prime matches.
  // We'll first create flat nodes: left_node_id, right_node_id.

  localparam int MAX_EDGES = MAX_PAIRS * MAX_FACTORS * MAX_FACTORS; // worst case full connection per pair

  // Edge lists for bipartite graph
  logic [15:0] edge_u [0:MAX_EDGES-1];  // left node indices
  logic [15:0] edge_v [0:MAX_EDGES-1];  // right node indices
  logic [15:0] edge_count;

  // We also need count of left and right nodes.
  logic [15:0] left_node_count;
  logic [15:0] right_node_count;

  // Matching arrays
  // matchR[r] = index of left node matched to right node r (or 16'hFFFF if none)
  // We implement simple greedy/iterative augmenting (bounded, small graph).
  logic [15:0] matchR [0:MAX_RIGHT-1];

  // Internal counters for matching FSM
  logic [15:0] m_edge_idx;
  logic [15:0] m_iter;
  logic [7:0]  match_count;

  // Utility function: check if index is valid based on arraysize
  function automatic logic idx_valid(input [1:0] idx);
    return (idx < eff_arraysize);
  endfunction

  // Combinational next-state
  always_comb begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_FACTORIZE;
      end
      S_FACTORIZE: begin
        if (!fact_active)
          next_state = S_BUILD_GRAPH;
      end
      S_BUILD_GRAPH: begin
        next_state = S_MATCHING;
      end
      S_MATCHING: begin
        // limit iterations to ensure <=16 cycles total after start
        if (m_iter == 16 || m_edge_idx >= edge_count)
          next_state = S_DONE;
      end
      S_DONE: begin
        // done is one-cycle; go back to IDLE when start deasserted
        if (!start)
          next_state = S_IDLE;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  integer i, j, k;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= S_IDLE;
      result          <= 8'd0;
      done            <= 1'b0;

      arr_val[0]      <= 8'd0;
      arr_val[1]      <= 8'd0;
      arr_val[2]      <= 8'd0;
      arr_val[3]      <= 8'd0;

      eff_arraysize   <= 3'd0;
      eff_paircount   <= 3'd0;

      for (i = 0; i < MAX_PAIRS; i = i + 1) begin
        pair_i[i] <= 2'd0;
        pair_j[i] <= 2'd0;
      end

      for (i = 0; i < NUM_ELEM; i = i + 1) begin
        factor_count[i] <= 4'd0;
        for (j = 0; j < MAX_FACTORS; j = j + 1) begin
          factors[i][j] <= 8'd0;
        end
      end

      fact_elem_idx   <= 3'd0;
      fact_n          <= 8'd0;
      fact_div        <= 8'd0;
      fact_active     <= 1'b0;

      edge_count      <= 16'd0;
      left_node_count <= 16'd0;
      right_node_count<= 16'd0;

      for (i = 0; i < MAX_EDGES; i = i + 1) begin
        edge_u[i] <= 16'hFFFF;
        edge_v[i] <= 16'hFFFF;
      end

      for (i = 0; i < MAX_RIGHT; i = i + 1) begin
        matchR[i] <= 16'hFFFF;
      end

      m_edge_idx      <= 16'd0;
      m_iter          <= 16'd0;
      match_count     <= 8'd0;

    end else begin
      state <= next_state;
      done  <= 1'b0;

      case (state)
        S_IDLE: begin
          // Latch inputs when start asserted
          if (start) begin
            // Clamp sizes (2-4 for arraysize, 1-4 for paircount)
            eff_arraysize <= (arraysize < 2) ? 3'd2 : ((arraysize > 4) ? 3'd4 : {1'b0,arraysize});
            eff_paircount <= (paircount < 1) ? 3'd1 : ((paircount > 4) ? 3'd4 : {1'b0,paircount});

            arr_val[0] <= array1;
            arr_val[1] <= array2;
            arr_val[2] <= array3;
            arr_val[3] <= array4;

            // Load pairs
            pair_i[0] <= pair1_i;  pair_j[0] <= pair1_j;
            pair_i[1] <= pair2_i;  pair_j[1] <= pair2_j;
            pair_i[2] <= pair3_i;  pair_j[2] <= pair3_j;
            pair_i[3] <= pair4_i;  pair_j[3] <= pair4_j;

            // Reset factorization storage
            for (i = 0; i < NUM_ELEM; i = i + 1) begin
              factor_count[i] <= 4'd0;
              for (j = 0; j < MAX_FACTORS; j = j + 1) begin
                factors[i][j] <= 8'd0;
              end
            end

            fact_elem_idx <= 3'd0;
            fact_active   <= 1'b1;
            fact_n        <= arr_val[0];
            fact_div      <= 8'd2;

            // Clear graph and matching
            edge_count       <= 16'd0;
            left_node_count  <= 16'd0;
            right_node_count <= 16'd0;

            for (i = 0; i < MAX_EDGES; i = i + 1) begin
              edge_u[i] <= 16'hFFFF;
              edge_v[i] <= 16'hFFFF;
            end
            for (i = 0; i < MAX_RIGHT; i = i + 1) begin
              matchR[i] <= 16'hFFFF;
            end
            m_edge_idx  <= 16'd0;
            m_iter      <= 16'd0;
            match_count <= 8'd0;
          end
        end

        S_FACTORIZE: begin
          if (fact_active) begin
            if (fact_n > 1 && fact_div <= fact_n) begin
              if (fact_n % fact_div == 0) begin
                if (factor_count[fact_elem_idx] < MAX_FACTORS) begin
                  factors[fact_elem_idx][factor_count[fact_elem_idx]] <= fact_div;
                  factor_count[fact_elem_idx] <= factor_count[fact_elem_idx] + 1'b1;
                end
                fact_n <= fact_n / fact_div;
              end else begin
                fact_div <= (fact_div == 8'd2) ? 8'd3 : fact_div + 8'd2; // test 2,3,5,7,... odds
              end
            end else begin
              // If remaining fact_n > 1, record as prime
              if (fact_n > 1 && factor_count[fact_elem_idx] < MAX_FACTORS) begin
                factors[fact_elem_idx][factor_count[fact_elem_idx]] <= fact_n;
                factor_count[fact_elem_idx] <= factor_count[fact_elem_idx] + 1'b1;
              end

              // Move to next element
              if (fact_elem_idx + 1 < eff_arraysize) begin
                fact_elem_idx <= fact_elem_idx + 1'b1;
                fact_n        <= arr_val[fact_elem_idx + 1'b1];
                fact_div      <= 8'd2;
              end else begin
                fact_active <= 1'b0;
              end
            end
          end
        end

        S_BUILD_GRAPH: begin
          // Build bipartite graph based on factors and good pairs
          // Left and Right node indexing scheme:
          // For each pair k: determine which index is even (left) and odd (right).
          // For every matching prime factor between the two elements, create an edge.

          edge_count       <= 16'd0;
          left_node_count  <= 16'd0;
          right_node_count <= 16'd0;

          // Temporary arrays (implicit via deterministic mapping):
          // left_id = base_left + local_left_factor_index
          // right_id = base_right + local_right_factor_index

          // We'll assign contiguous index ranges per element:
          // left side: elements with even index (0,2)
          // right side: elements with odd index (1,3)

          // Precompute base indices
          logic [15:0] base_left [0:NUM_ELEM-1];
          logic [15:0] base_right[0:NUM_ELEM-1];

          // Initialize bases
          base_left[0]  = 16'd0;
          base_left[1]  = 16'd0;
          base_left[2]  = 16'd0;
          base_left[3]  = 16'd0;
          base_right[0] = 16'd0;
          base_right[1] = 16'd0;
          base_right[2] = 16'd0;
          base_right[3] = 16'd0;

          // Compute bases sequentially (small, done in one cycle combinationally inside this clocked block)
          left_node_count  <= 16'd0;
          right_node_count <= 16'd0;

          // Even indices as left
          if (0 < eff_arraysize) begin
            base_left[0]      = left_node_count;
            left_node_count   <= left_node_count + factor_count[0];
          end
          if (2 < eff_arraysize) begin
            base_left[2]      = left_node_count;
            left_node_count   <= left_node_count + factor_count[2];
          end

          // Odd indices as right
          if (1 < eff_arraysize) begin
            base_right[1]     = right_node_count;
            right_node_count  <= right_node_count + factor_count[1];
          end
          if (3 < eff_arraysize) begin
            base_right[3]     = right_node_count;
            right_node_count  <= right_node_count + factor_count[3];
          end

          // Clear matchR
          for (i = 0; i < MAX_RIGHT; i = i + 1) begin
            matchR[i] <= 16'hFFFF;
          end

          // Build edges for valid pairs
          // Note: using procedural loops; this executes within the clocked block in one cycle.
          edge_count <= 16'd0;
          for (k = 0; k < MAX_PAIRS; k = k + 1) begin
            if (k < eff_paircount) begin
              if (idx_valid(pair_i[k]) && idx_valid(pair_j[k])) begin
                int ai = pair_i[k];
                int aj = pair_j[k];
                int left_elem;
                int right_elem;

                if ((ai[0] == 1'b0) && (aj[0] == 1'b1)) begin
                  left_elem  = ai;
                  right_elem = aj;
                end else if ((ai[0] == 1'b1) && (aj[0] == 1'b0)) begin
                  left_elem  = aj;
                  right_elem = ai;
                end else begin
                  // enforce bipartite: skip pairs of same parity
                  left_elem  = -1;
                  right_elem = -1;
                end

                if (left_elem >= 0 && right_elem >= 0) begin
                  for (i = 0; i < factor_count[left_elem]; i = i + 1) begin
                    for (j = 0; j < factor_count[right_elem]; j = j + 1) begin
                      if (factors[left_elem][i] == factors[right_elem][j]) begin
                        if (edge_count < MAX_EDGES) begin
                          edge_u[edge_count] <= base_left[left_elem]  + i;
                          edge_v[edge_count] <= base_right[right_elem] + j;
                          edge_count         <= edge_count + 1'b1;
                        end
                      end
                    end
                  end
                end
              end
            end
          end

          // Initialize matching iteration counters
          m_edge_idx  <= 16'd0;
          m_iter      <= 16'd0;
          match_count <= 8'd0;
        end

        S_MATCHING: begin
          // Simple iterative greedy matching over edges.
          // On each cycle, scan one edge; if it can improve matching, update.
          if (m_edge_idx < edge_count && m_iter < 16) begin
            logic [15:0] u;
            logic [15:0] v;
            u = edge_u[m_edge_idx];
            v = edge_v[m_edge_idx];

            if (v < right_node_count) begin
              if (matchR[v] == 16'hFFFF) begin
                matchR[v]   <= u;
                match_count <= match_count + 1'b1;
              end
            end

            m_edge_idx <= m_edge_idx + 1'b1;

            if (m_edge_idx + 1 >= edge_count) begin
              // Restart scan if iterations remain to allow some improvement
              m_edge_idx <= 16'd0;
              m_iter     <= m_iter + 1'b1;
            end
          end
        end

        S_DONE: begin
          result <= match_count;
          done   <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule