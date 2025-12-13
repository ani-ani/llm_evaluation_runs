module unique_substrings(
  input clk,
  input rst_n,
  input start,
  input [39:0] chars_in,
  output reg [39:0] chars_out,
  output reg valid,
  output reg done
);

  // Internal signals
  reg [4:0] chars[0:7];
  reg [4:0] sorted[0:7];
  reg [4:0] rearr[0:7];

  reg [4:0] freq [0:25];

  reg [4:0] ch0, ch1, ch2, ch3, ch4, ch5, ch6, ch7;

  reg        busy;
  reg [4:0]  cycle_cnt; // up to 20

  // Extract chars (combinational view of chars_in)
  // chars_in[39:35] -> char0 ... [4:0] -> char7
  always @* begin
    chars[0] = chars_in[39:35];
    chars[1] = chars_in[34:30];
    chars[2] = chars_in[29:25];
    chars[3] = chars_in[24:20];
    chars[4] = chars_in[19:15];
    chars[5] = chars_in[14:10];
    chars[6] = chars_in[9:5];
    chars[7] = chars_in[4:0];
  end

  // Main sequential control
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset
      valid      <= 1'b0;
      done       <= 1'b0;
      chars_out  <= 40'd0;
      busy       <= 1'b0;
      cycle_cnt  <= 5'd0;
      // clear freq
      for (i = 0; i < 26; i = i + 1) begin
        freq[i] <= 5'd0;
      end
    end else begin
      // Default outputs
      done <= 1'b0;

      if (start && !busy) begin
        // Start operation
        busy      <= 1'b1;
        cycle_cnt <= 5'd0;
        valid     <= 1'b0;
        chars_out <= 40'd0;

        // Initialize frequency counts
        for (i = 0; i < 26; i = i + 1) begin
          freq[i] <= 5'd0;
        end
      end else if (busy) begin
        cycle_cnt <= cycle_cnt + 5'd1;

        // Cycle 0-? : frequency counting (single-cycle combinational based on chars[])
        if (cycle_cnt == 5'd0) begin
          // Count frequencies based on chars
          // We do this sequentially in this same cycle using blocking style in a combinational sense via temps
          // Implemented as: reset already done at start; now increment
          // To avoid mixed blocking/non-blocking issues across cycles, compute via case chain
          // We'll use non-blocking adds referencing current values; synthesizers handle this as parallel increments.
          freq[chars[0]] <= freq[chars[0]] + 5'd1;
          freq[chars[1]] <= freq[chars[1]] + 5'd1;
          freq[chars[2]] <= freq[chars[2]] + 5'd1;
          freq[chars[3]] <= freq[chars[3]] + 5'd1;
          freq[chars[4]] <= freq[chars[4]] + 5'd1;
          freq[chars[5]] <= freq[chars[5]] + 5'd1;
          freq[chars[6]] <= freq[chars[6]] + 5'd1;
          freq[chars[7]] <= freq[chars[7]] + 5'd1;
        end

        // Cycle 1: check frequency constraint and prepare sorted array
        if (cycle_cnt == 5'd1) begin
          // Check if any char appears > 4 times
          valid <= 1'b1; // tentatively true
          for (i = 0; i < 26; i = i + 1) begin
            if (freq[i] > 5'd4) begin
              valid <= 1'b0;
            end
          end

          if (valid == 1'b0) begin
            chars_out <= 40'd0;
          end else begin
            // Copy input chars into sorted as initial (we'll sort next cycle)
            sorted[0] <= chars[0];
            sorted[1] <= chars[1];
            sorted[2] <= chars[2];
            sorted[3] <= chars[3];
            sorted[4] <= chars[4];
            sorted[5] <= chars[5];
            sorted[6] <= chars[6];
            sorted[7] <= chars[7];
          end
        end

        // Cycle 2: sort 8 elements (simple combinational bubble via fixed network using temp regs)
        if (cycle_cnt == 5'd2 && valid) begin
          reg [4:0] s0,s1,s2,s3,s4,s5,s6,s7;
          reg [4:0] t;

          s0 = sorted[0]; s1 = sorted[1]; s2 = sorted[2]; s3 = sorted[3];
          s4 = sorted[4]; s5 = sorted[5]; s6 = sorted[6]; s7 = sorted[7];

          // Simple sorting network (odd-even style)
          if (s0 > s1) begin t=s0; s0=s1; s1=t; end
          if (s2 > s3) begin t=s2; s2=s3; s3=t; end
          if (s4 > s5) begin t=s4; s4=s5; s5=t; end
          if (s6 > s7) begin t=s6; s6=s7; s7=t; end

          if (s0 > s2) begin t=s0; s0=s2; s2=t; end
          if (s1 > s3) begin t=s1; s1=s3; s3=t; end
          if (s4 > s6) begin t=s4; s4=s6; s6=t; end
          if (s5 > s7) begin t=s5; s5=s7; s7=t; end

          if (s1 > s2) begin t=s1; s1=s2; s2=t; end
          if (s3 > s4) begin t=s3; s3=s4; s4=t; end
          if (s5 > s6) begin t=s5; s5=s6; s6=t; end

          if (s0 > s1) begin t=s0; s0=s1; s1=t; end
          if (s2 > s3) begin t=s2; s2=s3; s3=t; end
          if (s4 > s5) begin t=s4; s4=s5; s5=t; end
          if (s6 > s7) begin t=s6; s6=s7; s7=t; end

          sorted[0] <= s0; sorted[1] <= s1; sorted[2] <= s2; sorted[3] <= s3;
          sorted[4] <= s4; sorted[5] <= s5; sorted[6] <= s6; sorted[7] <= s7;
        end

        // Cycle 3: build rearr = [first_half, second_half_reversed]
        if (cycle_cnt == 5'd3 && valid) begin
          rearr[0] <= sorted[0];
          rearr[1] <= sorted[1];
          rearr[2] <= sorted[2];
          rearr[3] <= sorted[3];
          rearr[4] <= sorted[7];
          rearr[5] <= sorted[6];
          rearr[6] <= sorted[5];
          rearr[7] <= sorted[4];
        end

        // Cycle 4: check substring uniqueness and finalize chars_out/valid
        if (cycle_cnt == 5'd4 && valid) begin
          // Form 5 substrings of length 4
          // Compare all pairs for equality
          reg unique_ok;
          unique_ok = 1'b1;

          // Helper tasks replaced by explicit compares
          // s0 vs others
          if ({rearr[0],rearr[1],rearr[2],rearr[3]} == {rearr[1],rearr[2],rearr[3],rearr[4]}) unique_ok = 1'b0;
          if ({rearr[0],rearr[1],rearr[2],rearr[3]} == {rearr[2],rearr[3],rearr[4],rearr[5]}) unique_ok = 1'b0;
          if ({rearr[0],rearr[1],rearr[2],rearr[3]} == {rearr[3],rearr[4],rearr[5],rearr[6]}) unique_ok = 1'b0;
          if ({rearr[0],rearr[1],rearr[2],rearr[3]} == {rearr[4],rearr[5],rearr[6],rearr[7]}) unique_ok = 1'b0;

          // s1 vs others after it
          if ({rearr[1],rearr[2],rearr[3],rearr[4]} == {rearr[2],rearr[3],rearr[4],rearr[5]}) unique_ok = 1'b0;
          if ({rearr[1],rearr[2],rearr[3],rearr[4]} == {rearr[3],rearr[4],rearr[5],rearr[6]}) unique_ok = 1'b0;
          if ({rearr[1],rearr[2],rearr[3],rearr[4]} == {rearr[4],rearr[5],rearr[6],rearr[7]}) unique_ok = 1'b0;

          // s2 vs others
          if ({rearr[2],rearr[3],rearr[4],rearr[5]} == {rearr[3],rearr[4],rearr[5],rearr[6]}) unique_ok = 1'b0;
          if ({rearr[2],rearr[3],rearr[4],rearr[5]} == {rearr[4],rearr[5],rearr[6],rearr[7]}) unique_ok = 1'b0;

          // s3 vs s4
          if ({rearr[3],rearr[4],rearr[5],rearr[6]} == {rearr[4],rearr[5],rearr[6],rearr[7]}) unique_ok = 1'b0;

          if (!unique_ok) begin
            valid <= 1'b0;
            chars_out <= 40'd0;
          end else begin
            valid <= 1'b1;
            chars_out <= {rearr[0],rearr[1],rearr[2],rearr[3],rearr[4],rearr[5],rearr[6],rearr[7]};
          end
        end

        // Cycle 19: signal done pulse and release busy
        if (cycle_cnt == 5'd19) begin
          done <= 1'b1;
          busy <= 1'b0;
        end
      end
    end
  end

endmodule