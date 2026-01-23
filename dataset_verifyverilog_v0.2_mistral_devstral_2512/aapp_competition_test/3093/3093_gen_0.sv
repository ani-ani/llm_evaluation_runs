module graph_coloring (
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [7:0] K,
  input [7:0] f [0:7],
  output reg [31:0] result,
  output reg done
);

  // Constants
  localparam MOD = 32'd1000000007;
  localparam IDLE = 3'd0;
  localparam INIT = 3'd1;
  localparam FIND_UNVISITED = 3'd2;
  localparam FIND_CYCLE = 3'd3;
  localparam PROCESS_COMPONENT = 3'd4;
  localparam UPDATE_RESULT = 3'd5;
  localparam DONE = 3'd6;

  // State registers
  reg [2:0] state = IDLE;
  reg [2:0] next_state = IDLE;

  // Temporary registers
  reg [7:0] visited [0:7];
  reg [2:0] current_node = 0;
  reg [2:0] cycle_length = 0;
  reg [2:0] component_size = 0;
  reg [31:0] temp_result = 1;
  reg [31:0] component_contrib = 1;
  reg [31:0] pow1 = 1;
  reg [31:0] pow2 = 1;
  reg [31:0] exponent = 0;
  reg [31:0] base = 0;
  reg [31:0] cycle_poly = 0;
  reg [31:0] temp = 0;
  reg [31:0] i = 0;
  reg [31:0] j = 0;
  reg [31:0] k = 0;
  reg [31:0] m = 0;
  reg [31:0] L = 0;
  reg [31:0] sign = 0;
  reg [31:0] count = 0;
  reg [31:0] node = 0;
  reg [31:0] next_node = 0;
  reg [31:0] start_node = 0;
  reg [31:0] cycle_start = 0;
  reg [31:0] cycle_found = 0;
  reg [31:0] in_cycle = 0;
  reg [31:0] cycle_nodes = 0;
  reg [31:0] non_cycle_nodes = 0;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
    end else begin
      state <= next_state;
    end
  end

  // State transitions and logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = INIT;
        end
      end

      INIT: begin
        // Initialize visited array
        for (i = 0; i < 8; i = i + 1) begin
          visited[i] = 0;
        end
        temp_result = 1;
        current_node = 0;
        next_state = FIND_UNVISITED;
      end

      FIND_UNVISITED: begin
        // Find next unvisited node
        for (i = 0; i < N; i = i + 1) begin
          if (!visited[i]) begin
            current_node = i;
            next_state = FIND_CYCLE;
            break;
          end
        end
        // All nodes visited
        if (i == N) begin
          next_state = DONE;
        end
      end

      FIND_CYCLE: begin
        // Traverse to find cycle
        start_node = current_node;
        node = start_node;
        cycle_start = 0;
        cycle_found = 0;
        in_cycle = 0;
        cycle_length = 0;
        component_size = 0;
        cycle_nodes = 0;
        non_cycle_nodes = 0;

        // Mark all nodes in component
        while (!visited[node]) begin
          visited[node] = 1;
          component_size = component_size + 1;
          next_node = f[node];
          if (next_node == 0) begin
            next_node = node + 1; // Self-loop for f[i] = 0
          end else begin
            next_node = next_node - 1; // Convert to 0-based
          end

          // Check if next_node is in current component
          if (visited[next_node] && next_node != node) begin
            // Found cycle
            if (!cycle_found) begin
              cycle_start = next_node;
              cycle_found = 1;
            end
          end

          node = next_node;
        end

        // Compute cycle length
        if (cycle_found) begin
          node = cycle_start;
          cycle_length = 0;
          do begin
            cycle_length = cycle_length + 1;
            node = f[node] - 1;
          end while (node != cycle_start);
        end

        next_state = PROCESS_COMPONENT;
      end

      PROCESS_COMPONENT: begin
        // Compute component contribution
        L = cycle_length;
        m = component_size;

        // Special case: K = 1
        if (K == 1) begin
          if (L == 0) begin
            component_contrib = 1; // No constraints
          end else begin
            component_contrib = 0; // Constraints exist
          end
        end
        // Special case: K = 2
        else if (K == 2) begin
          if (L % 2 == 1) begin
            component_contrib = 0; // Odd cycle
          end else begin
            component_contrib = 2; // Even cycle
          end
        end
        // General case
        else begin
          // Compute (K-1)^L
          base = K - 1;
          exponent = L;
          pow1 = 1;
          for (i = 0; i < exponent; i = i + 1) begin
            pow1 = (pow1 * base) % MOD;
          end

          // Compute (-1)^L * (K-1)
          sign = (L % 2 == 0) ? 1 : -1;
          pow2 = (sign * (K - 1)) % MOD;
          if (pow2 < 0) begin
            pow2 = pow2 + MOD;
          end

          // Cycle polynomial: (K-1)^L + (-1)^L * (K-1)
          cycle_poly = (pow1 + pow2) % MOD;

          // Compute (K-1)^(m-L)
          exponent = m - L;
          pow1 = 1;
          for (i = 0; i < exponent; i = i + 1) begin
            pow1 = (pow1 * base) % MOD;
          end

          // Component contribution
          component_contrib = (cycle_poly * pow1) % MOD;
        end

        next_state = UPDATE_RESULT;
      end

      UPDATE_RESULT: begin
        // Multiply into temp_result
        temp_result = (temp_result * component_contrib) % MOD;
        next_state = FIND_UNVISITED;
      end

      DONE: begin
        result = temp_result;
        done = 1;
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule