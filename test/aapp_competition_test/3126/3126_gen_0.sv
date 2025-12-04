module frog_jump_calculator(
  input clk,
  input rst_n,
  input [1:0] cmd_type,
  input [15:0] cmd_data,
  input cmd_valid,
  output reg [4:0] total_jumps,
  output reg result_valid
);

  // Internal registers
  reg [15:0] frog_positions[0:7];
  reg [3:0]  frog_count;
  reg [15:0] current_target;

  // Pipeline registers for stage 2
  reg [15:0] frog_positions_s2[0:7];
  reg [3:0]  frog_count_s2;
  reg [15:0] current_target_s2;
  reg        valid_s2;

  integer i, j;

  // Stage 1: Command processing, update frog positions/target and capture for next stage
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      frog_count        <= 4'd0;
      current_target    <= 16'd0;
      for (i = 0; i < 8; i = i + 1) begin
        frog_positions[i] <= 16'd0;
      end

      // Reset pipeline registers
      frog_count_s2     <= 4'd0;
      current_target_s2 <= 16'd0;
      for (i = 0; i < 8; i = i + 1) begin
        frog_positions_s2[i] <= 16'd0;
      end
      valid_s2          <= 1'b0;

      // Reset outputs
      total_jumps       <= 5'd0;
      result_valid      <= 1'b0;
    end else begin
      // Default: no new valid in stage 2 unless cmd_valid
      valid_s2 <= cmd_valid;

      // Default: hold current arrays/target unless command
      // Apply command when cmd_valid is high
      if (cmd_valid) begin
        case (cmd_type)
          2'b00: begin // Add frog
            if (frog_count < 8) begin
              frog_positions[frog_count] <= cmd_data;
              frog_count <= frog_count + 1'b1;
            end
          end

          2'b01: begin // Remove frog: delete first matching position
            integer rm_idx;
            reg found;
            found  = 1'b0;
            rm_idx = 0;
            // Find first matching index
            for (i = 0; i < 8; i = i + 1) begin
              if (!found && (i < frog_count) && (frog_positions[i] == cmd_data)) begin
                found  = 1'b1;
                rm_idx = i;
              end
            end
            // If found, shift down
            if (found) begin
              for (j = rm_idx; j < 7; j = j + 1) begin
                if (j + 1 < frog_count)
                  frog_positions[j] <= frog_positions[j+1];
                else
                  frog_positions[j] <= 16'd0;
              end
              frog_count <= frog_count - 1'b1;
            end
          end

          2'b10: begin // Change target
            current_target <= cmd_data;
          end

          default: begin
            // No operation for other types
          end
        endcase
      end

      // Capture snapshot into stage-2 pipeline registers for jump calculation
      if (cmd_valid) begin
        frog_count_s2     <= frog_count;
        current_target_s2 <= current_target;
        for (i = 0; i < 8; i = i + 1) begin
          frog_positions_s2[i] <= frog_positions[i];
        end
      end

      // Stage 2: Perform jump calculation based on previous cycle snapshot
      // (Executed every cycle; result_valid tied to valid_s2 from previous cycle)
      begin : jump_calc_stage
        reg [4:0] max_k;
        reg [15:0] dist;
        reg [15:0] abs_diff;
        reg [4:0] k;
        reg [10:0] kk1_over2; // k(k+1)/2 fits within 11 bits for k<=31
        integer f;

        max_k = 5'd0;

        if (valid_s2) begin
          for (f = 0; f < 8; f = f + 1) begin
            if (f < frog_count_s2) begin
              // Compute absolute distance
              if (frog_positions_s2[f] >= current_target_s2)
                abs_diff = frog_positions_s2[f] - current_target_s2;
              else
                abs_diff = current_target_s2 - frog_positions_s2[f];

              // If distance is zero, k = 0
              if (abs_diff == 16'd0) begin
                k = 5'd0;
              end else begin
                // Find minimal k <= 31 such that:
                // 1) k(k+1)/2 >= abs_diff
                // 2) (k(k+1)/2 - abs_diff) is even (same parity condition)
                k = 5'd0;
                for (kk1_over2 = 0; (k < 5'd31) && (kk1_over2 < 11'd2047); k = k + 1'b1) begin
                  kk1_over2 = (k * (k + 1)) >> 1;
                  if ((kk1_over2 >= abs_diff) && (((kk1_over2 - abs_diff) & 1'b1) == 1'b0)) begin
                    // Found minimal k
                    disable for;
                  end
                end
              end

              // Track maximum k
              if (k > max_k)
                max_k = k;
            end
          end
        end

        // Update outputs
        total_jumps  <= valid_s2 ? max_k : total_jumps;
        result_valid <= valid_s2;
      end
    end
  end

endmodule
