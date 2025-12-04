module lowercase_filter (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [63:0] str_in,
  output logic [63:0] str_out,
  output logic [3:0]  valid_len,
  output logic        done
);

  logic [2:0] idx;        // byte index (0..7)
  logic       run;        // 1 during the 8-cycle processing window
  logic       start_d;    // delayed start to detect pulse

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      str_out   <= 64'b0;
      valid_len <= 4'b0;
      idx       <= 3'b0;
      run       <= 1'b0;
      done      <= 1'b0;
      start_d   <= 1'b0;
    end else begin
      start_d <= start;

      if (start && !start_d) begin
        // New operation: reset outputs and start processing
        str_out   <= 64'b0;
        valid_len <= 4'b0;
        idx       <= 3'b0;
        run       <= 1'b1;
        done      <= 1'b0;
      end else if (run) begin
        // Process one input byte per cycle
        if ((str_in[8*idx +: 8] < 8'h61) || (str_in[8*idx +: 8] > 8'h7A)) begin
          // Not a lowercase letter: store it in the next position of str_out
          str_out[8*valid_len +: 8] <= str_in[8*idx +: 8];
          valid_len                 <= valid_len + 1;
        end
        // Advance index
        if (idx == 3'd7) begin
          idx <= 3'd0;
          run <= 1'b0;
          done <= 1'b1; // done asserted for 1 cycle after processing completes
        end else begin
          idx <= idx + 1;
          done <= 1'b0;
        end
      end else begin
        // Idle or just completed
        done <= 1'b0;
      end
    end
  end

endmodule
