module minimal_column_deletion(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [2:0]  n,
  input  logic [23:0] row1,
  input  logic [23:0] row2,
  input  logic [23:0] row3,
  output logic [3:0]  result,
  output logic        done
);

  // FSM state encoding
  typedef enum logic [2:0] {
    IDLE          = 3'd0,
    INIT          = 3'd1,
    PROCESS_MASK  = 3'd2,
    UPDATE_STATE  = 3'd3,
    DONE_STATE    = 3'd4
  } state_t;

  state_t state, next_state;

  // Internal registers
  logic [7:0]  mask_counter;
  logic [7:0]  last_mask;        // (1<<n)-1
  logic [3:0]  max_kept;

  // Stored rows (latched at start)
  logic [23:0] row1_reg, row2_reg, row3_reg;
  logic [2:0]  n_reg;

  // For current mask processing
  logic [7:0]  cur_mask;
  logic [3:0]  cols_kept;

  // Temp arrays before and after sort (8 elements of 4-bit each)
  logic [3:0] r1_in [7:0];
  logic [3:0] r2_in [7:0];
  logic [3:0] r3_in [7:0];

  logic [3:0] r1_sorted [7:0];
  logic [3:0] r2_sorted [7:0];
  logic [3:0] r3_sorted [7:0];

  // Match flag for current mask
  logic        valid_mask;

  // Comparator helper (compare and swap) for 4-bit values
  function automatic void cswap(
    input  logic [3:0] a_in,
    input  logic [3:0] b_in,
    output logic [3:0] a_out,
    output logic [3:0] b_out
  );
  begin
    if (a_in > b_in) begin
      a_out = b_in;
      b_out = a_in;
    end else begin
      a_out = a_in;
      b_out = b_in;
    end
  end
  endfunction

  // 8-element ascending sorting network (purely combinational)
  function automatic void sort8(
    input  logic [3:0] in0,
    input  logic [3:0] in1,
    input  logic [3:0] in2,
    input  logic [3:0] in3,
    input  logic [3:0] in4,
    input  logic [3:0] in5,
    input  logic [3:0] in6,
    input  logic [3:0] in7,
    output logic [3:0] out0,
    output logic [3:0] out1,
    output logic [3:0] out2,
    output logic [3:0] out3,
    output logic [3:0] out4,
    output logic [3:0] out5,
    output logic [3:0] out6,
    output logic [3:0] out7
  );
    // Batcher odd-even mergesort network for 8 elements
    // Stage 0
    logic [3:0] s0[7:0];
    // Stage 1
    logic [3:0] s1[7:0];
    // Stage 2
    logic [3:0] s2[7:0];
    // Stage 3
    logic [3:0] s3[7:0];
    // Stage 4
    logic [3:0] s4[7:0];
    // Stage 5
    logic [3:0] s5[7:0];

  begin
    // Load inputs
    s0[0] = in0; s0[1] = in1; s0[2] = in2; s0[3] = in3;
    s0[4] = in4; s0[5] = in5; s0[6] = in6; s0[7] = in7;

    // Stage 1: (0,1)(2,3)(4,5)(6,7)
    cswap(s0[0], s0[1], s1[0], s1[1]);
    cswap(s0[2], s0[3], s1[2], s1[3]);
    cswap(s0[4], s0[5], s1[4], s1[5]);
    cswap(s0[6], s0[7], s1[6], s1[7]);

    // Stage 2: (0,2)(1,3)(4,6)(5,7)
    cswap(s1[0], s1[2], s2[0], s2[2]);
    cswap(s1[1], s1[3], s2[1], s2[3]);
    cswap(s1[4], s1[6], s2[4], s2[6]);
    cswap(s1[5], s1[7], s2[5], s2[7]);

    // Stage 3: (1,2)(5,6)
    s3[0] = s2[0];
    s3[3] = s2[3];
    s3[4] = s2[4];
    s3[7] = s2[7];
    cswap(s2[1], s2[2], s3[1], s3[2]);
    cswap(s2[5], s2[6], s3[5], s3[6]);

    // Stage 4: (0,4)(1,5)(2,6)(3,7)
    cswap(s3[0], s3[4], s4[0], s4[4]);
    cswap(s3[1], s3[5], s4[1], s4[5]);
    cswap(s3[2], s3[6], s4[2], s4[6]);
    cswap(s3[3], s3[7], s4[3], s4[7]);

    // Stage 5: (2,4)(3,5)
    s5[0] = s4[0];
    s5[1] = s4[1];
    s5[6] = s4[6];
    s5[7] = s4[7];
    cswap(s4[2], s4[4], s5[2], s5[4]);
    cswap(s4[3], s4[5], s5[3], s5[5]);

    // Stage 6: (1,2)(3,4)(5,6)
    cswap(s5[1], s5[2], out1, out2);
    cswap(s5[3], s5[4], out3, out4);
    cswap(s5[5], s5[6], out5, out6);
    out0 = s5[0];
    out7 = s5[7];
  end
  endfunction

  // FSM sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      mask_counter <= 8'd0;
      max_kept     <= 4'd0;
      result       <= 4'd0;
      done         <= 1'b0;
      row1_reg     <= 24'd0;
      row2_reg     <= 24'd0;
      row3_reg     <= 24'd0;
      n_reg        <= 3'd0;
      last_mask    <= 8'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Capture inputs at start
            row1_reg  <= row1;
            row2_reg  <= row2;
            row3_reg  <= row3;
            n_reg     <= n;
            mask_counter <= 8'd0;
            max_kept  <= 4'd0;
            // last_mask = (1<<n) - 1
            last_mask <= (8'd1 << n) - 8'd1;
          end
        end

        INIT: begin
          // Nothing extra; counters already initialized in IDLE on start
        end

        PROCESS_MASK: begin
          // No sequential updates here; all combinational
        end

        UPDATE_STATE: begin
          // Update max_kept if current mask valid and better
          if (valid_mask && (cols_kept > max_kept)) begin
            max_kept <= cols_kept;
          end

          // Increment mask_counter if not finished
          if (mask_counter != last_mask) begin
            mask_counter <= mask_counter + 8'd1;
          end
        end

        DONE_STATE: begin
          // Latch final result and assert done until next start
          result <= n_reg - max_kept;
          done   <= 1'b1;
          if (start) begin
            // Prepare for new run
            done         <= 1'b0;
            row1_reg     <= row1;
            row2_reg     <= row2;
            row3_reg     <= row3;
            n_reg        <= n;
            mask_counter <= 8'd0;
            max_kept     <= 4'd0;
            last_mask    <= (8'd1 << n) - 8'd1;
          end
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = INIT;
        end
      end

      INIT: begin
        next_state = PROCESS_MASK;
      end

      PROCESS_MASK: begin
        next_state = UPDATE_STATE;
      end

      UPDATE_STATE: begin
        if (mask_counter == last_mask) begin
          next_state = DONE_STATE;
        end else begin
          next_state = PROCESS_MASK;
        end
      end

      DONE_STATE: begin
        if (start) begin
          next_state = INIT;
        end else begin
          next_state = DONE_STATE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Combinational logic for current mask processing
  always_comb begin
    // Current mask from counter (only lower n_reg bits are relevant)
    cur_mask = mask_counter;

    // Count bits set in cur_mask up to n_reg-1
    cols_kept = 4'd0;
    for (int i = 0; i < 8; i++) begin
      if ((i < n_reg) && cur_mask[i]) begin
        cols_kept = cols_kept + 4'd1;
      end
    end

    // Build padded arrays: selected column -> its 3-bit value; unselected -> 9 (4'b1001)
    for (int i = 0; i < 8; i++) begin
      logic [2:0] v1, v2, v3;
      v1 = row1_reg[3*i +: 3];
      v2 = row2_reg[3*i +: 3];
      v3 = row3_reg[3*i +: 3];
      if ((i < n_reg) && cur_mask[i]) begin
        r1_in[i] = {1'b0, v1};
        r2_in[i] = {1'b0, v2};
        r3_in[i] = {1'b0, v3};
      end else begin
        r1_in[i] = 4'd9;
        r2_in[i] = 4'd9;
        r3_in[i] = 4'd9;
      end
    end

    // Sort each row using sorting network
    sort8(
      r1_in[0], r1_in[1], r1_in[2], r1_in[3],
      r1_in[4], r1_in[5], r1_in[6], r1_in[7],
      r1_sorted[0], r1_sorted[1], r1_sorted[2], r1_sorted[3],
      r1_sorted[4], r1_sorted[5], r1_sorted[6], r1_sorted[7]
    );

    sort8(
      r2_in[0], r2_in[1], r2_in[2], r2_in[3],
      r2_in[4], r2_in[5], r2_in[6], r2_in[7],
      r2_sorted[0], r2_sorted[1], r2_sorted[2], r2_sorted[3],
      r2_sorted[4], r2_sorted[5], r2_sorted[6], r2_sorted[7]
    );

    sort8(
      r3_in[0], r3_in[1], r3_in[2], r3_in[3],
      r3_in[4], r3_in[5], r3_in[6], r3_in[7],
      r3_sorted[0], r3_sorted[1], r3_sorted[2], r3_sorted[3],
      r3_sorted[4], r3_sorted[5], r3_sorted[6], r3_sorted[7]
    );

    // Validate current mask if it improves over max_kept
    valid_mask = 1'b0;

    if ((cols_kept > max_kept) && (cols_kept != 4'd0)) begin
      valid_mask = 1'b1;
      // Compare first cols_kept elements across three sorted rows
      for (int k = 0; k < 8; k++) begin
        if (k < cols_kept) begin
          if (!((r1_sorted[k] == r2_sorted[k]) && (r2_sorted[k] == r3_sorted[k]))) begin
            valid_mask = 1'b0;
          end
        end
      end
    end
  end

endmodule