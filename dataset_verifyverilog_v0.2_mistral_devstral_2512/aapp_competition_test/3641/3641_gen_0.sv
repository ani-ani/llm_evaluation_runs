module necklace_splitter (
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [2:0] n,
  input [7:0] beads [0:7],
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_TOTAL,
    FIND_CUTS,
    VALIDATE,
    DONE
  } state_t;

  state_t state;
  reg [15:0] total_sum;
  reg [15:0] target_sum;
  reg [2:0] current_start;
  reg [2:0] segment_count;
  reg [15:0] segment_sum;
  reg [2:0] cut_positions [0:2]; // For k-1 cuts (max 3)
  reg [2:0] cut_index;
  reg [2:0] bead_index;
  reg [2:0] segment_index;
  reg [2:0] cut_config;
  reg [2:0] max_cut_config;
  reg valid_config;

  // Compute total sum
  always @(*) begin
    total_sum = 0;
    for (int i = 0; i < n; i++) begin
      total_sum = total_sum + beads[i];
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      total_sum <= 0;
      target_sum <= 0;
      current_start <= 0;
      segment_count <= 0;
      segment_sum <= 0;
      cut_index <= 0;
      bead_index <= 0;
      segment_index <= 0;
      cut_config <= 0;
      max_cut_config <= 0;
      valid_config <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECK_TOTAL;
          end
        end

        CHECK_TOTAL: begin
          // Compute total and target
          target_sum <= total_sum / k;
          if (total_sum % k == 0 && k > 0 && n > 0) begin
            // Calculate max cut configurations
            max_cut_config <= (n-1) * (n-2) * (n-3) / 6; // C(n-1, k-1)
            if (max_cut_config == 0) begin
              max_cut_config <= 1;
            end
            state <= FIND_CUTS;
          end else begin
            result <= 0;
            done <= 1;
            state <= DONE;
          end
        end

        FIND_CUTS: begin
          // Generate cut configurations
          if (cut_config < max_cut_config) begin
            // Simple enumeration for small n
            // For k=2: 1 cut, for k=3: 2 cuts, for k=4: 3 cuts
            // This is a simplified approach
            cut_positions[0] <= (cut_config % (n-1)) + 1;
            if (k > 2) begin
              cut_positions[1] <= ((cut_config / (n-1)) % (n-2)) + 2;
            end
            if (k > 3) begin
              cut_positions[2] <= ((cut_config / ((n-1)*(n-2))) % (n-3)) + 3;
            end
            state <= VALIDATE;
          end else begin
            result <= 0;
            done <= 1;
            state <= DONE;
          end
        end

        VALIDATE: begin
          // Validate current cut configuration
          segment_sum <= 0;
          segment_count <= 0;
          bead_index <= 0;
          segment_index <= 0;
          valid_config <= 1;
          state <= VALIDATE;
        end

        DONE: begin
          // Stay in DONE until reset
        end

        default: state <= IDLE;
      endcase
    end
  end

  // Validation logic
  always @(posedge clk) begin
    if (state == VALIDATE) begin
      // Calculate segment sum
      if (bead_index < n) begin
        segment_sum <= segment_sum + beads[bead_index];
        bead_index <= bead_index + 1;

        // Check if we've reached a cut position
        if (bead_index == cut_positions[segment_index] && segment_index < k-1) begin
          if (segment_sum != target_sum) begin
            valid_config <= 0;
          end
          segment_sum <= 0;
          segment_index <= segment_index + 1;
        end
      end else begin
        // Final segment check
        if (segment_sum != target_sum) begin
          valid_config <= 0;
        end

        if (valid_config) begin
          result <= 1;
          done <= 1;
          state <= DONE;
        end else begin
          cut_config <= cut_config + 1;
          state <= FIND_CUTS;
        end
      end
    end
  end

endmodule