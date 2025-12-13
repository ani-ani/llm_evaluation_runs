module rescale_unit (
  input  clk,
  input  rst_n,
  input  start,
  input  [31:0] numbers [0:7],
  output reg [31:0] result  [0:7],
  output reg       done
);

  // Internal registers
  reg [31:0] min_val;
  reg [31:0] max_val;
  reg [31:0] range;

  reg [31:0] num_reg   [0:7];
  reg [31:0] num_sub   [0:7];
  reg [31:0] accum     [0:7];
  reg [31:0] remainder [0:7];

  reg [3:0]  iter_cnt;
  reg        busy;
  reg        range_zero;

  integer i;

  // Start and main FSM/iteration logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous reset
      min_val     <= 32'hFFFFFFFF;
      max_val     <= 32'h00000000;
      range       <= 32'h00000000;
      iter_cnt    <= 4'd0;
      busy        <= 1'b0;
      done        <= 1'b0;
      range_zero  <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        num_reg[i]   <= 32'h00000000;
        num_sub[i]   <= 32'h00000000;
        accum[i]     <= 32'h00000000;
        remainder[i] <= 32'h00000000;
        result[i]    <= 32'h00000000;
      end
    end else begin
      // Default done low unless asserted at completion
      done <= 1'b0;

      if (start && !busy) begin
        // Latch inputs
        for (i = 0; i < 8; i = i + 1) begin
          num_reg[i] <= numbers[i];
        end

        // Find min and max (combinational-style in this clock)
        min_val <= numbers[0];
        max_val <= numbers[0];
        for (i = 1; i < 8; i = i + 1) begin
          if (numbers[i] < min_val)
            min_val <= numbers[i];
          if (numbers[i] > max_val)
            max_val <= numbers[i];
        end

        iter_cnt   <= 4'd0;
        busy       <= 1'b1;
        range_zero <= 1'b0;
      end else if (busy) begin
        // Once inputs captured and min/max computed, proceed
        if (iter_cnt == 4'd0) begin
          // Compute range and zero-guard; also compute (numbers_i - min)
          range <= max_val - min_val;
          if ((max_val - min_val) == 32'd0) begin
            range_zero <= 1'b1;
          end else begin
            range_zero <= 1'b0;
          end

          for (i = 0; i < 8; i = i + 1) begin
            if (numbers[i] >= min_val)
              num_sub[i] <= numbers[i] - min_val;
            else
              num_sub[i] <= 32'd0;
          end

          // Initialize accumulators and remainders for iterative division
          for (i = 0; i < 8; i = i + 1) begin
            accum[i]     <= 32'd0;
            remainder[i] <= 32'd0;
          end

          iter_cnt <= 4'd1;
        end else if (iter_cnt <= 4'd15) begin
          // 15-cycle iterative restoring division for each of 8 values
          // Compute one result bit per cycle for Q16.16 output
          for (i = 0; i < 8; i = i + 1) begin
            if (range_zero) begin
              // If range zero, all outputs forced to 0
              accum[i]     <= 32'd0;
              remainder[i] <= 32'd0;
            end else begin
              // Shift left remainder and bring in next MSB from (num_sub << 15)
              // We effectively normalize (num_sub[i]) over 15 bits to form [0,1]
              // Build a 47-bit shifted numerator: num_sub[i] << 15
              // Iterative restoring division by 32-bit range.
              // Use 48-bit for remainder_internal to hold shifts.
              reg [47:0] rem_ext;
              reg [47:0] num_shift;
              reg [47:0] rem_next;

              num_shift = {num_sub[i], 15'd0};

              rem_ext = {remainder[i][31:0], 16'd0};
              rem_ext = rem_ext << 1;
              // Bring in next bit of numerator
              rem_ext[0] = num_shift[47 - iter_cnt + 1];

              if (rem_ext[47:16] >= range) begin
                rem_next = rem_ext - {range,16'd0};
                remainder[i] <= rem_next[47:16];
                accum[i] <= {accum[i][30:0], 1'b1};
              end else begin
                remainder[i] <= rem_ext[47:16];
                accum[i] <= {accum[i][30:0], 1'b0};
              end
            end
          end

          if (iter_cnt == 4'd15) begin
            // Final cycle: latch results and finish
            for (i = 0; i < 8; i = i + 1) begin
              if (range_zero)
                result[i] <= 32'd0;
              else
                result[i] <= accum[i];
            end
            done     <= 1'b1;
            busy     <= 1'b0;
            iter_cnt <= 4'd0;
          end else begin
            iter_cnt <= iter_cnt + 4'd1;
          end
        end
      end
    end
  end

endmodule