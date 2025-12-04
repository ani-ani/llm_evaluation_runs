module weight_identifier(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [31:0] weights,
  output reg [3:0] result,
  output reg done
);

  // Fixed-latency (100 cycles) state machine that finds the maximum count c (0..8)
  // such that there exists a positive integer m where the c selected weights are
  // multiples of m and their subset sums are all distinct (i.e., unique).
  // n in [1,8], weights are 8x4-bit packed as [31:28]=a7 ... [3:0]=a0.

  // Precomputed binom table for n<=8 (packed lower-triangular for quick access)
  // Index = (r*(r-1))/2 + c, for 0<=c<r<=8. binom[0]=C(1,0), binom[1]=C(2,0), binom[2]=C(2,1), ...
  logic [0:35] binom; // 36 entries for r=1..8

  // Sample the weights at the start of a run (qualify by start)
  logic [3:0] saved_n;
  logic [31:0] saved_weights;
  logic start_r1, start_r2;
  logic start_pulse; // single-cycle pulse on start

  // State for the 100-cycle search
  localparam LAT = 100;
  logic [$clog2(LAT):0] cycle;     // counts 0..99
  logic [7:0] comb;                // current combination number (0 .. 2^n - 1)
  logic [2:0] cnt;                 // current popcount(c)
  logic [3:0] max_found;           // best count found so far (0..8)
  logic [3:0] min_pw;              // 2^(cnt-1) for the current cnt
  logic [3:0] min_pw_next;         // 2^(cnt_next-1)

  // nCr value for current cnt: via precomputed table and a tiny loop
  logic [7:0] ncr_val, ncr_val_next;
  // Subset sums and masks for current combination
  logic [3:0] sums [0:255];
  logic [15:0] seen_mask;          // 16-bit mask for sums 0..15 (since weights <= 15)
  logic duplicate;                 // duplicate sum found for current combination
  // Subset sums and masks for next combination
  logic [3:0] sums_next [0:255];
  logic [15:0] seen_mask_next;
  logic duplicate_next;

  // Helper functions to compute index into binom table and fetch nCr
  function [7:0] nCr_index(input [2:0] r, input [2:0] c);
    // r in [1..8], c in [0..r-1]
    return ((r * (r - 1)) / 2) + c; // 0-based index
  endfunction

  function [7:0] get_nCr(input [3:0] N, input [3:0] K);
    integer idx;
    begin
      if (K > N) begin
        get_nCr = 8'd0;
      end else begin
        idx = nCr_index(N[2:0], K[2:0]);
        get_nCr = binom[idx];
      end
    end
  endfunction

  // Precompute binom table for n<=8 (max 8C4=70 < 256 fits in 8 bits)
  initial begin
    // r=1: C(1,0)=1
    binom[0] = 8'd1;
    // r=2: C(2,0)=1, C(2,1)=2
    binom[1] = 8'd1;
    binom[2] = 8'd2;
    // r=3: 1,3,3
    binom[3] = 8'd1;
    binom[4] = 8'd3;
    binom[5] = 8'd3;
    // r=4: 1,4,6,4
    binom[6] = 8'd1;
    binom[7] = 8'd4;
    binom[8] = 8'd6;
    binom[9] = 8'd4;
    // r=5: 1,5,10,10,5
    binom[10] = 8'd1;
    binom[11] = 8'd5;
    binom[12] = 8'd10;
    binom[13] = 8'd10;
    binom[14] = 8'd5;
    // r=6: 1,6,15,20,15,6
    binom[15] = 8'd1;
    binom[16] = 8'd6;
    binom[17] = 8'd15;
    binom[18] = 8'd20;
    binom[19] = 8'd15;
    binom[20] = 8'd6;
    // r=7: 1,7,21,35,35,21,7
    binom[21] = 8'd1;
    binom[22] = 8'd7;
    binom[23] = 8'd21;
    binom[24] = 8'd35;
    binom[25] = 8'd35;
    binom[26] = 8'd21;
    binom[27] = 8'd7;
    // r=8: 1,8,28,56,70,56,28,8
    binom[28] = 8'd1;
    binom[29] = 8'd8;
    binom[30] = 8'd28;
    binom[31] = 8'd56;
    binom[32] = 8'd70;
    binom[33] = 8'd56;
    binom[34] = 8'd28;
    binom[35] = 8'd8;
  end

  // Edge-detect for start pulse (registered)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_r1 <= 1'b0;
      start_r2 <= 1'b0;
    end else begin
      start_r1 <= start;
      start_r2 <= start_r1;
    end
  end
  assign start_pulse = start_r1 && (!start_r2);

  // Unpack saved weights to array (4-bit each, max 8)
  // a0 -> weights[3:0], a1 -> weights[7:4], ..., a7 -> weights[31:28]
  logic [3:0] a [0:7];
  integer i;
  always @(*) begin
    for (i = 0; i < 8; i = i + 1) begin
      a[i] = saved_weights[(4*i) +: 4];
    end
  end

  // Popcount for 8-bit value
  function [3:0] popcnt8(input [7:0] v);
    integer k;
    popcnt8 = 0;
    for (k = 0; k < 8; k = k + 1) begin
      if (v[k]) popcnt8 = popcnt8 + 1;
    end
  endfunction

  // 2^(k-1) when k>0 else 0
  function [3:0] pow2k_minus1(input [3:0] k);
    case (k)
      4'd0: pow2k_minus1 = 4'd0;
      4'd1: pow2k_minus1 = 4'd1; // 2^(1-1)
      4'd2: pow2k_minus1 = 4'd2; // 2^(2-1)
      4'd3: pow2k_minus1 = 4'd4;
      4'd4: pow2k_minus1 = 4'd8;
      4'd5: pow2k_minus1 = 4'd8; // cap at 8 for cnt up to 8
      4'd6: pow2k_minus1 = 4'd8;
      4'd7: pow2k_minus1 = 4'd8;
      4'd8: pow2k_minus1 = 4'd8;
      default: pow2k_minus1 = 4'd0;
    endcase
  endfunction

  // Compute subset sums (iterative parallel adders) for a given combination mask
  // We know subset count is min_pw for cnt>0 (from popcount > 0), and sums fit 0..15 because weights<=15.
  function void compute_subset_sums(input [7:0] mask, input [3:0] cnt_in, input [3:0] min_pw_in,
                                    output [3:0] sums_arr [0:255], output [15:0] seen_mask_out,
                                    output duplicate_out);
    integer s_idx, j, sum, bit_idx;
    logic [3:0] local_sums [0:255];
    logic [15:0] local_seen;
    logic local_dup;
  begin
    // initialize
    for (s_idx = 0; s_idx < 256; s_idx = s_idx + 1) local_sums[s_idx] = 4'd0;
    local_seen = 16'd0;
    local_dup = 1'b0;
    s_idx = 0;

    // For all subset masks of 'mask' (iterative addition: add one element at a time)
    for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
      if (mask[bit_idx]) begin
        // for each existing partial subset, add a[bit_idx]
        if (s_idx == 0) begin
          // first subset (empty)
          local_sums[0] = 4'd0;
        end
        // duplicate previous sums to upper half and add weight
        for (j = s_idx; j >= 0; j = j - 1) begin
          local_sums[j + s_idx + 1] = local_sums[j] + a[bit_idx];
        end
        s_idx = s_idx + s_idx + 1; // new number of subsets
      end
    end

    // Now we should have s_idx = 2^cnt_in subsets; check they don't exceed min_pw_in
    // s_idx should be exactly min_pw_in for cnt_in>0; if not, set duplicate and ignore.
    if (cnt_in > 0) begin
      if (s_idx != min_pw_in) begin
        local_dup = 1'b1; // mark invalid to avoid wrong check
      end
    end

    // Build seen mask and detect duplicates
    if (!local_dup) begin
      for (j = 0; j < s_idx; j = j + 1) begin
        sum = local_sums[j];
        if (local_seen[sum]) begin
          local_dup = 1'b1;
          // break; // we keep marking but don't need to continue
        end else begin
          local_seen[sum] = 1'b1;
        end
      end
    end

    // Return
    for (j = 0; j < 256; j = j + 1) sums_arr[j] = local_sums[j];
    seen_mask_out = local_seen;
    duplicate_out = local_dup;
  end
  endfunction

  // Main FSM
  // States: IDLE (done=0), BUSY (done=0), DONE (done=1)
  localparam IDLE = 2'b00;
  localparam BUSY = 2'b01;
  localparam DONE = 2'b10;
  logic [1:0] state;

  // Compute next values using current combination
  always @(*) begin
    cnt = popcnt8(comb);
    min_pw = pow2k_minus1(cnt);
    ncr_val = get_nCr(saved_n, cnt);
    // compute subset sums and duplicate flag for current comb
    compute_subset_sums(comb, cnt, min_pw, sums, seen_mask, duplicate);
  end

  // Compute next combination's values (for the next cycle's update)
  always @(*) begin
    ncr_val_next = get_nCr(saved_n, popcnt8(comb + 8'd1));
    min_pw_next = pow2k_minus1(popcnt8(comb + 8'd1));
    compute_subset_sums(comb + 8'd1, popcnt8(comb + 8'd1), min_pw_next, sums_next, seen_mask_next, duplicate_next);
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 4'd0;
      done <= 1'b0;
      saved_n <= 4'd0;
      saved_weights <= 32'd0;
      cycle <= 0;
      comb <= 8'd0;
      max_found <= 4'd0;
    end else begin
      case (state)
        IDLE: begin
          result <= 4'd0;
          done <= 1'b0;
          cycle <= 0;
          comb <= 8'd0;
          max_found <= 4'd0;
          if (start_pulse) begin
            saved_n <= (n == 4'd0) ? 4'd1 : n; // ensure n>=1 for valid range
            saved_weights <= weights;
            state <= BUSY;
          end
        end

        BUSY: begin
          // Evaluate current combination (cycle 0 uses comb=0)
          if (cnt > 0 && cnt <= saved_n) begin
            // Valid combination size within range
            // All-equal-to-m check: (w & m_mask) == 0; we compute m_mask via: (w0==0? '1 : w0)
            // and verify all weights (among selected) equal that base.
            // If duplicate sums exist, it's not identifiable.
            if (!duplicate) begin
              // Try to compute m_mask: use the first selected weight (lowest index in comb)
              // but if it's 0, any m>0 works; then we set m_mask to all-ones.
              logic [3:0] first_sel;
              logic [3:0] m_mask;
              integer f_idx;
              first_sel = 4'd0;
              m_mask = 4'd15; // default: all-ones if first_sel is 0 (then condition holds trivially)
              for (f_idx = 0; f_idx < 8; f_idx = f_idx + 1) begin
                if (comb[f_idx]) begin
                  first_sel = a[f_idx];
                  break;
                end
              end
              if (first_sel != 4'd0) m_mask = first_sel; // m_mask = w0
              // Check all selected weights have same remainder mask == 0 (i.e., are multiples of m)
              logic all_mul;
              integer chk;
              all_mul = 1'b1;
              for (chk = 0; chk < 8; chk = chk + 1) begin
                if (comb[chk]) begin
                  if ((a[chk] & m_mask) != 4'd0) all_mul = 1'b0;
                end
              end
              if (all_mul) begin
                // subset sums unique and all multiples of m -> identifiable
                if (cnt > max_found) max_found <= cnt;
              end
            end
          end

          // Advance to next combination on next cycle
          cycle <= cycle + 1;
          comb <= comb + 1;

          if (cycle == (LAT - 1)) begin
            state <= DONE;
            done <= 1'b1;
            result <= max_found;
          end
        end

        DONE: begin
          // Hold outputs until a new start pulse; if start held high continuously,
          // the FSM will relaunch on the next cycle after DONE.
          result <= max_found;
          done <= 1'b1;
          if (start_pulse) begin
            // restart
            saved_n <= (n == 4'd0) ? 4'd1 : n;
            saved_weights <= weights;
            cycle <= 0;
            comb <= 0;
            max_found <= 0;
            state <= BUSY;
            done <= 1'b0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule