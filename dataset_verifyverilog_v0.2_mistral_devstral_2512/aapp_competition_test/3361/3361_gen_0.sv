module ore_partitioner (
  input clk,
  input rst_n,
  input start,
  input valid_in,
  input [11:0] dist_in,
  input [3:0] row_idx,
  input [3:0] col_idx,
  output reg [11:0] result,
  output reg done
);

  // Constants
  localparam NUM_NODES = 16;
  localparam NUM_EDGES = 120;
  localparam IDLE = 3'b000;
  localparam INPUT_WAIT = 3'b001;
  localparam SORTING = 3'b010;
  localparam PROCESSING = 3'b011;
  localparam DONE = 3'b100;

  // State machine
  reg [2:0] state = IDLE;

  // Edge buffer (FIFO)
  reg [11:0] edge_weights [0:NUM_EDGES-1];
  reg [3:0] edge_rows [0:NUM_EDGES-1];
  reg [3:0] edge_cols [0:NUM_EDGES-1];
  reg [6:0] edge_count = 0;

  // Sorting variables
  reg [6:0] sort_i = 0;
  reg [6:0] sort_j = 0;
  reg [11:0] temp_weight;
  reg [3:0] temp_row, temp_col;

  // Processing variables
  reg [11:0] max_A = 0, max_B = 0;
  reg [1:0] node_group [0:NUM_NODES-1]; // 0=unassigned, 1=Group A, 2=Group B
  reg [6:0] process_idx = 0;

  // Edge processing
  reg [3:0] u, v;
  reg [11:0] w;

  // Reset logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      edge_count <= 0;
      sort_i <= 0;
      sort_j <= 0;
      process_idx <= 0;
      max_A <= 0;
      max_B <= 0;
      done <= 0;
      result <= 0;
      for (int i = 0; i < NUM_NODES; i++) begin
        node_group[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INPUT_WAIT;
            edge_count <= 0;
          end
        end

        INPUT_WAIT: begin
          if (valid_in && edge_count < NUM_EDGES) begin
            edge_weights[edge_count] <= dist_in;
            edge_rows[edge_count] <= row_idx;
            edge_cols[edge_count] <= col_idx;
            edge_count <= edge_count + 1;
          end else if (edge_count == NUM_EDGES) begin
            state <= SORTING;
            sort_i <= 0;
            sort_j <= 0;
          end
        end

        SORTING: begin
          // Bubble sort implementation
          if (sort_i < NUM_EDGES-1) begin
            if (sort_j < NUM_EDGES-sort_i-1) begin
              if (edge_weights[sort_j] < edge_weights[sort_j+1]) begin
                // Swap weights
                temp_weight = edge_weights[sort_j];
                edge_weights[sort_j] = edge_weights[sort_j+1];
                edge_weights[sort_j+1] = temp_weight;
                
                // Swap rows
                temp_row = edge_rows[sort_j];
                edge_rows[sort_j] = edge_rows[sort_j+1];
                edge_rows[sort_j+1] = temp_row;
                
                // Swap cols
                temp_col = edge_cols[sort_j];
                edge_cols[sort_j] = edge_cols[sort_j+1];
                edge_cols[sort_j+1] = temp_col;
              end
              sort_j <= sort_j + 1;
            end else begin
              sort_j <= 0;
              sort_i <= sort_i + 1;
            end
          end else begin
            state <= PROCESSING;
            process_idx <= 0;
            // Initialize node groups
            for (int i = 0; i < NUM_NODES; i++) begin
              node_group[i] <= 0;
            end
          end
        end

        PROCESSING: begin
          if (process_idx < NUM_EDGES) begin
            u = edge_rows[process_idx];
            v = edge_cols[process_idx];
            w = edge_weights[process_idx];

            // Get current groups
            reg [1:0] group_u = node_group[u];
            reg [1:0] group_v = node_group[v];

            // Case 1: Different groups - skip
            if (group_u != 0 && group_v != 0 && group_u != group_v) begin
              // Do nothing
            
            // Case 2: Same group - update max
            else if (group_u == group_v && group_u != 0) begin
              if (group_u == 1) begin
                if (w > max_A) max_A <= w;
              end else begin
                if (w > max_B) max_B <= w;
              end
            
            // Case 3: Unassigned or same group - assign to group with smaller max
            else begin
              if (max_A <= max_B) begin
                // Assign to group A
                if (group_u == 0) node_group[u] <= 1;
                if (group_v == 0) node_group[v] <= 1;
                if (w > max_A) max_A <= w;
              end else begin
                // Assign to group B
                if (group_u == 0) node_group[u] <= 2;
                if (group_v == 0) node_group[v] <= 2;
                if (w > max_B) max_B <= w;
              end
            end

            process_idx <= process_idx + 1;
          end else begin
            state <= DONE;
            result <= max_A + max_B;
            done <= 1;
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule