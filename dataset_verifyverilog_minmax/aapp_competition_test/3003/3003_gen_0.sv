module graph_color(
  input clk,
  input rst_n,
  input start,
  input [2:0] n_val,
  input [63:0] adjacency,
  output reg [3:0] colors,
  output reg done
);

  // State machine states
  localparam IDLE = 4'd0;
  localparam BOUNDS = 4'd1;
  localparam BACKTRACK_IDLE = 4'd2;
  localparam CHECK_VERTEX = 4'd3;
  localparam CHECK_NEIGHBORS = 4'd4;
  localparam SUCCESS = 4'd5;
  localparam FAILURE = 4'd6;
  localparam DONE = 4'd7;

  // Internal registers
  reg [3:0] state;
  reg [2:0] n_val_reg;
  reg [2:0] current_k;
  reg [3:0] max_degree;
  reg [7:0] vertex_order [0:7];
  reg [2:0] deg [0:7];
  
  // Backtracking registers
  reg [3:0] stack_ptr;
  reg [3:0] vertex_stack [0:7];
  reg [2:0] next_color_stack [0:7];
  reg [3:0] colors_reg [0:7];
  reg [3:0] current_v;
  reg [2:0] current_c;
  reg [3:0] j;
  reg [7:0] is_clique_valid;

  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      colors <= 4'd0;
      current_k <= 3'd0;
      max_degree <= 4'd0;
      stack_ptr <= 4'd0;
      j <= 4'd0;
      is_clique_valid <= 8'd1;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            n_val_reg <= n_val;
            state <= BOUNDS;
          end
        end

        BOUNDS: begin
          // Compute max_degree
          max_degree <= 4'd0;
          for (int i = 0; i < 8; i++) begin
            if (i < n_val_reg) begin
              deg[i] <= 3'd0;
              for (int j = 0; j < 8; j++) begin
                if (j < n_val_reg && adjacency[i*8 + j]) begin
                  deg[i] <= deg[i] + 1;
                end
              end
              if (deg[i] > max_degree) begin
                max_degree <= deg[i];
              end
            end
          end

          // Sort vertices by degree (descending)
          for (int i = 0; i < 8; i++) begin
            if (i < n_val_reg) begin
              vertex_order[i] <= i;
            end else begin
              vertex_order[i] <= 8'd0;
            end
          end

          // Bubble sort
          for (int i = 0; i < 7; i++) begin
            for (int j = 0; j < 7-i; j++) begin
              if (j < n_val_reg-1) begin
                if (deg[vertex_order[j]] < deg[vertex_order[j+1]]) begin
                  int temp = vertex_order[j];
                  vertex_order[j] <= vertex_order[j+1];
                  vertex_order[j+1] <= temp;
                end
              end
            end
          end

          // Check for complete graph
          if (max_degree == (n_val_reg - 1)) begin
            colors <= n_val_reg;
            done <= 1'b1;
            state <= IDLE;
          end else begin
            current_k <= 3'd2;
            state <= BACKTRACK_IDLE;
          end
        end

        BACKTRACK_IDLE: begin
          // Initialize backtracking stack for current_k
          stack_ptr <= 4'd0;
          vertex_stack[0] <= 4'd0;
          next_color_stack[0] <= 3'd0;
          for (int i = 0; i < 8; i++) begin
            if (i < n_val_reg) begin
              colors_reg[vertex_order[i]] <= 4'd15; // Unassigned
            end
          end
          state <= CHECK_VERTEX;
        end

        CHECK_VERTEX: begin
          if (stack_ptr < 0) begin
            // Backtracking stack empty, try next k
            if (current_k < (max_degree + 1)) begin
              current_k <= current_k + 1;
              state <= BACKTRACK_IDLE;
            end else begin
              colors <= max_degree + 1;
              done <= 1'b1;
              state <= IDLE;
            end
          end else begin
            current_v <= vertex_stack[stack_ptr];
            current_c <= next_color_stack[stack_ptr];
            if (current_c >= current_k) begin
              // Backtrack: unassign vertex
              colors_reg[vertex_order[current_v]] <= 4'd15;
              stack_ptr <= stack_ptr - 1;
            end else begin
              j <= 4'd0;
              is_clique_valid <= 8'd1;
              state <= CHECK_NEIGHBORS;
            end
          end
        end

        CHECK_NEIGHBORS: begin
          if (j == current_v) begin
            // No conflicts found
            colors_reg[vertex_order[current_v]] <= current_c;
            next_color_stack[stack_ptr] <= current_c + 1;
            if (current_v == (n_val_reg - 1)) begin
              // All vertices assigned
              colors <= current_k;
              done <= 1'b1;
              state <= IDLE;
            end else begin
              // Push next vertex
              stack_ptr <= stack_ptr + 1;
              vertex_stack[stack_ptr] <= current_v + 1;
              next_color_stack[stack_ptr] <= 3'd0;
              state <= CHECK_VERTEX;
            end
          end else begin
            // Check neighbor j
            int orig_j = vertex_order[j];
            int orig_v = vertex_order[current_v];
            if (adjacency[orig_j*8 + orig_v] && colors_reg[orig_j] == current_c) begin
              // Conflict found
              is_clique_valid <= 8'd0;
            end
            j <= j + 1;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule