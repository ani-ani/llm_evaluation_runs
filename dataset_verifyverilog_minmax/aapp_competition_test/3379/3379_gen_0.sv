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

  parameter NODES = 8;
  parameter MAX_EDGES = 56;
  parameter W = NODES; // bits for source set

  // State machine
  typedef enum logic [1:0] { IDLE = 2'b00, INIT = 2'b01, PROCESS = 2'b10, DONE = 2'b11 } state_t;
  state_t state, next_state;

  // Graph representation
  reg [NODES-1:0] adj [NODES-1:0];       // adjacency matrix rows (outgoing neighbors per row)
  reg [3:0] indeg [NODES-1:0];           // 4-bit in-degree per node (max 7)
  reg [3:0] remaining_edges;             // edges left to process during INIT
  reg [5:0] edge_ptr;                    // pointer to next edge to insert in INIT

  // Kahn's algorithm working sets/registers
  reg [NODES-1:0] S_current;   // current source set (bit vector)
  reg [NODES-1:0] S_prev;      // previous cycle S (for change detection)
  reg [2:0] alpha;             // currently removed source node index

  // Helper signals (combinational)
  wire [NODES-1:0] new_sources;
  function [NODES-1:0] get_new_sources;
    input [NODES-1:0] S_old, S_new;
    begin
      get_new_sources = S_new & ~S_old;
    end
  endfunction
  assign new_sources = get_new_sources(S_prev, S_current);

  function [NODES-1:0] priority_encoder;
    input [NODES-1:0] vec;
    integer i;
    begin
      priority_encoder = '0;
      for (i = 0; i < NODES; i = i + 1) begin
        if (vec[i]) begin
          priority_encoder = i;
          break;
        end
      end
    end
  endfunction

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      max_S_size <= '0;
      S_current <= '0;
      S_prev <= '0;
      alpha <= '0;
      indeg[0] <= '0; indeg[1] <= '0; indeg[2] <= '0; indeg[3] <= '0;
      indeg[4] <= '0; indeg[5] <= '0; indeg[6] <= '0; indeg[7] <= '0;
      adj[0] <= '0; adj[1] <= '0; adj[2] <= '0; adj[3] <= '0;
      adj[4] <= '0; adj[5] <= '0; adj[6] <= '0; adj[7] <= '0;
      remaining_edges <= '0;
      edge_ptr <= '0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize data structures for a new run
            max_S_size <= '0;
            S_current <= '0;
            S_prev <= '0;
            alpha <= '0;
            indeg[0] <= '0; indeg[1] <= '0; indeg[2] <= '0; indeg[3] <= '0;
            indeg[4] <= '0; indeg[5] <= '0; indeg[6] <= '0; indeg[7] <= '0;
            adj[0] <= '0; adj[1] <= '0; adj[2] <= '0; adj[3] <= '0;
            adj[4] <= '0; adj[5] <= '0; adj[6] <= '0; adj[7] <= '0;
            remaining_edges <= num_edges;
            edge_ptr <= 6'b0;
          end
        end

        INIT: begin
          if (remaining_edges == 0) begin
            // Build initial source set S: nodes with indegree 0
            S_prev <= '0;
            S_current <= '0;
            for (int i = 0; i < NODES; i = i + 1) begin
              if (i < num_nodes) begin
                S_current[i] <= (indeg[i] == 0);
              end else begin
                S_current[i] <= 1'b0;
              end
            end
            // Initialize max_S_size with |S|
            max_S_size <= $countones(S_current);
          end else begin
            // Add edges into adjacency matrix and indegree counts
            // Process one edge per cycle
            if (edge_src[edge_ptr] < num_nodes && edge_dst[edge_ptr] < num_nodes) begin
              adj[edge_src[edge_ptr]][edge_dst[edge_ptr]] <= 1'b1; // set adjacency bit
              indeg[edge_dst[edge_ptr]] <= indeg[edge_dst[edge_ptr]] + 1;
            end
            remaining_edges <= remaining_edges - 1;
            edge_ptr <= edge_ptr + 1;
          end
        end

        PROCESS: begin
          S_prev <= S_current;
          if (S_current == 0) begin
            // No more sources: done
            done <= 1'b1;
          end else begin
            // Remove one source alpha from S_current
            alpha <= priority_encoder(S_current);
            S_current[alpha] <= 1'b0;

            // Decrease indegree of alpha's neighbors and add any new sources
            for (int n = 0; n < NODES; n = n + 1) begin
              if (adj[alpha][n]) begin
                if (indeg[n] > 0) indeg[n] <= indeg[n] - 1;
                if (indeg[n] == 1) begin // will become zero after decrement
                  S_current[n] <= 1'b1;   // add to source set
                end
              end
            end

            // Update maximum source set size encountered (combinatorial read, registered write next cycle)
            // Use the current S_current value after potential insertions for this cycle
            max_S_size <= (max_S_size < $countones(S_current)) ? $countones(S_current) : max_S_size;
          end
        end

        DONE: begin
          // Hold done high until a new start or reset
          done <= 1'b1;
        end
      endcase
    end
  end

  // Next-state logic
  always_comb begin
    case (state)
      IDLE:  next_state = start ? INIT : IDLE;
      INIT:  next_state = (remaining_edges == 0) ? PROCESS : INIT;
      PROCESS: next_state = (S_current == 0) ? DONE : PROCESS;
      DONE:  next_state = (start ? IDLE : DONE);
      default: next_state = IDLE;
    endcase
  end

endmodule
