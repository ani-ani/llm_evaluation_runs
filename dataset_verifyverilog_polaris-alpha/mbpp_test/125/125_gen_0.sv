module max_zero_diff(
  input clk,
  input rst_n,
  input start,
  input [15:0] data,
  input [3:0] str_len,
  output reg [4:0] max_diff,
  output reg done
);

  // Internal registers
  reg [3:0] idx;                 // index 0..15
  reg [3:0] len_reg;             // latched string length
  reg [15:0] data_reg;           // latched data
  reg [5:0] current_sum;         // signed: -16..+15
  reg [5:0] max_sum;             // signed:  0..+15 (we keep non-negative)
  reg busy;                      // processing flag

  // Signed wires for operations
  wire signed [5:0] cs_signed = current_sum;
  wire signed [5:0] ms_signed = max_sum;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      idx         <= 4'd0;
      len_reg     <= 4'd0;
      data_reg    <= 16'd0;
      current_sum <= 6'sd0;
      max_sum     <= 6'sd0;
      max_diff    <= 5'd0;
      done        <= 1'b0;
      busy        <= 1'b0;
    end else begin
      done <= 1'b0; // default

      if (start && !busy) begin
        // Initialize on start
        data_reg    <= data;
        len_reg     <= str_len;
        idx         <= 4'd0;
        current_sum <= 6'sd0;
        max_sum     <= 6'sd0;
        busy        <= 1'b1;
      end else if (busy) begin
        if (idx < len_reg) begin
          // Extract current bit from MSB first
          // For idx=0 -> bit_index=15, idx=1 -> 14, ...
          // bit_index = 15 - idx
          // Compute contribution: 0 -> +1, 1 -> -1
          if (data_reg[15 - idx] == 1'b0) begin
            current_sum <= cs_signed + 6'sd1;
          end else begin
            current_sum <= cs_signed - 6'sd1;
          end

          // Next cycle we need updated current_sum for clamp and max.
          // To keep it single-cycle per bit, compute using temporary.
          begin : sum_update_block
            reg signed [5:0] next_sum;
            reg signed [5:0] clamped_sum;
            reg signed [5:0] next_max;

            if (data_reg[15 - idx] == 1'b0)
              next_sum = cs_signed + 6'sd1;
            else
              next_sum = cs_signed - 6'sd1;

            if (next_sum < 6'sd0)
              clamped_sum = 6'sd0;
            else
              clamped_sum = next_sum;

            if (clamped_sum > ms_signed)
              next_max = clamped_sum;
            else
              next_max = ms_signed;

            current_sum <= clamped_sum;
            max_sum     <= next_max;
          end

          idx <= idx + 4'd1;
        end else begin
          // Completed processing
          max_diff <= (max_sum[5] == 1'b1) ? 5'd0 : max_sum[4:0];
          done    <= 1'b1;
          busy    <= 1'b0;
        end
      end
    end
  end

endmodule