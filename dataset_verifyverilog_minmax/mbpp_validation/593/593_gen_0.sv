module ip_zero_remover(
  input clk,
  input rst_n,
  input start,
  input [95:0] ip_bytes, // 4 segments x 3 bytes (ASCII)
  output reg [95:0] clean_bytes,
  output reg done
);

  // States
  localparam IDLE = 2'b00;
  localparam PROC = 2'b01;
  localparam DONE = 2'b10;

  // Registers
  reg [1:0] state_d, state_q;
  reg [3:0] cycle_d, cycle_q;    // counts 0..15 over the 16-cycle processing
  reg [1:0] seg_idx_d, seg_idx_q; // which segment (0..3) is being processed in this 4-cycle group
  reg [23:0] clean_seg_d, clean_seg_q; // 3 ASCII bytes for the current segment
  reg [95:0] outbuf_d, outbuf_q; // accumulates cleaned segments
  reg [7:0] c0, c1, c2; // current segment bytes
  reg [1:0] nchars;     // number of valid characters in cleaned segment (1..3)
  integer i;

  // Next-state logic
  always @(*) begin
    // Defaults
    state_d = state_q;
    cycle_d = cycle_q;
    seg_idx_d = seg_idx_q;
    clean_seg_d = clean_seg_q;
    outbuf_d = outbuf_q;
    done = 1'b0;

    // Split current segment (3 ASCII bytes, each 8 bits)
    c0 = ip_bytes[seg_idx_q*24 +: 8];
    c1 = ip_bytes[seg_idx_q*24+8 +: 8];
    c2 = ip_bytes[seg_idx_q*24+16 +: 8];
    nchars = 2'b0;
    clean_seg_d = 24'b0;

    case (state_q)
      IDLE: begin
        if (start) begin
          // Begin processing; take exactly 16 cycles
          state_d = PROC;
          cycle_d = 4'd0;
          seg_idx_d = 2'd0;
          outbuf_d = 96'b0;
        end
      end

      PROC: begin
        // Compute cleaned segment for seg_idx_q in this cycle
        // Rule: remove leading ASCII '0's, keep first non-zero digit, and subsequent digits.
        // If all three are '0', keep exactly one '0'.
        if (c0 != 8'h30) begin
          // First char is non-zero: keep all three characters
          clean_seg_d = {c0, c1, c2};
          nchars = 2'd3;
        end else if (c1 != 8'h30) begin
          // First is '0', second is non-zero: keep from second onward
          clean_seg_d = {c1, c2, 8'h30}; // pad trailing with '0' to keep 3 bytes
          nchars = 2'd2;
        end else if (c2 != 8'h30) begin
          // First two are '0', third is non-zero: keep third
          clean_seg_d = {c2, 8'h30, 8'h30};
          nchars = 2'd1;
        end else begin
          // All zeros: keep a single '0'
          clean_seg_d = {8'h30, 8'h30, 8'h30};
          nchars = 2'd1;
        end

        // Accumulate result in order
        outbuf_d = outbuf_q;
        outbuf_d[seg_idx_q*24 +: 24] = clean_seg_d;

        // Advance to next segment/cycle
        cycle_d = cycle_q + 1'b1;
        seg_idx_d = seg_idx_q + 1'b1;

        if (cycle_q == 4'd15) begin
          // Completed 16 cycles total (4 segments x 4 cycles each)
          state_d = DONE;
          done = 1'b1;        // Completion flag high in this cycle
          clean_bytes = outbuf_d; // Final output available
        end
      end

      DONE: begin
        // Hold done and outputs until start is deasserted (return to IDLE)
        done = 1'b1;
        clean_bytes = outbuf_q;
        if (!start) begin
          state_d = IDLE;
        end
      end
    endcase
  end

  // Sequential block
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state_q <= IDLE;
      cycle_q <= 4'd0;
      seg_idx_q <= 2'd0;
      clean_seg_q <= 24'b0;
      outbuf_q <= 96'b0;
      done <= 1'b0;
      clean_bytes <= 96'b0;
    end else begin
      state_q <= state_d;
      cycle_q <= cycle_d;
      seg_idx_q <= seg_idx_d;
      clean_seg_q <= clean_seg_d;
      outbuf_q <= outbuf_d;
      if (state_q == PROC && cycle_q == 4'd15) begin
        // In the last cycle of processing, update clean_bytes
        clean_bytes <= outbuf_d;
      end
      if (state_q == DONE) begin
        done <= 1'b1;
        clean_bytes <= outbuf_q;
      end else if (state_q == IDLE) begin
        done <= 1'b0;
      end
    end
  end

endmodule
