module substring_finder (
  input clk,
  input rst_n,
  input start,
  input [127:0] text_data,
  input [63:0] pattern_data,
  output logic [63:0] substring,
  output logic [3:0] start_pos,
  output logic [3:0] end_pos,
  output logic match_found,
  output logic done
);

  // Internal signals
  logic [7:0] shift_reg [7:0];  // 8-byte sliding window over the 16-byte text
  logic [3:0] shift_count;      // 0..15, counts shifts performed since 'start'
  logic match_vec [8:0];        // parallel per-position equality (positions 0..8 of window)
  logic pattern_valid;          // 1 when enough bytes are shifted in to form a full pattern
  logic match_valid;            // 1 when a full pattern at some position matches
  logic match_latched;          // latched when first match is found
  logic [3:0] next_match_latched;
  logic [3:0] start_pos_int;
  logic [3:0] end_pos_int;
  logic match_found_int;
  logic done_int;
  logic [7:0] i;

  // Latch first match position and raise done
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      match_latched <= 1'b0;
      done_int      <= 1'b0;
    end else begin
      if (start) begin
        match_latched <= 1'b0;
        done_int      <= 1'b0;
      end else if (match_valid && !done_int) begin
        match_latched <= 1'b1;
        done_int      <= 1'b1;
      end
    end
  end

  // Track shift count (0..15) after 'start'
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) shift_count <= 4'd0;
    else if (start) shift_count <= 4'd0;
    else if (!done_int) shift_count <= shift_count + 1;
  end

  // Sliding window: on 'start' load text bytes into [15:8]; then shift left by 1 byte each cycle
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      shift_reg[0] <= 8'h00;
      shift_reg[1] <= 8'h00;
      shift_reg[2] <= 8'h00;
      shift_reg[3] <= 8'h00;
      shift_reg[4] <= 8'h00;
      shift_reg[5] <= 8'h00;
      shift_reg[6] <= 8'h00;
      shift_reg[7] <= 8'h00;
    end else begin
      if (start) begin
        shift_reg[0] <= text_data[127:120];
        shift_reg[1] <= text_data[119:112];
        shift_reg[2] <= text_data[111:104];
        shift_reg[3] <= text_data[103: 96];
        shift_reg[4] <= text_data[ 95: 88];
        shift_reg[5] <= text_data[ 87: 80];
        shift_reg[6] <= text_data[ 79: 72];
        shift_reg[7] <= text_data[ 71: 64];
      end else if (!done_int) begin
        shift_reg[0] <= shift_reg[1];
        shift_reg[1] <= shift_reg[2];
        shift_reg[2] <= shift_reg[3];
        shift_reg[3] <= shift_reg[4];
        shift_reg[4] <= shift_reg[5];
        shift_reg[5] <= shift_reg[6];
        shift_reg[6] <= shift_reg[7];
        shift_reg[7] <= 8'h00; // fill with null as we slide beyond the 16-char text
      end
    end
  end

  // Determine if a full 8-char pattern is present in the window
  assign pattern_valid = (shift_count >= 4'd7);

  // Parallel comparison of all 9 possible start positions (0..8) within the 16-char text
  genvar p;
  generate
    for (p = 0; p < 8; p = p + 1) begin : cmp
      assign match_vec[p] = pattern_valid && (shift_reg[p + 0] == pattern_data[63:56]) &&
                                        (shift_reg[p + 1] == pattern_data[55:48]) &&
                                        (shift_reg[p + 2] == pattern_data[47:40]) &&
                                        (shift_reg[p + 3] == pattern_data[39:32]) &&
                                        (shift_reg[p + 4] == pattern_data[31:24]) &&
                                        (shift_reg[p + 5] == pattern_data[23:16]) &&
                                        (shift_reg[p + 6] == pattern_data[15: 8]) &&
                                        (shift_reg[p + 7] == pattern_data[ 7: 0]);
    end
    // position 8 is only valid when exactly 8 bytes remain to compare within the 16-char string
    assign match_vec[8] = (shift_count == 4'd8) && (shift_reg[8] == 8'dx) ? 1'b0 : 1'b0; // not reachable, reserved for completeness
  endgenerate

  assign match_valid = (match_vec[0] || match_vec[1] || match_vec[2] || match_vec[3] ||
                        match_vec[4] || match_vec[5] || match_vec[6] || match_vec[7]);

  // Compute first match position (lowest index) when a match becomes valid
  always_comb begin
    next_match_latched = 4'd0;
    if (match_vec[0]) next_match_latched = 4'd0;
    else if (match_vec[1]) next_match_latched = 4'd1;
    else if (match_vec[2]) next_match_latched = 4'd2;
    else if (match_vec[3]) next_match_latched = 4'd3;
    else if (match_vec[4]) next_match_latched = 4'd4;
    else if (match_vec[5]) next_match_latched = 4'd5;
    else if (match_vec[6]) next_match_latched = 4'd6;
    else if (match_vec[7]) next_match_latched = 4'd7;
    // position 8 is intentionally not used to keep max substring 8 chars
  end

  // Latch the first occurrence position
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_pos_int <= 4'd0;
    else if (start) start_pos_int <= 4'd0;
    else if (match_valid && !done_int) start_pos_int <= next_match_latched;
  end

  // Outputs
  assign start_pos = start_pos_int;
  assign end_pos   = (start_pos_int + 4'd7); // inclusive end index of the 8-char substring
  assign match_found = match_found_int && done_int;
  assign done = done_int;

  // Result substring assembled from the captured 8-byte window at the time of match
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      substring      <= 64'h0000000000000000;
      match_found_int <= 1'b0;
    end else begin
      if (start) begin
        substring      <= 64'h0000000000000000;
        match_found_int <= 1'b0;
      end else if (match_valid && !done_int) begin
        substring      <= {shift_reg[start_pos_int + 0],
                          shift_reg[start_pos_int + 1],
                          shift_reg[start_pos_int + 2],
                          shift_reg[start_pos_int + 3],
                          shift_reg[start_pos_int + 4],
                          shift_reg[start_pos_int + 5],
                          shift_reg[start_pos_int + 6],
                          shift_reg[start_pos_int + 7]};
        match_found_int <= 1'b1;
      end
    end
  end

endmodule
