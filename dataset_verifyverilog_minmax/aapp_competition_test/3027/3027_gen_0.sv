module stamp_nub_minimizer(
  input clk,
  input rst_n,
  input start,
  input [7:0] grid_height,
  input [7:0] grid_width,
  input [63:0] paper_mark,
  output reg [3:0] min_nubs,
  output reg done
);

localparam IDLE=0, INIT=1, TRY_STAMP_SIZE=2, GEN_PLACEMENT=3, GEN_PLACEMENT_CHECK=4, RECORD_MIN=5, DONE=6;

reg [2:0] state;
reg [7:0] sh, sw;
reg [63:0] pattern_index;
reg [3:0] nub_count;
reg [7:0] r0, c0;
reg [5:0] valid_count;
reg [63:0] valid_placement_masks [0:63];
reg [63:0] placement_mask;
reg found;
reg [5:0] i;

// Function to count ones in a 64-bit vector
function [6:0] count_ones;
  input [63:0] vec;
  integer j;
  begin
    count_ones = 0;
    for (j = 0; j < 64; j = j + 1) begin
      if (vec[j]) count_ones = count_ones + 1;
    end
  end
endfunction

// Function to compute placement mask for a given pattern and position
function [63:0] compute_placement_mask;
  input [63:0] pattern_bits;
  input [7:0] r0, c0, sh, sw;
  integer r, c;
  reg [63:0] mask;
  begin
    mask = 0;
    for (r = 0; r < sh; r = r + 1) begin
      for (c = 0; c < sw; c = c + 1) begin
        if (pattern_bits[r*sw + c]) begin
          mask = mask | (1 << ((r0 + r) * 8 + (c0 + c)));
        end
      end
    end
    compute_placement_mask = mask;
  end
endfunction

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    min_nubs <= 4'd15; // Saturate at 15 since 4-bit output
    done <= 0;
  end else begin
    case (state)
      IDLE: begin
        if (start) begin
          state <= INIT;
        end
      end
      INIT: begin
        sh <= 8'd1;
        sw <= 8'd1;
        pattern_index <= 64'd0;
        min_nubs <= 4'd15;
        done <= 0;
        state <= TRY_STAMP_SIZE;
      end
      TRY_STAMP_SIZE: begin
        if (sh > grid_height) begin
          state <= DONE;
        end else begin
          sw <= 8'd1;
          state <= GEN_PLACEMENT;
        end
      end
      GEN_PLACEMENT: begin
        if (r0 > grid_height - sh) begin
          // Done with all placements for this pattern, move to next pattern
          pattern_index <= pattern_index + 1;
          if (pattern_index >= (1 << (sh * sw)) - 1) begin
            sh <= sh + 1;
            state <= TRY_STAMP_SIZE;
          end else begin
            state <= GEN_PLACEMENT; // Continue with next pattern
          end
        end else if (c0 > grid_width - sw) begin
          r0 <= r0 + 1;
          c0 <= 8'd0;
          state <= GEN_PLACEMENT;
        end else begin
          // Generate placement mask for current (r0, c0)
          placement_mask = compute_placement_mask(pattern_index, r0, c0, sh, sw);
          // Check if placement is subset of paper_mark
          if ((placement_mask & ~paper_mark) == 0) begin
            state <= GEN_PLACEMENT_CHECK;
          end else begin
            c0 <= c0 + 1;
            state <= GEN_PLACEMENT;
          end
        end
      end
      GEN_PLACEMENT_CHECK: begin
        if (placement_mask == paper_mark) begin
          min_nubs <= nub_count;
          state <= RECORD_MIN;
        end else begin
          found = 0;
          for (i = 0; i < valid_count; i = i + 1) begin
            if ((placement_mask | valid_placement_masks[i]) == paper_mark) begin
              found = 1;
            end
          end
          if (found) begin
            min_nubs <= nub_count;
            state <= RECORD_MIN;
          end else begin
            valid_placement_masks[valid_count] <= placement_mask;
            valid_count <= valid_count + 1;
            c0 <= c0 + 1;
            state <= GEN_PLACEMENT;
          end
        end
      end
      RECORD_MIN: begin
        pattern_index <= pattern_index + 1;
        if (pattern_index >= (1 << (sh * sw)) - 1) begin
          sh <= sh + 1;
          state <= TRY_STAMP_SIZE;
        end else begin
          state <= GEN_PLACEMENT;
        end
      end
      DONE: begin
        done <= 1;
        state <= IDLE;
      end
      default: state <= IDLE;
    endcase
  end
end

// Calculate nub_count for current pattern
always @(*) begin
  if (state == GEN_PLACEMENT_CHECK || state == RECORD_MIN) begin
    nub_count = count_ones(pattern_index[0 : sh * sw - 1]);
  end else begin
    nub_count = 0;
  end
end

endmodule