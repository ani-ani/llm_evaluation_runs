module puppy_recolor_check(
  input        clk,
  input        rst_n,
  input        start,
  input  [3:0] valid_length,
  input  [127:0] string_in,
  output reg   result,
  output reg   done
);

  reg [4:0] cnt [0:25];
  reg       has_dup;
  reg [3:0] i;
  reg [7:0] ch;
  reg [5:0] idx;
  reg       started;

  integer k;

  // Synchronous logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all counters and outputs
      for (k = 0; k < 26; k = k + 1) begin
        cnt[k] <= 5'd0;
      end
      result   <= 1'b0;
      done     <= 1'b0;
      has_dup  <= 1'b0;
      started  <= 1'b0;
      i        <= 4'd0;
    end else begin
      done <= 1'b0;

      if (start) begin
        // Clear counters at start of new computation
        for (k = 0; k < 26; k = k + 1) begin
          cnt[k] <= 5'd0;
        end
        has_dup <= 1'b0;
        i       <= 4'd0;
        started <= 1'b1;
      end else if (started) begin
        // Perform computation in this cycle (single-cycle after start)
        // Count characters and detect duplicates
        for (i = 0; i < valid_length; i = i + 1) begin
          ch = string_in[8*i +: 8];
          if (ch >= 8'h61 && ch <= 8'h7A) begin
            idx = ch - 8'h61;
            // Check current count before increment for duplicate
            if (cnt[idx] >= 5'd1) begin
              has_dup <= 1'b1;
            end
            cnt[idx] <= cnt[idx] + 5'd1;
          end
        end

        // Compute result based on conditions
        if (valid_length == 4'd1) begin
          result <= 1'b1;
        end else if (has_dup) begin
          result <= 1'b1;
        end else begin
          result <= 1'b0;
        end

        done    <= 1'b1;
        started <= 1'b0;
      end
    end
  end

endmodule