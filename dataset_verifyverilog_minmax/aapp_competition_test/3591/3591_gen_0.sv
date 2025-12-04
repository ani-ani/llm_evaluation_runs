module photo_filter(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] heights [0:15],
  output reg valid,
  output reg processing
);
  // Internal signals
  reg [3:0] processing_cnt;        // 4-bit counter (0..15)
  reg prev_start;
  wire start_edge;

  // Capture heights on first cycle after start
  reg [15:0] h_r [0:15];
  reg [3:0] n_r;

  // Left-to-right running max
  reg [15:0] max_left;             // max height from 0..i-1
  reg [15:0] max_left_d1;          // delayed by 1 cycle (for i=0 -> 0)

  // Right-side precomputed max (reverse pass) in a register array
  reg [15:0] max_right [0:15];     // max_right[i] = max(height[i+1..n-1])

  // Helper to form 16-bit word per position from packed array
  function [15:0] get_h(input [3:0] i);
    get_h = heights[i];
  endfunction

  // Build per-position h_vec for indexed access
  genvar gi;
  generate
    for (gi = 0; gi < 16; gi = gi + 1) begin : build_h_vec
      wire [15:0] h_vec = get_h(gi);
    end
  endgenerate

  // Build array of wires referencing the generated nets
  wire [15:0] h_vec [0:15];
  genvar gj;
  generate
    for (gj = 0; gj < 16; gj = gj + 1) begin : connect_h_vec
      assign h_vec[gj] = build_h_vec[gj].h_vec;
    end
  endgenerate

  // Edge detect for start pulse
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) prev_start <= 1'b0;
    else        prev_start <= start;
  end
  assign start_edge = start && !prev_start;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid        <= 1'b0;
      processing   <= 1'b0;
      processing_cnt <= 4'd0;
      n_r          <= 4'd0;
      max_left     <= 16'd0;
      max_left_d1  <= 16'd0;
      // Initialize captured heights (don't care reset)
      h_r[0]  <= 16'd0; h_r[1]  <= 16'd0; h_r[2]  <= 16'd0; h_r[3]  <= 16'd0;
      h_r[4]  <= 16'd0; h_r[5]  <= 16'd0; h_r[6]  <= 16'd0; h_r[7]  <= 16'd0;
      h_r[8]  <= 16'd0; h_r[9]  <= 16'd0; h_r[10] <= 16'd0; h_r[11] <= 16'd0;
      h_r[12] <= 16'd0; h_r[13] <= 16'd0; h_r[14] <= 16'd0; h_r[15] <= 16'd0;
      // Initialize max_right (don't care)
      max_right[0]  <= 16'd0; max_right[1]  <= 16'd0; max_right[2]  <= 16'd0; max_right[3]  <= 16'd0;
      max_right[4]  <= 16'd0; max_right[5]  <= 16'd0; max_right[6]  <= 16'd0; max_right[7]  <= 16'd0;
      max_right[8]  <= 16'd0; max_right[9]  <= 16'd0; max_right[10] <= 16'd0; max_right[11] <= 16'd0;
      max_right[12] <= 16'd0; max_right[13] <= 16'd0; max_right[14] <= 16'd0; max_right[15] <= 16'd0;
    end else begin
      // Start pulse behavior: load inputs and initialize state
      if (start_edge) begin
        processing   <= 1'b1;
        processing_cnt <= 4'd0;
        // capture inputs
        n_r <= n;
        h_r[0]  <= h_vec[0];  h_r[1]  <= h_vec[1];  h_r[2]  <= h_vec[2];  h_r[3]  <= h_vec[3];
        h_r[4]  <= h_vec[4];  h_r[5]  <= h_vec[5];  h_r[6]  <= h_vec[6];  h_r[7]  <= h_vec[7];
        h_r[8]  <= h_vec[8];  h_r[9]  <= h_vec[9];  h_r[10] <= h_vec[10]; h_r[11] <= h_vec[11];
        h_r[12] <= h_vec[12]; h_r[13] <= h_vec[13]; h_r[14] <= h_vec[14]; h_r[15] <= h_vec[15];
        // Initialize trackers
        max_left     <= 16'd0;   // for i=0: max_left = 0
        max_left_d1  <= 16'd0;
        // Start reverse precompute from the right end; first computed value (for i=n-1) will be 0
        max_right[15] <= 16'd0;
        // valid will be updated on cycle 16 (processing_cnt == 4'd15)
        valid        <= 1'b0;
      end else if (processing) begin
        // Increment processing counter (fixed 16-cycle run)
        processing_cnt <= processing_cnt + 4'd1;

        // Update max_left (running max from left, excluding current i)
        if (processing_cnt == 4'd0) begin
          // i = 0, no elements to the left; latch 0 for this cycle
          max_left     <= 16'd0;
          max_left_d1  <= 16'd0;
        end else begin
          // i >= 1: max_left becomes max(max_left, h_r[i-1])
          max_left     <= (max_left >= h_r[processing_cnt - 4'd1]) ? max_left : h_r[processing_cnt - 4'd1];
          max_left_d1  <= max_left; // capture previous max_left for current i's check
        end

        // Reverse precompute max_right for next position (i = n-1 - processing_cnt)
        if (processing_cnt < 4'd15) begin
          // Next index to compute: idx = 15 - processing_cnt
          // Update with max of h_r[idx+1] and previous right max
          max_right[15 - processing_cnt] <= (h_r[15 - processing_cnt + 4'd1] >= max_right[15 - processing_cnt + 4'd1]) ?
                                             h_r[15 - processing_cnt + 4'd1] :
                                             max_right[15 - processing_cnt + 4'd1];
        end

        // On the 16th cycle (processing_cnt == 15), evaluate the result
        if (processing_cnt == 4'd15) begin
          // current i (0..15) under test
          if (processing_cnt < n_r) begin
            // Conditions:
            // 1) exists j < i with height[j] > height[i] -> max_left_d1 > h_r[i]
            // 2) exists k > i with height[k] > height[j] and height[k] > height[i]
            //    -> max_right[i] > max_left_d1 AND max_right[i] > h_r[i]
            // Since max_left_d1 already implies some j with height[j] = max_left_d1,
            // checking max_right[i] > max_left_d1 suffices for condition 2.
            if ((max_left_d1 > h_r[processing_cnt]) &&
                (max_right[processing_cnt] > max_left_d1)) begin
              valid <= 1'b1;
            end else begin
              valid <= 1'b0;
            end
          end else begin
            valid <= 1'b0; // i >= n -> not a valid position
          end
          processing <= 1'b0; // done
        end
      end
    end
  end
endmodule