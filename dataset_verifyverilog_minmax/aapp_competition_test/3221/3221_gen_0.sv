module ginger_candy_optimizer(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Start computation (pulse high)
  input [3:0] n_nodes, // Number of junctions (1-8)
  input [3:0] n_roads, // Number of roads (1-16)
  input [4:0] alpha, // Alpha parameter (1-20)
  input [7:0] road_data_valid, // Road data write enable (1 per cycle)
  input [2:0] u_in, // Junction u (3-bit)
  input [2:0] v_in, // Junction v (3-bit)
  input [15:0] c_in, // Candy count (16-bit)
  output reg [31:0] min_energy, // Computed L^2 + alpha*K (32-bit)
  output reg no_route, // High when no valid route
  output reg done // High when computation completed
);
  // Internal constants
  localparam MAX_EDGES = 16;
  localparam MAX_NODES = 8;
  localparam LATENCY   = 1024; // fixed compute latency in cycles

  // State encoding
  localparam FSM_IDLE      = 3'b000;
  localparam FSM_LOAD_DATA = 3'b001;
  localparam FSM_FIND      = 3'b010;
  localparam FSM_CALC      = 3'b011;
  localparam FSM_DONE      = 3'b100;

  // Edge storage
  reg [2:0] eu [0:MAX_EDGES-1];
  reg [2:0] ev [0:MAX_EDGES-1];
  reg [15:0] ec [0:MAX_EDGES-1];

  // Latched inputs for compute
  reg [3:0] n_nodes_r, n_roads_r;
  reg [4:0] alpha_r;
  reg [7:0] road_data_valid_r;
  reg [2:0] u_in_r, v_in_r;
  reg [15:0] c_in_r;

  // Counters/FSM state
  reg [2:0] state_d, state_q;
  reg [9:0] cycle_cnt_d, cycle_cnt_q; // up to 1023
  reg [4:0] eidx_d, eidx_q; // up to 16 edges
  reg [3:0] node_count_d, node_count_q; // up to 8
  reg [6:0] degree_d [0:MAX_NODES-1]; // degree up to 16 (needs 5 bits, padded to 7)
  reg [6:0] degree_q [0:MAX_NODES-1];
  reg [2:0] start_node_d, start_node_q;
  reg [2:0] max_candy_idx_d, max_candy_idx_q;
  reg [15:0] max_candy_d, max_candy_q;

  // Combinational flags
  reg start_rising;
  reg all_edges_loaded;
  reg even_deg; // true when all non-zero degree nodes have even degree
  reg connected; // connectivity check via DFS

  integer i, j;

  // Edge packing for DFS visited-edge representation
  function [15:0] edge_bit;
    input [2:0] idx;
    edge_bit = (1 << idx);
  endfunction

  // Start pulse detection (combinational)
  always @(*) begin
    start_rising = start && !road_data_valid_r[0]; // road_data_valid_r[0] holds previous start
  end

  // Data path for loading edges
  always @(*) begin
    // Default: keep previous
    eidx_d = eidx_q;
    node_count_d = node_count_q;
    for (i = 0; i < MAX_NODES; i = i + 1) begin
      degree_d[i] = degree_q[i];
    end
    max_candy_d = max_candy_q;
    max_candy_idx_d = max_candy_idx_q;

    if (start_rising) begin
      // Latch inputs and prepare for loading
      n_nodes_r = n_nodes;
      n_roads_r = n_roads;
      alpha_r   = alpha;
      eidx_d = 5'd0;
      node_count_d = 4'd0;
      for (i = 0; i < MAX_NODES; i = i + 1) begin
        degree_d[i] = 7'd0;
      end
      max_candy_d = 16'd0;
      max_candy_idx_d = 3'd0;
    end else if ((state_q == FSM_LOAD_DATA) && (|road_data_valid)) begin
      // Load exactly one road per cycle when road_data_valid high
      // Use current inputs as latched at the start of cycle (avoid latches on inputs)
      if (eidx_q < {1'b0, n_roads_r}) begin
        eu[eidx_q] = u_in_r;
        ev[eidx_q] = v_in_r;
        ec[eidx_q] = c_in_r;
        // Update degrees
        degree_d[u_in_r] = degree_q[u_in_r] + 1;
        degree_d[v_in_r] = degree_q[v_in_r] + 1;
        eidx_d = eidx_q + 1;
        // Track max candy (unique by spec)
        if (c_in_r > max_candy_q) begin
          max_candy_d = c_in_r;
          max_candy_idx_d = eidx_q; // current index
        end
      end
    end
  end

  // Connectivity and even-degree checks (combinational with current latched data)
  always @(*) begin
    // Degree evenness
    even_deg = 1'b1;
    for (i = 0; i < MAX_NODES; i = i + 1) begin
      if (i < n_nodes_r) begin
        if (degree_q[i] > 0) begin
          even_deg = even_deg & (degree_q[i][0] == 1'b0); // even check
        end
      end
    end

    // Connectivity via DFS over edges
    connected = 1'b0;
    if (n_roads_r > 0) begin
      // Find a start node with non-zero degree
      start_node_d = 3'd0;
      for (i = 0; i < MAX_NODES; i = i + 1) begin
        if (i < n_nodes_r && degree_q[i] > 0) begin
          start_node_d = i;
          break;
        end
      end

      // DFS
      reg [7:0] stack_nodes;
      reg visited_nodes [0:MAX_NODES-1];
      reg visited_edges [0:MAX_EDGES-1];
      integer sp;

      for (i = 0; i < MAX_NODES; i = i + 1) visited_nodes[i] = 1'b0;
      for (i = 0; i < MAX_EDGES; i = i + 1) visited_edges[i] = 1'b0;
      sp = 0;

      // stack push
      stack_nodes = start_node_d;
      visited_nodes[start_node_d] = 1'b1;

      // Iterative DFS
      while (sp >= 0) begin
        reg [2:0] node;
        node = stack_nodes[sp];
        sp = sp - 1;
        // Visit all edges from 'node'
        for (i = 0; i < MAX_EDGES; i = i + 1) begin
          if (i < {1'b0, n_roads_r}) begin
            if (!visited_edges[i]) begin
              if (eu[i] == node) begin
                visited_edges[i] = 1'b1;
                if (!visited_nodes[ev[i]]) begin
                  visited_nodes[ev[i]] = 1'b1;
                  sp = sp + 1;
                  stack_nodes[sp] = ev[i];
                end
              end else if (ev[i] == node) begin
                visited_edges[i] = 1'b1;
                if (!visited_nodes[eu[i]]) begin
                  visited_nodes[eu[i]] = 1'b1;
                  sp = sp + 1;
                  stack_nodes[sp] = eu[i];
                end
              end
            end
          end
        end
      end

      // Check all non-isolated nodes visited
      connected = 1'b1;
      for (i = 0; i < MAX_NODES; i = i + 1) begin
        if (i < n_nodes_r && degree_q[i] > 0) begin
          if (!visited_nodes[i]) begin
            connected = 1'b0;
          end
        end
      end
    end
  end

  // All edges loaded flag
  always @(*) begin
    all_edges_loaded = (eidx_q == {1'b0, n_roads_r}) && (n_roads_r > 0);
  end

  // FSM combinational next state and outputs
  always @(*) begin
    state_d = state_q;
    cycle_cnt_d = cycle_cnt_q;
    // Outputs
    min_energy = 32'd0;
    no_route = 1'b0;
    done = 1'b0;
    // Keep inputs latched
    road_data_valid_r = road_data_valid;
    u_in_r = u_in;
    v_in_r = v_in;
    c_in_r = c_in;

    if (!rst_n) begin
      state_d = FSM_IDLE;
      cycle_cnt_d = 10'd0;
    end else begin
      case (state_q)
        FSM_IDLE: begin
          if (start_rising) begin
            // Begin fixed-latency compute
            state_d = FSM_LOAD_DATA;
            cycle_cnt_d = 10'd0;
            // keep latched inputs as set in data path
          end
        end
        FSM_LOAD_DATA: begin
          cycle_cnt_d = cycle_cnt_q + 1;
          if (all_edges_loaded) begin
            state_d = FSM_FIND;
          end else begin
            state_d = FSM_LOAD_DATA;
          end
        end
        FSM_FIND: begin
          // Stay one cycle for evaluation
          cycle_cnt_d = cycle_cnt_q + 1;
          state_d = FSM_CALC;
        end
        FSM_CALC: begin
          // Compute energy if valid Eulerian cycle exists
          if (all_edges_loaded && even_deg && connected) begin
            min_energy = ({16'd0, max_candy_q} * {16'd0, max_candy_q}) + ({27'd0, alpha_r} * {27'd0, n_roads_r});
            no_route = 1'b0;
          end else begin
            min_energy = 32'd0;
            no_route = 1'b1;
          end
          cycle_cnt_d = cycle_cnt_q + 1;
          state_d = FSM_DONE;
        end
        FSM_DONE: begin
          // Pulse done for 1 cycle at exact latency
          if (cycle_cnt_q == (LATENCY - 1)) begin
            done = 1'b1;
            // Hold outputs valid at this cycle
            if (all_edges_loaded && even_deg && connected) begin
              min_energy = ({16'd0, max_candy_q} * {16'd0, max_candy_q}) + ({27'd0, alpha_r} * {27'd0, n_roads_r});
              no_route = 1'b0;
            end else begin
              min_energy = 32'd0;
              no_route = 1'b1;
            end
            state_d = FSM_IDLE;
            cycle_cnt_d = 10'd0;
          end else begin
            done = 1'b0;
            cycle_cnt_d = cycle_cnt_q + 1;
            state_d = FSM_DONE;
            // Hold outputs stable during DONE
            if (all_edges_loaded && even_deg && connected) begin
              min_energy = ({16'd0, max_candy_q} * {16'd0, max_candy_q}) + ({27'd0, alpha_r} * {27'd0, n_roads_r});
              no_route = 1'b0;
            end else begin
              min_energy = 32'd0;
              no_route = 1'b1;
            end
          end
        end
        default: begin
          state_d = FSM_IDLE;
          cycle_cnt_d = 10'd0;
        end
      endcase
    end
  end

  // Sequential update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= FSM_IDLE;
      cycle_cnt_q <= 10'd0;
      eidx_q <= 5'd0;
      node_count_q <= 4'd0;
      for (i = 0; i < MAX_NODES; i = i + 1) begin
        degree_q[i] <= 7'd0;
      end
      max_candy_q <= 16'd0;
      max_candy_idx_q <= 3'd0;
      // outputs
      min_energy <= 32'd0;
      no_route <= 1'b0;
      done <= 1'b0;
      // latched inputs
      road_data_valid_r <= 8'd0;
      u_in_r <= 3'd0;
      v_in_r <= 3'd0;
      c_in_r <= 16'd0;
      // latched control
      n_nodes_r <= 4'd0;
      n_roads_r <= 4'd0;
      alpha_r   <= 5'd0;
      start_node_q <= 3'd0;
    end else begin
      state_q <= state_d;
      cycle_cnt_q <= cycle_cnt_d;
      eidx_q <= eidx_d;
      node_count_q <= node_count_d;
      for (i = 0; i < MAX_NODES; i = i + 1) begin
        degree_q[i] <= degree_d[i];
      end
      max_candy_q <= max_candy_d;
      max_candy_idx_q <= max_candy_idx_d;
      road_data_valid_r <= road_data_valid_r; // internal; assigned above
      u_in_r <= u_in_r; // internal; assigned above
      v_in_r <= v_in_r; // internal; assigned above
      c_in_r <= c_in_r; // internal; assigned above
      n_nodes_r <= n_nodes_r; // latched inputs maintained in datapath
      n_roads_r <= n_roads_r;
      alpha_r   <= alpha_r;
      start_node_q <= start_node_d; // used only in connectivity block; kept for completeness
    end
  end
endmodule