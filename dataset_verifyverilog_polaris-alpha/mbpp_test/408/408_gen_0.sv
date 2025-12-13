module k_min_pairs (
  input              clk,
  input              rst_n,
  input      [2:0]   array1_size,
  input      [2:0]   array2_size,
  input      [3:0]   nums1 [0:7],
  input      [3:0]   nums2 [0:7],
  input      [5:0]   k,
  output reg [3:0]   pairs [0:15][0:1],
  output reg         valid
);

  // Parameters
  localparam MAX_PAIRS = 64;
  localparam MAX_OUT_PAIRS = 16;

  // Internal storage for pairs and sums
  reg [3:0] pair_a   [0:MAX_PAIRS-1];
  reg [3:0] pair_b   [0:MAX_PAIRS-1];
  reg [4:0] pair_sum [0:MAX_PAIRS-1];

  // Pipeline registers for sorted arrays per stage
  reg [3:0] stage_a   [0:9][0:MAX_PAIRS-1];
  reg [3:0] stage_b   [0:9][0:MAX_PAIRS-1];
  reg [4:0] stage_sum [0:9][0:MAX_PAIRS-1];

  // Tracking
  reg [6:0] actual_pairs;          // up to 64
  reg [6:0] actual_pairs_d [0:9];  // delayed through pipeline

  // Input change detection
  reg [2:0] array1_size_q, array2_size_q;
  reg [5:0] k_q;
  reg [3:0] nums1_q [0:7];
  reg [3:0] nums2_q [0:7];

  reg       input_changed;
  reg [3:0] change_shift; // 10-cycle latency tracker

  integer i, j, s;

  // Capture previous inputs and detect changes
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      array1_size_q <= 3'd0;
      array2_size_q <= 3'd0;
      k_q           <= 6'd0;
      for (i = 0; i < 8; i = i + 1) begin
        nums1_q[i] <= 4'd0;
        nums2_q[i] <= 4'd0;
      end
      input_changed <= 1'b0;
    end else begin
      input_changed <= (array1_size_q != array1_size) ||
                       (array2_size_q != array2_size) ||
                       (k_q           != k);
      for (i = 0; i < 8; i = i + 1) begin
        if (nums1_q[i] != nums1[i]) input_changed <= 1'b1;
        if (nums2_q[i] != nums2[i]) input_changed <= 1'b1;
      end

      array1_size_q <= array1_size;
      array2_size_q <= array2_size;
      k_q           <= k;
      for (i = 0; i < 8; i = i + 1) begin
        nums1_q[i] <= nums1[i];
        nums2_q[i] <= nums2[i];
      end
    end
  end

  // 10-cycle latency valid tracker
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      change_shift <= 4'd0;
      valid        <= 1'b0;
    end else begin
      // shift register for 10-cycle delay using 4-bit counter style is insufficient,
      // use explicit 10-bit shift but implemented as two steps: here we use pattern:
      // when input_changed, load MSB; shift toward LSB; valid is LSB.
      // Implement 10-bit via two regs: upper 6 bits implied as they are not needed explicitly
      // For strict correctness, use 10-bit shift.
    end
  end

  // Correct 10-bit shift register for valid
  reg [9:0] valid_shift;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_shift <= 10'b0;
      valid       <= 1'b0;
    end else begin
      valid_shift <= {valid_shift[8:0], input_changed};
      valid       <= valid_shift[9];
    end
  end

  // Generate all possible 64 pairs (combinational into pair_* regs on input_changed)
  // and compute actual_pairs = array1_size * array2_size
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      actual_pairs <= 7'd0;
      for (i = 0; i < MAX_PAIRS; i = i + 1) begin
        pair_a[i]   <= 4'd0;
        pair_b[i]   <= 4'd0;
        pair_sum[i] <= 5'd0;
      end
    end else if (input_changed) begin
      // compute actual_pairs
      actual_pairs <= array1_size * array2_size;

      // fill pairs in row-major order (i over nums1, j over nums2)
      integer idx;
      idx = 0;
      for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
          if ((i < array1_size) && (j < array2_size)) begin
            pair_a[idx]   <= nums1[i];
            pair_b[idx]   <= nums2[j];
            pair_sum[idx] <= nums1[i] + nums2[j];
            idx = idx + 1;
          end
        end
      end
      // zero out remaining entries
      for (; idx < MAX_PAIRS; idx = idx + 1) begin
        pair_a[idx]   <= 4'd0;
        pair_b[idx]   <= 4'd0;
        pair_sum[idx] <= 5'd31; // large so they sort to end
      end
    end
  end

  // Pipeline actual_pairs through 10 stages
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (s = 0; s < 10; s = s + 1) begin
        actual_pairs_d[s] <= 7'd0;
      end
    end else begin
      actual_pairs_d[0] <= actual_pairs;
      for (s = 1; s < 10; s = s + 1) begin
        actual_pairs_d[s] <= actual_pairs_d[s-1];
      end
    end
  end

  // Initialize stage 0 from pair_* on input_changed
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < MAX_PAIRS; i = i + 1) begin
        stage_a[0][i]   <= 4'd0;
        stage_b[0][i]   <= 4'd0;
        stage_sum[0][i] <= 5'd0;
      end
    end else if (input_changed) begin
      for (i = 0; i < MAX_PAIRS; i = i + 1) begin
        stage_a[0][i]   <= pair_a[i];
        stage_b[0][i]   <= pair_b[i];
        stage_sum[0][i] <= pair_sum[i];
      end
    end else begin
      // hold when no new input change; no update
    end
  end

  // 10-stage odd-even style bubble sort network (partial, 1 pass per stage)
  // Each stage performs parallel compare-swap on alternating indices.
  genvar gv_stage;
  generate
    for (gv_stage = 0; gv_stage < 9; gv_stage = gv_stage + 1) begin : GEN_SORT_STAGES
      integer idx2;
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
          for (idx2 = 0; idx2 < MAX_PAIRS; idx2 = idx2 + 1) begin
            stage_a[gv_stage+1][idx2]   <= 4'd0;
            stage_b[gv_stage+1][idx2]   <= 4'd0;
            stage_sum[gv_stage+1][idx2] <= 5'd0;
          end
        end else begin
          // copy previous stage as default
          for (idx2 = 0; idx2 < MAX_PAIRS; idx2 = idx2 + 1) begin
            stage_a[gv_stage+1][idx2]   <= stage_a[gv_stage][idx2];
            stage_b[gv_stage+1][idx2]   <= stage_b[gv_stage][idx2];
            stage_sum[gv_stage+1][idx2] <= stage_sum[gv_stage][idx2];
          end

          // odd-even passes alternate between even and odd starting indices
          integer start_idx;
          start_idx = (gv_stage[0] == 1'b0) ? 0 : 1; // even stage: start at 0, odd: 1

          integer k_idx;
          reg [4:0] s0, s1;
          reg [3:0] a0, a1, b0, b1;

          for (k_idx = start_idx; k_idx < MAX_PAIRS-1; k_idx = k_idx + 2) begin
            s0 = stage_sum[gv_stage][k_idx];
            s1 = stage_sum[gv_stage][k_idx+1];
            a0 = stage_a[gv_stage][k_idx];
            a1 = stage_a[gv_stage][k_idx+1];
            b0 = stage_b[gv_stage][k_idx];
            b1 = stage_b[gv_stage][k_idx+1];
            if (s1 < s0) begin
              stage_sum[gv_stage+1][k_idx]   <= s1;
              stage_sum[gv_stage+1][k_idx+1] <= s0;
              stage_a[gv_stage+1][k_idx]     <= a1;
              stage_a[gv_stage+1][k_idx+1]   <= a0;
              stage_b[gv_stage+1][k_idx]     <= b1;
              stage_b[gv_stage+1][k_idx+1]   <= b0;
            end
          end
        end
      end
    end
  endgenerate

  // Output selection after stage 9 (10th stage indexed 9)
  reg [6:0] out_count;
  always @(*) begin
    // min(k, actual_pairs_d[9], MAX_OUT_PAIRS)
    if (actual_pairs_d[9] < MAX_OUT_PAIRS)
      out_count = actual_pairs_d[9];
    else
      out_count = MAX_OUT_PAIRS;

    if (k < out_count)
      out_count = k;
  end

  integer o;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (o = 0; o < MAX_OUT_PAIRS; o = o + 1) begin
        pairs[o][0] <= 4'd0;
        pairs[o][1] <= 4'd0;
      end
    end else begin
      // Write selected pairs
      for (o = 0; o < MAX_OUT_PAIRS; o = o + 1) begin
        if (o < out_count) begin
          pairs[o][0] <= stage_a[9][o];
          pairs[o][1] <= stage_b[9][o];
        end else begin
          pairs[o][0] <= 4'd0;
          pairs[o][1] <= 4'd0;
        end
      end
    end
  end

endmodule