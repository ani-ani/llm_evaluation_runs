module substring_finder(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [127:0] text_data,
  input  logic [63:0]  pattern_data,
  output logic [63:0]  substring,
  output logic [3:0]   start_pos,
  output logic [3:0]   end_pos,
  output logic         match_found,
  output logic         done
);

  // Internal registers
  logic [127:0] text_reg;          // Shift register for text
  logic [63:0]  pattern_reg;       // Latched pattern
  logic [4:0]   cycle_cnt;         // Up to 16 cycles
  logic         searching;         // Search in progress

  // Combinational match wires
  logic [15:0] match_vec;          // Potential match at each start index

  // Generate parallel comparisons for all valid start positions (0..8)
  // pattern_reg[63:56] is char0, [55:48] is char1, ..., [7:0] is char7
  // text_reg is organized similarly: [127:120] char0 ... [7:0] char15
  genvar i;
  generate
    for (i = 0; i <= 8; i = i + 1) begin : GEN_MATCH
      assign match_vec[i] = (text_reg[127 - 8*i      -: 8]  == pattern_reg[63:56]) &&
                            (text_reg[127 - 8*(i+1)  -: 8]  == pattern_reg[55:48]) &&
                            (text_reg[127 - 8*(i+2)  -: 8]  == pattern_reg[47:40]) &&
                            (text_reg[127 - 8*(i+3)  -: 8]  == pattern_reg[39:32]) &&
                            (text_reg[127 - 8*(i+4)  -: 8]  == pattern_reg[31:24]) &&
                            (text_reg[127 - 8*(i+5)  -: 8]  == pattern_reg[23:16]) &&
                            (text_reg[127 - 8*(i+6)  -: 8]  == pattern_reg[15:8])  &&
                            (text_reg[127 - 8*(i+7)  -: 8]  == pattern_reg[7:0]);
    end
    for (i = 9; i < 16; i = i + 1) begin : GEN_INVALID
      assign match_vec[i] = 1'b0; // invalid start positions for 8-char pattern
    end
  endgenerate

  // Priority encoder for first match (lowest index)
  function automatic [3:0] first_match_pos(input logic [15:0] mv);
    integer k;
    begin
      first_match_pos = 4'd0;
      for (k = 0; k < 16; k = k + 1) begin
        if (mv[k]) begin
          first_match_pos = k[3:0];
          disable for;
        end
      end
    end
  endfunction

  function automatic logic any_match(input logic [15:0] mv);
    begin
      any_match = |mv;
    end
  endfunction

  // Main sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      text_reg    <= 128'd0;
      pattern_reg <= 64'd0;
      cycle_cnt   <= 5'd0;
      searching   <= 1'b0;
      match_found <= 1'b0;
      done        <= 1'b0;
      start_pos   <= 4'd0;
      end_pos     <= 4'd0;
      substring   <= 64'd0;
    end else begin
      // Default: keep done low unless we just finish
      done <= 1'b0;

      // Start condition (edge or level-sensitive while idle)
      if (start && !searching) begin
        text_reg    <= text_data;
        pattern_reg <= pattern_data;
        cycle_cnt   <= 5'd0;
        searching   <= 1'b1;
        match_found <= 1'b0;
        start_pos   <= 4'd0;
        end_pos     <= 4'd0;
        substring   <= 64'd0;
      end else if (searching) begin
        // Perform parallel comparison in current alignment
        if (any_match(match_vec)) begin
          // Capture first match
          start_pos   <= first_match_pos(match_vec);
          end_pos     <= first_match_pos(match_vec) + 4'd7;
          substring   <= pattern_reg; // matched substring (8 chars)
          match_found <= 1'b1;
          done        <= 1'b1;
          searching   <= 1'b0;
        end else begin
          // No match this cycle, advance search
          cycle_cnt <= cycle_cnt + 5'd1;

          if (cycle_cnt == 5'd15) begin
            // Reached maximum latency without match
            match_found <= 1'b0;
            done        <= 1'b1;
            searching   <= 1'b0;
          end else begin
            // Shift text register by 8 bits (one character) to create new window
            text_reg <= {text_reg[119:0], 8'd0};
          end
        end
      end
    end
  end

endmodule
