module domino_tiling_maxsum(
  input clk,
  input rst_n,
  input start,
  input [19:0] row0_col0,
  input [19:0] row0_col1,
  input [19:0] row0_col2,
  input [19:0] row1_col0,
  input [19:0] row1_col1,
  input [19:0] row1_col2,
  input [19:0] row2_col0,
  input [19:0] row2_col1,
  input [19:0] row2_col2,
  input [19:0] row3_col0,
  input [19:0] row3_col1,
  input [19:0] row3_col2,
  output reg [23:0] max_sum,
  output reg done
);

  // State machine states
  localparam IDLE = 3'b000;
  localparam CALC_ROW0 = 3'b001;
  localparam CALC_ROW1 = 3'b010;
  localparam CALC_ROW2 = 3'b011;
  localparam CALC_ROW3 = 3'b100;
  localparam DONE = 3'b101;

  // State and cycle counter
  reg [2:0] state;
  reg [0:0] cycle_count;

  // DP table: current and new
  reg signed [23:0] dp [0:7][0:2];
  reg signed [23:0] new_dp [0:7][0:2];

  // Current row index
  integer row_index;

  // Values for current row and next row
  reg signed [19:0] current_row [0:2];
  reg signed [19:0] next_row [0:2];

  // For cycle when computing new_dp
  reg [7:0] S;
  reg [2:0] U_S;
  reg pair_01, pair_12;
  reg signed [23:0] cells_covered_sum;
  integer cell;
  reg [2:0] mask_occupied;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_count <= 1'b0;
      max_sum <= 24'h800000; // Initialize to minimum signed
      done <= 1'b0;
      // Initialize DP table
      for (int i = 0; i < 8; i++) begin
        for (int j = 0; j < 3; j++) begin
          dp[i][j] <= 24'h800000; // Invalid state
        end
      end
      dp[0][0] <= 24'h0; // Initial state: mask=0, k=0, sum=0
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CALC_ROW0;
            cycle_count <= 1'b0;
            row_index <= 0;
          end
        end
        CALC_ROW0: begin
          if (cycle_count == 1'b0) begin
            // Compute new_dp for row1 based on row0
            row_index <= 0;
            // Set current and next row values
            current_row[0] <= row0_col0;
            current_row[1] <= row0_col1;
            current_row[2] <= row0_col2;
            next_row[0] <= row1_col0;
            next_row[1] <= row1_col1;
            next_row[2] <= row1_col2;
            // Compute new_dp
            compute_new_dp(0, 1); // allow_vertical=1
            cycle_count <= 1'b1;
          end else begin
            dp <= new_dp; // Update dp to new_dp for row1
            state <= CALC_ROW1;
            cycle_count <= 1'b0;
          end
        end
        CALC_ROW1: begin
          if (cycle_count == 1'b0) begin
            row_index <= 1;
            current_row[0] <= row1_col0;
            current_row[1] <= row1_col1;
            current_row[2] <= row1_col2;
            next_row[0] <= row2_col0;
            next_row[1] <= row2_col1;
            next_row[2] <= row2_col2;
            compute_new_dp(1, 1);
            cycle_count <= 1'b1;
          end else begin
            dp <= new_dp;
            state <= CALC_ROW2;
            cycle_count <= 1'b0;
          end
        end
        CALC_ROW2: begin
          if (cycle_count == 1'b0) begin
            row_index <= 2;
            current_row[0] <= row2_col0;
            current_row[1] <= row2_col1;
            current_row[2] <= row2_col2;
            next_row[0] <= row3_col0;
            next_row[1] <= row3_col1;
            next_row[2] <= row3_col2;
            compute_new_dp(2, 1);
            cycle_count <= 1'b1;
          end else begin
            dp <= new_dp;
            state <= CALC_ROW3;
            cycle_count <= 1'b0;
          end
        end
        CALC_ROW3: begin
          if (cycle_count == 1'b0) begin
            row_index <= 3;
            current_row[0] <= row3_col0;
            current_row[1] <= row3_col1;
            current_row[2] <= row3_col2;
            next_row[0] <= 20'h0; // No next row, so zero
            next_row[1] <= 20'h0;
            next_row[2] <= 20'h0;
            compute_new_dp(3, 0); // No vertical dominoes allowed
            cycle_count <= 1'b1;
          end else begin
            dp <= new_dp;
            state <= DONE;
            cycle_count <= 1'b0;
          end
        end
        DONE: begin
          max_sum <= dp[0][2]; // Mask=0, k=2
          done <= 1'b1;
          // Stay in DONE until reset
        end
      endcase
    end
  end

  // Task to compute new_dp for a given row
  task compute_new_dp;
    input integer row;
    input bit allow_vertical; // 1 if vertical dominoes allowed, 0 otherwise
    begin
      // Initialize new_dp to invalid
      for (int m = 0; m < 8; m++) begin
        for (int k = 0; k < 3; k++) begin
          new_dp[m][k] = 24'h800000;
        end
      end

      // Iterate over all current states
      for (int m = 0; m < 8; m++) begin
        for (int k = 0; k < 3; k++) begin
          if (dp[m][k] != 24'h800000) begin
            // Unoccupied cells U: where m bit is 0
            U_S = ~m[2:0]; // U is the bitmask of unoccupied cells
            // Iterate over all subsets S of U
            for (S = 0; S < 8; S++) begin
              if (allow_vertical) begin
                // S must be subset of U: (S & m) == 0
                if ((S & m) == 0) begin
                  process_transition(m, k, S, allow_vertical);
                end
              end else begin
                // Only S=0 is allowed when vertical not allowed
                if (S == 0) begin
                  process_transition(m, k, S, allow_vertical);
                end
              end
            end
          end
        end
      end
    end
  endtask

  // Process a single transition for a given state
  task process_transition;
    input [2:0] m;
    input integer k;
    input [7:0] S;
    input bit allow_vertical;
    reg [2:0] m_next;
    reg [2:0] U_S_local;
    integer d0;
    reg signed [23:0] sum_added;
    integer new_k;
    begin
      m_next = S[2:0];
      d0 = $countones(S); // Number of vertical dominoes
      // Cells covered from occupied mask: where m bit is 1
      mask_occupied = m[2:0];
      // U-S: unoccupied cells not in S
      U_S_local = ~m[2:0] & ~S[2:0];
      // Check for horizontal dominoes
      pair_01 = U_S_local[0] & U_S_local[1];
      pair_12 = U_S_local[1] & U_S_local[2];

      // Option 1: no horizontal domino
      if (1) begin
        cells_covered_sum = 24'h0;
        // Add values of cells covered by occupied mask and S
        for (cell = 0; cell < 3; cell++) begin
          if (mask_occupied[cell] || S[cell]) begin
            cells_covered_sum = cells_covered_sum + current_row[cell];
          end
        end
        new_k = k + d0;
        if (new_k <= 2) begin
          if (dp[m][k] + cells_covered_sum > new_dp[m_next][new_k]) begin
            new_dp[m_next][new_k] = dp[m][k] + cells_covered_sum;
          end
        end
      end

      // Option 2: horizontal domino on (0,1) if available
      if (pair_01) begin
        cells_covered_sum = 24'h0;
        for (cell = 0; cell < 3; cell++) begin
          if (mask_occupied[cell] || S[cell]) begin
            cells_covered_sum = cells_covered_sum + current_row[cell];
          end
        end
        // Add cells 0 and 1 for horizontal domino
        cells_covered_sum = cells_covered_sum + current_row[0] + current_row[1];
        new_k = k + d0 + 1;
        if (new_k <= 2) begin
          if (dp[m][k] + cells_covered_sum > new_dp[m_next][new_k]) begin
            new_dp[m_next][new_k] = dp[m][k] + cells_covered_sum;
          end
        end
      end

      // Option 3: horizontal domino on (1,2) if available
      if (pair_12) begin
        cells_covered_sum = 24'h0;
        for (cell = 0; cell < 3; cell++) begin
          if (mask_occupied[cell] || S[cell]) begin
            cells_covered_sum = cells_covered_sum + current_row[cell];
          end
        end
        // Add cells 1 and 2 for horizontal domino
        cells_covered_sum = cells_covered_sum + current_row[1] + current_row[2];
        new_k = k + d0 + 1;
        if (new_k <= 2) begin
          if (dp[m][k] + cells_covered_sum > new_dp[m_next][new_k]) begin
            new_dp[m_next][new_k] = dp[m][k] + cells_covered_sum;
          end
        end
      end
    end
  endtask

endmodule
