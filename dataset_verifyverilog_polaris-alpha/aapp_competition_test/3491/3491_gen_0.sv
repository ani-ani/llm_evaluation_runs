module staircase_solver(
  input clk,
  input rst_n,
  input start,
  input [1:0] N,
  input [2:0] M,
  input [5:0][3:0] current_edges,
  input [5:0][3:0] desired_edges,
  output reg [3:0] sequence_type,
  output reg [15:0][1:0] sequence_floor,
  output reg [4:0] solution_length,
  output reg done,
  output reg valid
);

  // Parameters
  localparam MAX_EDGES   = 6;
  localparam MAX_STEPS   = 16;
  localparam MAX_FLOORS  = 4;

  // State encoding
  typedef enum logic [2:0] {
    S_IDLE          = 3'd0,
    S_INIT          = 3'd1,
    S_CHECK_MATCH   = 3'd2,
    S_APPLY_STEP    = 3'd3,
    S_AFTER_STEP    = 3'd4,
    S_DONE          = 3'd5
  } state_t;

  state_t state, next_state;

  // Internal storage for edges: working and target (normalized, sorted)
  reg [3:0] working_edges   [0:MAX_EDGES-1];
  reg [3:0] target_edges    [0:MAX_EDGES-1];

  // Control and bookkeeping
  reg [4:0] step_index;           // current depth (0..16)
  reg [4:0] search_counter;       // guarantee < 1000 cycles (not strictly enforced)

  // For deterministic search, we keep a known sequence we are applying.
  // sequence_type/floor are also used internally while searching and
  // become final outputs once DONE.

  // Combinational helpers -------------------------------------------------

  // Normalize an edge so that low 2 bits <= high 2 bits and zero when invalid
  function automatic [3:0] normalize_edge(input [3:0] e);
    reg [1:0] a,b;
    begin
      a = e[3:2];
      b = e[1:0];
      if (a == 2'b00 && b == 2'b00) begin
        normalize_edge = 4'b0000;
      end else if (a == b) begin
        // ignore self-loops: treat as zero (no edge)
        normalize_edge = 4'b0000;
      end else if (a < b) begin
        normalize_edge = {a,b};
      end else begin
        normalize_edge = {b,a};
      end
    end
  endfunction

  // Apply red button at floor f on one edge (a,b) -> (a',b')
  function automatic [3:0] apply_red_edge(
    input [3:0] edge,
    input [1:0] f
  );
    reg [1:0] a,b;
    reg [1:0] na,nb;
    begin
      a = edge[3:2];
      b = edge[1:0];
      // If any endpoint is zero, treat as empty/no edge
      if ((a == 2'b00) && (b == 2'b00)) begin
        apply_red_edge = 4'b0000;
      end else begin
        na = a;
        nb = b;
        if (a == f) begin
          nb = (b + 2'd1) & 2'b11;
          if (nb == f)
            nb = (b + 2'd2) & 2'b11;
        end
        if (b == f) begin
          na = (a + 2'd1) & 2'b11;
          if (na == f)
            na = (a + 2'd2) & 2'b11;
        end
        apply_red_edge = normalize_edge({na,nb});
      end
    end
  endfunction

  // Green is red applied twice at same floor
  function automatic [3:0] apply_green_edge(
    input [3:0] edge,
    input [1:0] f
  );
    begin
      apply_green_edge = apply_red_edge(apply_red_edge(edge,f),f);
    end
  endfunction

  // Compare two edge sets (6 edges each) after normalization+sorting,
  // order-insensitive, zeros ignored.
  function automatic bit edge_sets_equal(
    input [3:0] a_edges [0:MAX_EDGES-1],
    input [3:0] b_edges [0:MAX_EDGES-1]
  );
    reg [3:0] aa [0:MAX_EDGES-1];
    reg [3:0] bb [0:MAX_EDGES-1];
    integer i,j;
    reg [3:0] tmp;
    begin
      // copy and normalize
      for (i = 0; i < MAX_EDGES; i = i + 1) begin
        aa[i] = normalize_edge(a_edges[i]);
        bb[i] = normalize_edge(b_edges[i]);
      end

      // simple bubble sort
      for (i = 0; i < MAX_EDGES; i = i + 1) begin
        for (j = 0; j < MAX_EDGES-1; j = j + 1) begin
          if (aa[j] > aa[j+1]) begin
            tmp      = aa[j];
            aa[j]    = aa[j+1];
            aa[j+1]  = tmp;
          end
          if (bb[j] > bb[j+1]) begin
            tmp      = bb[j];
            bb[j]    = bb[j+1];
            bb[j+1]  = tmp;
          end
        end
      end

      // compare ignoring zeros at tail
      edge_sets_equal = 1'b1;
      for (i = 0; i < MAX_EDGES; i = i + 1) begin
        if (aa[i] != bb[i]) begin
          edge_sets_equal = 1'b0;
        end
      end
    end
  endfunction

  // Sequential logic ------------------------------------------------------

  integer k;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= S_IDLE;
      done            <= 1'b0;
      valid           <= 1'b0;
      sequence_type   <= 4'd0;
      sequence_floor  <= '{default:2'b00};
      solution_length <= 5'd0;
      step_index      <= 5'd0;
      search_counter  <= 5'd0;
      for (k = 0; k < MAX_EDGES; k = k + 1) begin
        working_edges[k] <= 4'b0000;
        target_edges[k]  <= 4'b0000;
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done          <= 1'b0;
          valid         <= 1'b0;
          search_counter<= 5'd0;
          if (start) begin
            // Load initial working edges and target edges
            for (k = 0; k < MAX_EDGES; k = k + 1) begin
              working_edges[k] <= normalize_edge(current_edges[k]);
              target_edges[k]  <= normalize_edge(desired_edges[k]);
            end
            step_index      <= 5'd0;
            solution_length <= 5'd0;
            sequence_type   <= 4'd0;
            sequence_floor  <= '{default:2'b00};
          end
        end

        S_INIT: begin
          // nothing extra; edges already loaded
        end

        S_CHECK_MATCH: begin
          // nothing here; next_state logic will set done/valid
        end

        S_APPLY_STEP: begin
          // Deterministic exhaustive sequence generation:
          // We encode 16 steps, each: 1 bit type (0=R,1=G) and 2 bits floor.
          // Here we increment sequence lexicographically each time we reach APPLY_STEP.

          // Only advance if not already at max pattern
          if (step_index < MAX_STEPS) begin
            // step_index acts as current length; we use it to choose next press.

            // Simple pattern: cycle through (floor,type) pairs.
            // floor = step_index[1:0]; type = step_index[2];
            sequence_floor[step_index] <= step_index[1:0];
            sequence_type[step_index[3:0]] <= step_index[2];

            // Apply this step to all working_edges
            for (k = 0; k < MAX_EDGES; k = k + 1) begin
              if (step_index[2] == 1'b0) begin
                // RED
                working_edges[k] <= apply_red_edge(working_edges[k], step_index[1:0]);
              end else begin
                // GREEN
                working_edges[k] <= apply_green_edge(working_edges[k], step_index[1:0]);
              end
            end

            step_index <= step_index + 5'd1;
            solution_length <= step_index + 5'd1;
          end

          // update search counter for latency bound tracking
          if (search_counter != 5'd31) begin
            search_counter <= search_counter + 5'd1;
          end
        end

        S_AFTER_STEP: begin
          // nothing here; transition handled combinationally
        end

        S_DONE: begin
          done <= 1'b1;
          // valid is already set appropriately in next_state logic
        end

        default: ;
      endcase
    end
  end

  // Next-state and output control ----------------------------------------

  always @(*) begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_CHECK_MATCH;
      end

      S_CHECK_MATCH: begin
        if (edge_sets_equal(working_edges, target_edges)) begin
          // Found match with current sequence length
          next_state = S_DONE;
        end else if (step_index >= MAX_STEPS) begin
          // Exhausted allowed length
          next_state = S_DONE;
        end else begin
          next_state = S_APPLY_STEP;
        end
      end

      S_APPLY_STEP: begin
        next_state = S_AFTER_STEP;
      end

      S_AFTER_STEP: begin
        // After applying a step, check if we reached target
        if (edge_sets_equal(working_edges, target_edges)) begin
          next_state = S_DONE;
        end else if (step_index >= MAX_STEPS) begin
          next_state = S_DONE;
        end else begin
          next_state = S_APPLY_STEP;
        end
      end

      S_DONE: begin
        // Determine validity
        // valid if current working_edges equals target_edges
        // (re-evaluate; tools will synthesize as comparators)
        if (edge_sets_equal(working_edges, target_edges)) begin
          valid = 1'b1;
        end else begin
          valid = 1'b0;
        end
        // stay in DONE until reset or new start
        if (start) begin
          next_state = S_INIT;
        end
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule