module peg_sequence_checker(
  input clk,
  input rst_n,
  input start,
  input op,
  input [3:0] point_id,
  output reg valid,
  output reg done
);

  // Dependency matrix: M[i] = bitmask of dependencies for point i+1 (points 1-16)
  // NOTE: Initialize with actual dependencies as needed.
  parameter [15:0] DEPENDENCY [0:15] = '{
    16'h0000, // point 1
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

  reg [15:0] peg_mask;
  reg [15:0] support_mask [0:15];
  reg [5:0] step_count; // supports sequences up to 32 steps (0-31)

  integer i;

  wire [3:0] idx = (point_id == 4'd0) ? 4'd0 : (point_id - 4'd1);
  wire [15:0] required_deps = DEPENDENCY[idx];
  wire deps_satisfied = ((required_deps & peg_mask) == required_deps);

  // FSM-like control: operate when start is asserted and not done
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      peg_mask <= 16'h0000;
      for (i = 0; i < 16; i = i + 1) begin
        support_mask[i] <= 16'h0000;
      end
      valid <= 1'b1;
      done  <= 1'b0;
      step_count <= 6'd0;
    end else begin
      if (start && !done) begin
        if (valid) begin
          // process one step per cycle
          if (op == 1'b0) begin
            // ADD peg operation
            if (point_id != 4'd0 && deps_satisfied) begin
              peg_mask[point_id] <= 1'b1;
              support_mask[idx] <= peg_mask;
            end else begin
              valid <= 1'b0;
            end
          end else begin
            // REMOVE peg operation
            if (point_id != 4'd0 && (peg_mask == support_mask[idx])) begin
              peg_mask[point_id] <= 1'b0;
            end else begin
              valid <= 1'b0;
            end
          end

          // increment step count and check for completion
          step_count <= step_count + 6'd1;
          if (step_count == 6'd31 || !valid) begin
            done <= 1'b1;
          end
        end else begin
          // already invalid
          done <= 1'b1;
        end
      end

      // If start is low and not yet done, hold state; 'done' asserted only via logic above
    end
  end

endmodule