module min_transmission_cost (
  input clk,
  input rst_n,
  input start,
  input [7:0] tree_a_nodes,
  input [7:0] tree_b_nodes,
  input [7:0] tree_a_adj [0:7],
  input [7:0] tree_b_adj [0:7],
  output reg [31:0] min_cost,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    COMPUTE_DIST_A,
    COMPUTE_DIST_B,
    FIND_CENTER_A,
    FIND_CENTER_B,
    CALCULATE_COST,
    DONE
  } state_t;

  state_t state, next_state;

  // Distance matrices (8x8)
  reg [3:0] dist_a [0:7][0:7];
  reg [3:0] dist_b [0:7][0:7];

  // Center nodes
  reg [2:0] center_a, center_b;

  // Counters
  reg [2:0] i, j, k;
  reg [5:0] counter;

  // Temporary registers
  reg [3:0] temp_dist;
  reg [31:0] sum_a, sum_b;
  reg [31:0] min_sum_a, min_sum_b;
  reg [31:0] center_dist_a, center_dist_b;
  reg [31:0] cost_accum;

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      min_cost <= 0;
      counter <= 0;
    end else begin
      state <= next_state;
    end
  end

  // State transition logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = COMPUTE_DIST_A;
      end
      COMPUTE_DIST_A: begin
        if (counter == 19) next_state = COMPUTE_DIST_B;
      end
      COMPUTE_DIST_B: begin
        if (counter == 38) next_state = FIND_CENTER_A;
      end
      FIND_CENTER_A: begin
        if (counter == 57) next_state = FIND_CENTER_B;
      end
      FIND_CENTER_B: begin
        if (counter == 76) next_state = CALCULATE_COST;
      end
      CALCULATE_COST: begin
        if (counter == 199) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Main computation logic
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset all registers
      for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
          dist_a[i][j] <= 0;
          dist_b[i][j] <= 0;
        end
      end
      center_a <= 0;
      center_b <= 0;
      i <= 0;
      j <= 0;
      k <= 0;
      sum_a <= 0;
      sum_b <= 0;
      min_sum_a <= 0;
      min_sum_b <= 0;
      center_dist_a <= 0;
      center_dist_b <= 0;
      cost_accum <= 0;
    end else begin
      case (state)
        COMPUTE_DIST_A: begin
          // Initialize distance matrix for tree A
          if (counter < 8) begin
            for (j = 0; j < 8; j = j + 1) begin
              if (tree_a_adj[counter][j]) begin
                dist_a[counter][j] <= 1;
                dist_a[j][counter] <= 1;
              end else begin
                dist_a[counter][j] <= (counter == j) ? 0 : 8'hFF;
                dist_a[j][counter] <= (counter == j) ? 0 : 8'hFF;
              end
            end
          end
          // Floyd-Warshall algorithm
          else if (counter < 19) begin
            k <= counter - 8;
            for (i = 0; i < 8; i = i + 1) begin
              for (j = 0; j < 8; j = j + 1) begin
                if (dist_a[i][k] + dist_a[k][j] < dist_a[i][j]) begin
                  dist_a[i][j] <= dist_a[i][k] + dist_a[k][j];
                end
              end
            end
          end
        end

        COMPUTE_DIST_B: begin
          // Initialize distance matrix for tree B
          if (counter < 27) begin
            for (j = 0; j < 8; j = j + 1) begin
              if (tree_b_adj[counter - 19][j]) begin
                dist_b[counter - 19][j] <= 1;
                dist_b[j][counter - 19] <= 1;
              end else begin
                dist_b[counter - 19][j] <= (counter - 19 == j) ? 0 : 8'hFF;
                dist_b[j][counter - 19] <= (counter - 19 == j) ? 0 : 8'hFF;
              end
            end
          end
          // Floyd-Warshall algorithm
          else if (counter < 38) begin
            k <= counter - 27;
            for (i = 0; i < 8; i = i + 1) begin
              for (j = 0; j < 8; j = j + 1) begin
                if (dist_b[i][k] + dist_b[k][j] < dist_b[i][j]) begin
                  dist_b[i][j] <= dist_b[i][k] + dist_b[k][j];
                end
              end
            end
          end
        end

        FIND_CENTER_A: begin
          // Find center node for tree A
          if (counter < 57) begin
            i <= counter - 38;
            sum_a <= 0;
            for (j = 0; j < 8; j = j + 1) begin
              if (i != j) begin
                sum_a <= sum_a + (dist_a[i][j] * dist_a[i][j]);
              end
            end
            if (counter == 38 || sum_a < min_sum_a) begin
              min_sum_a <= sum_a;
              center_a <= i;
            end
          end
        end

        FIND_CENTER_B: begin
          // Find center node for tree B
          if (counter < 76) begin
            i <= counter - 57;
            sum_b <= 0;
            for (j = 0; j < 8; j = j + 1) begin
              if (i != j) begin
                sum_b <= sum_b + (dist_b[i][j] * dist_b[i][j]);
              end
            end
            if (counter == 57 || sum_b < min_sum_b) begin
              min_sum_b <= sum_b;
              center_b <= i;
            end
          end
        end

        CALCULATE_COST: begin
          // Calculate transmission cost
          if (counter == 76) begin
            cost_accum <= 0;
            // Sum of squared distances for tree A
            for (i = 0; i < 8; i = i + 1) begin
              for (j = i + 1; j < 8; j = j + 1) begin
                cost_accum <= cost_accum + (dist_a[i][j] * dist_a[i][j]);
              end
            end
            // Sum of squared distances for tree B
            for (i = 0; i < 8; i = i + 1) begin
              for (j = i + 1; j < 8; j = j + 1) begin
                cost_accum <= cost_accum + (dist_b[i][j] * dist_b[i][j]);
              end
            end
            // N*M term
            cost_accum <= cost_accum + (tree_a_nodes * tree_b_nodes);
            // Center distances
            center_dist_a <= dist_a[center_a][center_b];
            center_dist_b <= dist_b[center_a][center_b];
            // Final term
            cost_accum <= cost_accum + (tree_a_nodes * tree_b_nodes) * 
                         (center_dist_a * center_dist_a + 
                          center_dist_b * center_dist_b + 
                          2 * center_dist_a * center_dist_b);
          end
        end

        DONE: begin
          done <= 1;
          min_cost <= cost_accum;
        end

        default: begin
          // Do nothing
        end
      endcase

      // Increment counter
      if (state != IDLE && state != DONE) begin
        counter <= counter + 1;
      end
    end
  end

endmodule