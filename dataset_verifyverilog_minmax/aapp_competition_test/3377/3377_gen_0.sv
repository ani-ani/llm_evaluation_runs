module peg_sequence_checker(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start validation
  input op, // 0: add peg, 1: remove peg
  input [3:0] point_id, // 4-bit point ID (0-15)
  output reg valid, // 1 when current sequence is still valid
  output reg done // validation complete
);

  // Dependency matrix: M[i] = bitmask of dependencies for point (i+1)
  // Bits: [15:1] correspond to points 16..2; point 1 has no dependencies.
  // Replace with actual dependencies as needed.
  parameter [15:0] DEPENDENCY [0:15] = '{
    16'h0000, // 0 unused / point 1 dependencies (point 1)
    16'h0000, // point 2
    16'h0000, // point 3
    16'h0000, // point 4
    16'h0000, // point 5
    16'h0000, // point 6
    16'h0000, // point 7
    16'h0000, // point 8
    16'h0000, // point 9
    16'h0000, // point 10
    16'h0000, // point 11
    16'h0000, // point 12
    16'h0000, // point 13
    16'h0000, // point 14
    16'h0000, // point 15
    16'h0000  // point 16
  };

  // State
  typedef enum logic { IDLE = 1'b0, RUN = 1'b1 } state_t;
  state_t state;

  // Masks
  reg [15:0] peg_mask;           // bit j set <=> peg (j+1) is present
  reg [15:0] support_mask [0:15]; // support_mask[i] = peg_mask snapshot when peg (i+1) was added

  // Internal flags
  reg running; // asserted from start until done

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      running <= 1'b0;
      valid <= 1'b1;
      done <= 1'b0;
      peg_mask <= 16'h0000;
      for (int i = 0; i < 16; i++) support_mask[i] <= 16'h0000;
    end else begin
      // Defaults
      done <= 1'b0;

      case (state)
        IDLE: begin
          // Clear on idle (keep cleared even if start is held)
          peg_mask <= 16'h0000;
          for (int i = 0; i < 16; i++) support_mask[i] <= 16'h0000;
          valid <= 1'b1;
          running <= 1'b0;

          if (start) begin
            state <= RUN;
            running <= 1'b1;
            // valid remains 1 at start; done remains 0
          end
        end

        RUN: begin
          // When an invalid operation occurs, assert done and go back to IDLE next cycle
          // If start is deasserted (end of sequence), also assert done and return to IDLE.
          if (!valid || !start) begin
            if (!valid) done <= 1'b1;        // invalid -> done
            if (!start) done <= 1'b1;        // normal end -> done
            state <= IDLE;
            running <= 1'b0;
          end else begin
            // Valid operation this cycle
            if (op == 1'b0) begin: add_op
              // Add peg at point_id
              if (point_id inside {[4'd1:4'd16]}) begin
                // Check if point is not already present and dependencies are satisfied
                if (!peg_mask[point_id]) begin
                  if ((peg_mask & DEPENDENCY[point_id]) == DEPENDENCY[point_id]) begin
                    peg_mask[point_id] <= 1'b1;
                    support_mask[point_id] <= peg_mask;
                  end else begin
                    // Missing dependencies
                    valid <= 1'b0;
                  end
                end else begin
                  // Peg already present (idempotent add)
                  // Keep support_mask[point_id] unchanged
                end
              end else begin
                // Invalid point_id (0 or >16)
                valid <= 1'b0;
              end
            end else if (op == 1'b1) begin: remove_op
              // Remove peg at point_id
              if (point_id inside {[4'd1:4'd16]}) begin
                if (peg_mask[point_id]) begin
                  // Allowed only if current peg_mask equals the stored support mask
                  if (peg_mask == support_mask[point_id]) begin
                    peg_mask[point_id] <= 1'b0;
                  end else begin
                    valid <= 1'b0;
                  end
                end else begin
                  // Removing a non-existing peg is invalid
                  valid <= 1'b0;
                end
              end else begin
                // Invalid point_id (0 or >16)
                valid <= 1'b0;
              end
            end else begin
              // op is X/Z: treat as invalid
              valid <= 1'b0;
            end
          end
        end
      endcase
    end
  end

endmodule
