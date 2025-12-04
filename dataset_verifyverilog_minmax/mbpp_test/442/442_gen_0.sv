module positive_ratio (
  input               clk,
  input               rst_n,
  input               start,
  input        [3:0]  array_size,
  input        [15:0] nums [0:15],
  output logic [15:0] ratio,
  output logic        done
);

  // Internal signals
  logic [5:0] pos_count;   // up to 16 positives
  logic [31:0] A;          // numerator = pos_count * 256
  logic [31:0] B;          // denominator = array_size
  logic [5:0]  bits_to_do; // remaining bits to process
  logic [16:0] R;          // remainder, signed, enough for 16-bit dividend + bias
  logic [16:0] Q;          // quotient accumulator
  logic        processing; // divide in progress
  logic [5:0]  cyc;        // cycle counter for 20-cycle latency
  logic        start_d;    // edge detect for start
  logic        A_is_zero_or_neg;
  logic [3:0]  array_size_r;
  logic        div_by_zero;
  logic        div_done;
  logic [15:0] ratio_raw;
  logic [15:0] ratio_rounded;

  // Edge detect for start
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_d <= 1'b0;
    else        start_d <= start;
  end
  wire start_pulse = start && !start_d;

  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      processing <= 1'b0;
      cyc        <= 6'd0;
    end else begin
      if (start_pulse) begin
        processing <= 1'b1;
        cyc        <= 6'd1; // cycle 1 of 20
      end else if (processing) begin
        if (cyc == 6'd20) begin
          processing <= 1'b0;
          cyc        <= 6'd0;
        end else begin
          cyc <= cyc + 1;
        end
      end else begin
        cyc <= 6'd0;
      end
    end
  end

  // Count positive numbers in nums[0:array_size-1]
  // Positive means > 0 (ignore zeros)
  integer k;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pos_count <= 6'd0;
    end else if (start_pulse) begin
      pos_count <= 6'd0;
      for (k = 0; k < 16; k = k + 1) begin
        if (k < array_size) begin
          if (nums[k] > 0) pos_count <= pos_count + 1'b1;
        end
      end
    end
  end

  // Latch array_size and detect division-by-zero
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      array_size_r <= 4'd0;
    end else if (start_pulse) begin
      array_size_r <= array_size;
    end
  end
  assign div_by_zero = (array_size_r == 4'd0);

  // Prepare numerator/denominator and decide if division is needed
  // We use numerator = pos_count * 256 (no bias here; we use unbiased non-restoring with later rounding)
  // To avoid dealing with negative numerators in division, we only proceed if A >= 0.
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      A <= 32'd0;
      B <= 32'd0;
      A_is_zero_or_neg <= 1'b1; // treat as not-processable by default
    end else if (start_pulse) begin
      A <= {32'd0} + {26'd0, pos_count, 8'd0}; // pos_count * 256
      B <= {32'd0} + {28'd0, array_size};      // array_size
      A_is_zero_or_neg <= ((pos_count == 6'd0) || div_by_zero);
    end
  end

  // Initialize non-restoring division on cycle 2 if needed
  logic [15:0] next_Q;
  logic [16:0] next_R;
  logic [15:0] A_ext;
  logic [31:0] B_ext;

  // Extend inputs for division
  assign A_ext = A[15:0];         // 16-bit dividend
  assign B_ext = B[31:0];         // up to 4-bit denominator extended
  // R must be 1 bit wider than the dividend to keep full range during non-restoring
  // next_R and Q logic (non-restoring) for 16 fractional bits (i.e., process 16 bits)
  wire [16:0] R_abs;
  wire [16:0] B_abs;
  assign R_abs = R[16] ? ~R + 1'b1 : R;
  assign B_abs = B_ext[16] ? ~B_ext[16:0] + 1'b1 : B_ext[16:0];

  // Compute next Q and R
  always_comb begin
    if (R[16] == 1'b0) begin
      // R >= 0 => R = 2*R - B
      next_R = {R[15:0], next_Q[15]} - {1'b0, B_ext[16:0]};
      next_Q = {Q[15:0], 1'b0} | 16'h0001; // quotient bit = 1
    end else begin
      // R < 0 => R = 2*R + B
      next_R = {R[15:0], next_Q[15]} + {1'b0, B_ext[16:0]};
      next_Q = {Q[15:0], 1'b0} | 16'h0000; // quotient bit = 0
    end
  end

  // Division pipeline: initialize on cycle 2, process one bit per cycle, done by cycle 17
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      R        <= 17'sd0;
      Q        <= 17'sd0;
      bits_to_do <= 6'd0;
      div_done   <= 1'b0;
    end else if (start_pulse) begin
      // Will be re-initialized below on cycle 2
      R        <= 17'sd0;
      Q        <= 17'sd0;
      bits_to_do <= 6'd0;
      div_done   <= 1'b0;
    end else if (processing) begin
      if (cyc == 6'd2) begin
        if (A_is_zero_or_neg) begin
          // Skip division: quotient = 0, remainder = 0, done next cycle
          R        <= 17'sd0;
          Q        <= 17'sd0;
          bits_to_do <= 6'd0;
          div_done   <= 1'b1; // indicate immediate result is ready
        end else begin
          // Initialize R = A, Q = 0, start processing 16 bits
          R        <= {1'b0, A_ext[15:0]}; // sign-extend 0 since A >= 0
          Q        <= 17'sd0;
          bits_to_do <= 6'd16;
          div_done   <= 1'b0;
        end
      end else if (bits_to_do != 6'd0) begin
        R <= next_R;
        Q <= {1'b0, next_Q[15:1]}; // shift left: put next quotient LSB at MSB of packed {Q,R}
        bits_to_do <= bits_to_do - 1'b1;
        if (bits_to_do == 6'd1) div_done <= 1'b1;
      end else begin
        // No-op after bits done
        div_done <= div_done; // keep last state
      end
    end else begin
      // Idle: keep defaults
      R        <= 17'sd0;
      Q        <= 17'sd0;
      bits_to_do <= 6'd0;
      div_done   <= 1'b0;
    end
  end

  // Unbiased final quotient: Q now holds unbiased 16 fractional bits (since we used unbiased non-restoring)
  assign ratio_raw = Q[15:0];

  // Rounding to nearest (ties to up): ratio = (ratio_raw + 0.5)
  // ratio_raw is Q8.8; add 1/256 => 0x01 in fractional field
  assign ratio_rounded = ratio_raw + 16'd1;

  // Output ratio and done with 20-cycle latency
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ratio <= 16'd0;
      done  <= 1'b0;
    end else if (processing) begin
      done <= (cyc == 6'd20);
      if (cyc == 6'd20) begin
        if (A_is_zero_or_neg) begin
          ratio <= 16'd0; // zero numerator or invalid denominator
        end else begin
          // Use rounded result
          ratio <= ratio_rounded;
        end
      end
    end else begin
      // Idle: outputs zero
      ratio <= 16'd0;
      done  <= 1'b0;
    end
  end

endmodule
