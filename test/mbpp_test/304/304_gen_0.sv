module rotation_index_finder(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [3:0]  arr [0:7],
  input  logic [2:0]  ranges [0:3][0:1],
  input  logic [1:0]  rotations,
  input  logic [2:0]  index,
  output logic [3:0]  result,
  output logic        done
);

  // Internal registers
  logic [2:0] curr_index;
  logic [1:0] rotations_reg;
  logic [2:0] index_reg;
  logic [2:0] step_cnt;      // counts from 0 up to rotations
  logic       active;        // indicates computation in progress

  // Synchronous logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      curr_index    <= 3'd0;
      rotations_reg <= 2'd0;
      index_reg     <= 3'd0;
      step_cnt      <= 3'd0;
      active        <= 1'b0;
      result        <= 4'd0;
      done          <= 1'b0;
    end else begin
      done <= 1'b0; // default, will be asserted when computation completes

      // Start new computation
      if (start) begin
        rotations_reg <= rotations;
        index_reg     <= index;
        curr_index    <= index;
        step_cnt      <= 3'd0;
        active        <= 1'b1;
      end else if (active) begin
        // If no rotations requested, complete immediately in next cycle
        if (rotations_reg == 2'd0) begin
          // After 1 cycle (step_cnt == 0), present result
          result <= arr[curr_index];
          done   <= 1'b1;
          active <= 1'b0;
        end else begin
          // There is at least one rotation to process
          if (step_cnt < rotations_reg) begin
            // Compute which rotation to apply (backwards)
            logic [1:0] rot_idx;
            rot_idx = rotations_reg - 1 - step_cnt;

            // Get range bounds
            logic [2:0] left_bound;
            logic [2:0] right_bound;
            left_bound  = ranges[rot_idx][0];
            right_bound = ranges[rot_idx][1];

            // Apply rotation if within range
            if ((curr_index >= left_bound) && (curr_index <= right_bound)) begin
              if (curr_index == left_bound)
                curr_index <= right_bound;
              else
                curr_index <= curr_index - 3'd1;
            end

            step_cnt <= step_cnt + 3'd1;

            // If this was the last rotation step, next state will output result
            if (step_cnt + 3'd1 == rotations_reg) begin
              // Next cycle we will output result
            end
          end else begin
            // All rotations processed; output result and finish
            result <= arr[curr_index];
            done   <= 1'b1;
            active <= 1'b0;
          end
        end
      end
    end
  end

endmodule