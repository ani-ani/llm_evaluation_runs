module course_optimizer(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [3:0] k,
  input [7:0][9:0] difficulties,
  input [7:0] is_level1,
  input [7:0] is_level2,
  input [7:0] pair_id,
  output reg [12:0] min_sum,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam CALC = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state, next_state;
  reg [7:0] comb;        // current combination mask
  reg [7:0] n_mask;      // valid course mask based on n
  reg [7:0] pair_mask;   // mask of courses that belong to a pair (pair_id != 0)
  reg [6:0] cnt;         // up to 127 combinations
  wire [7:0] valid_mask; // courses that actually exist (n_mask)
  wire [3:0] num_valid;
  wire [12:0] sum;
  wire subset_valid;
  wire [3:0] sel_cnt;

  // Courses within the first n are considered valid
  assign valid_mask = n_mask;
  // Count of valid courses
  assign num_valid = ({1'b0, valid_mask[7:5]} + {3'b0, valid_mask[4]}) +
                     ({1'b0, valid_mask[3]} + {3'b0, valid_mask[2]}) +
                     ({1'b0, valid_mask[1]} + {3'b0, valid_mask[0]});

  // Sum of difficulties for current combination (unselected courses contribute 0)
  assign sum =
      ({3'b0, comb[0]} * difficulties[0]) +
      ({3'b0, comb[1]} * difficulties[1]) +
      ({3'b0, comb[2]} * difficulties[2]) +
      ({3'b0, comb[3]} * difficulties[3]) +
      ({3'b0, comb[4]} * difficulties[4]) +
      ({3'b0, comb[5]} * difficulties[5]) +
      ({3'b0, comb[6]} * difficulties[6]) +
      ({3'b0, comb[7]} * difficulties[7]);

  // Count selected courses in current combination
  assign sel_cnt =
      ({1'b0, comb[7:7]} + {2'b0, comb[6:6]}) +
      ({1'b0, comb[5:5]} + {2'b0, comb[4:4]}) +
      ({1'b0, comb[3:3]} + {2'b0, comb[2:2]}) +
      ({1'b0, comb[1:1]} + {2'b0, comb[0:0]});

  // Prerequisite check:
  // A combination is valid only if for every Level II course selected,
  // its paired Level I course is also selected (when both belong to the same pair).
  // This is equivalent to: no selected course is Level II without its paired Level I.
  // Only courses that are part of a pair (pair_id != 0) need to be checked.
  assign subset_valid =
      ((comb[0] & is_level2[0] & ~comb[1] & pair_mask[0]) ? 1'b0 : 1'b1) &
      ((comb[1] & is_level2[1] & ~comb[0] & pair_mask[1]) ? 1'b0 : 1'b1) &
      ((comb[2] & is_level2[2] & ~comb[3] & pair_mask[2]) ? 1'b0 : 1'b1) &
      ((comb[3] & is_level2[3] & ~comb[2] & pair_mask[3]) ? 1'b0 : 1'b1) &
      ((comb[4] & is_level2[4] & ~comb[5] & pair_mask[4]) ? 1'b0 : 1'b1) &
      ((comb[5] & is_level2[5] & ~comb[4] & pair_mask[5]) ? 1'b0 : 1'b1) &
      ((comb[6] & is_level2[6] & ~comb[7] & pair_mask[6]) ? 1'b0 : 1'b1) &
      ((comb[7] & is_level2[7] & ~comb[6] & pair_mask[7]) ? 1'b0 : 1'b1);

  // State update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else        state <= next_state;
  end

  // Next state and control logic
  always @(*) begin
    // Defaults
    next_state = state;
    done       = 1'b0;
    comb       = 8'b0;
    n_mask     = 8'b0;
    pair_mask  = 8'b0;
    cnt        = 7'b0;

    case (state)
      IDLE: begin
        if (start) begin
          // Setup valid course mask for n (1..8 valid courses)
          n_mask    = (n == 4'd0) ? 8'b0 :
                      (n == 4'd1) ? 8'b0000_0001 :
                      (n == 4'd2) ? 8'b0000_0011 :
                      (n == 4'd3) ? 8'b0000_0111 :
                      (n == 4'd4) ? 8'b0000_1111 :
                      (n == 4'd5) ? 8'b0001_1111 :
                      (n == 4'd6) ? 8'b0011_1111 :
                      (n == 4'd7) ? 8'b0111_1111 :
                                     8'b1111_1111;
          // Mark which courses have a non-zero pair_id (i.e., belong to a pair)
          pair_mask = (pair_id[0] != 3'b0) ? 8'b0000_0001 : 8'b0 |
                      (pair_id[1] != 3'b0) ? 8'b0000_0010 : 8'b0 |
                      (pair_id[2] != 3'b0) ? 8'b0000_0100 : 8'b0 |
                      (pair_id[3] != 3'b0) ? 8'b0000_1000 : 8'b0 |
                      (pair_id[4] != 3'b0) ? 8'b0001_0000 : 8'b0 |
                      (pair_id[5] != 3'b0) ? 8'b0010_0000 : 8'b0 |
                      (pair_id[6] != 3'b0) ? 8'b0100_0000 : 8'b0 |
                      (pair_id[7] != 3'b0) ? 8'b1000_0000 : 8'b0;
          comb      = 8'b0;
          cnt       = 7'b0;
          next_state = CALC;
          done       = 1'b0;
        end else begin
          next_state = IDLE;
          done       = 1'b0;
        end
      end

      CALC: begin
        // Iterate through all 128 combinations of up to 7 selected courses
        comb      = cnt[6:0];
        n_mask    = n_mask;  // keep
        pair_mask = pair_mask;
        cnt       = cnt + 1;
        next_state = (cnt == 7'd127) ? DONE : CALC;
        done       = 1'b0;
      end

      DONE: begin
        next_state = IDLE;
        done       = 1'b1; // result valid for 1 cycle
        comb       = 8'b0;
        n_mask     = 8'b0;
        pair_mask  = 8'b0;
        cnt        = 7'b0;
      end

      default: begin
        next_state = IDLE;
        done       = 1'b0;
        comb       = 8'b0;
        n_mask     = 8'b0;
        pair_mask  = 8'b0;
        cnt        = 7'b0;
      end
    endcase
  end

  // Selection and min tracking (combinational)
  always @(*) begin
    // If combination selects only valid courses (within n), meets size k, and passes prerequisites
    if ((comb & ~valid_mask) == 8'b0 && sel_cnt == k && subset_valid) begin
      min_sum = sum; // update candidate min
    end else begin
      min_sum = 13'h1FFF; // high watermark (will be overwritten by first valid candidate)
    end
  end

endmodule