module matrix_recovery (
  input clk,
  input rst_n,
  input start,
  input [3:0] row_parity,
  input [3:0] col_parity,
  output reg [15:0] matrix_out,
  output reg valid,
  output reg impossible,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    SEARCH,
    VALIDATE,
    COMPLETE,
    IMPOSSIBLE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [15:0] candidate_matrix;
  reg [3:0] ones_count;
  reg [15:0] max_ones_matrix;
  reg max_ones_found;
  reg [3:0] search_counter;
  reg [15:0] current_matrix;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      candidate_matrix <= 16'h0;
      ones_count <= 4'd0;
      max_ones_matrix <= 16'h0;
      max_ones_found <= 1'b0;
      search_counter <= 4'd0;
      current_matrix <= 16'h0;
      matrix_out <= 16'h0;
      valid <= 1'b0;
      impossible <= 1'b0;
      done <= 1'b0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = SEARCH;
      end
      SEARCH: begin
        if (search_counter == 4'd15) begin
          if (max_ones_found) next_state = COMPLETE;
          else next_state = IMPOSSIBLE;
        end else begin
          next_state = VALIDATE;
        end
      end
      VALIDATE: begin
        next_state = SEARCH;
      end
      COMPLETE: begin
        next_state = IDLE;
      end
      IMPOSSIBLE: begin
        next_state = IDLE;
      end
    endcase
  end

  // Search logic
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state transition
    end else if (state == SEARCH) begin
      if (search_counter == 4'd0) begin
        candidate_matrix <= 16'hFFFF;
        ones_count <= 4'd16;
      end else begin
        // Generate next candidate with one less '1'
        if (ones_count > 4'd0) begin
          candidate_matrix <= candidate_matrix - 1;
          if ($countones(candidate_matrix) != ones_count) begin
            candidate_matrix <= {16{$random}} & ((1 << ones_count) - 1);
          end
        end else begin
          candidate_matrix <= 16'h0;
        end
      end
      search_counter <= search_counter + 1;
    end
  end

  // Validation logic
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state transition
    end else if (state == VALIDATE) begin
      reg [3:0] calculated_row_parity [0:3];
      reg [3:0] calculated_col_parity [0:3];
      reg row_valid, col_valid;
      reg [3:0] i, j;

      // Calculate row parities
      for (i = 0; i < 4; i = i + 1) begin
        calculated_row_parity[i] = ^candidate_matrix[(i*4)+3:(i*4)];
      end

      // Calculate column parities
      for (j = 0; j < 4; j = j + 1) begin
        calculated_col_parity[j] = ^{candidate_matrix[j+12], candidate_matrix[j+8], candidate_matrix[j+4], candidate_matrix[j]};
      end

      // Check if parities match
      row_valid = (calculated_row_parity[0] == row_parity[0]) &&
                  (calculated_row_parity[1] == row_parity[1]) &&
                  (calculated_row_parity[2] == row_parity[2]) &&
                  (calculated_row_parity[3] == row_parity[3]);

      col_valid = (calculated_col_parity[0] == col_parity[0]) &&
                  (calculated_col_parity[1] == col_parity[1]) &&
                  (calculated_col_parity[2] == col_parity[2]) &&
                  (calculated_col_parity[3] == col_parity[3]);

      if (row_valid && col_valid) begin
        if (ones_count > $countones(max_ones_matrix) ||
            (ones_count == $countones(max_ones_matrix) && candidate_matrix < max_ones_matrix)) begin
          max_ones_matrix <= candidate_matrix;
          max_ones_found <= 1'b1;
        end
      end
    end
  end

  // Output logic
  always @(posedge clk) begin
    if (!rst_n) begin
      matrix_out <= 16'h0;
      valid <= 1'b0;
      impossible <= 1'b0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          matrix_out <= 16'h0;
          valid <= 1'b0;
          impossible <= 1'b0;
          done <= 1'b0;
        end
        SEARCH: begin
          matrix_out <= 16'h0;
          valid <= 1'b0;
          impossible <= 1'b0;
          done <= 1'b0;
        end
        VALIDATE: begin
          matrix_out <= 16'h0;
          valid <= 1'b0;
          impossible <= 1'b0;
          done <= 1'b0;
        end
        COMPLETE: begin
          matrix_out <= max_ones_matrix;
          valid <= 1'b1;
          impossible <= 1'b0;
          done <= 1'b1;
        end
        IMPOSSIBLE: begin
          matrix_out <= 16'h0;
          valid <= 1'b0;
          impossible <= 1'b1;
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule