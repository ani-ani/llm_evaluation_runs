module temperature_predictor (
  input clk,
  input rst_n,
  input start,
  input signed [11:0] temp_0, temp_1, temp_2, temp_3, temp_4, temp_5, temp_6, temp_7,
  input [2:0] n,
  output reg signed [11:0] prediction,
  output reg done
);

  localparam IDLE = 2'b00;
  localparam COMPARE = 2'b01;
  localparam CALCULATE = 2'b10;
  localparam DONE = 2'b11;

  reg [1:0] state, next_state;
  reg [2:0] stage, next_stage;
  reg common_diff_valid;
  reg [6:0] diff_valid_mask;
  reg signed [11:0] prev_temps [6:0];
  reg signed [11:0] diff_reg [6:0];
  reg signed [11:0] common_diff, next_common_diff;
  reg signed [11:0] result, next_result;
  reg next_done;
  integer k;

  always @(*) begin
    next_state = state;
    next_stage = stage;
    next_done = 1'b0;
    next_result = result;
    next_common_diff = common_diff;
    next_common_diff_valid = 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = COMPARE;
          next_stage = 3'd0;
          // Only valid if at least two samples exist (n>=2 by spec)
          next_common_diff = temp_1 - temp_0;
          next_common_diff_valid = 1'b1;
        end else begin
          next_common_diff_valid = 1'b0;
        end
      end

      COMPARE: begin
        next_common_diff_valid = common_diff_valid;
        next_stage = stage + 1;

        // Prepare prediction early for n=2 (arithmetic with 2 points)
        if ((n == 3'd2) && (stage == 3'd0)) begin
          next_result = temp_1 + common_diff;
          next_done = 1'b1;
          next_state = DONE;
        end

        // For more points, we compute in CALCULATE after the comparison window
        if (n > 3'd2) begin
          if (stage == 3'd6) begin
            next_state = CALCULATE;
            next_stage = 3'd0;
          end
        end else begin
          // n == 2 already handled above, remain in DONE
          if (stage == 3'd6) begin
            next_state = DONE;
            next_stage = 3'd0;
          end
        end
      end

      CALCULATE: begin
        next_common_diff_valid = 1'b0;
        next_stage = stage + 1;

        // temp[n-1] + common_diff using iterative addition
        next_result = result + common_diff;

        if (stage == 3'd6) begin
          next_state = DONE;
          next_done = 1'b1;
          next_stage = 3'd0;
        end
      end

      DONE: begin
        next_done = 1'b0;
        if (start) begin
          next_state = COMPARE;
          next_stage = 3'd0;
          next_common_diff = temp_1 - temp_0;
          next_common_diff_valid = 1'b1;
        end else begin
          next_state = IDLE;
          next_common_diff_valid = 1'b0;
          next_stage = 3'd0;
        end
      end

      default: begin
        next_state = IDLE;
        next_stage = 3'd0;
        next_done = 1'b0;
        next_common_diff_valid = 1'b0;
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      stage <= 3'd0;
      done <= 1'b0;
      common_diff_valid <= 1'b0;
      diff_valid_mask <= 7'b0;
      common_diff <= 12'sd0;
      result <= 12'sd0;
      for (k = 0; k < 7; k = k + 1) begin
        diff_reg[k] <= 12'sd0;
        prev_temps[k] <= 12'sd0;
      end
    end else begin
      state <= next_state;
      stage <= next_stage;
      done <= next_done;
      common_diff <= next_common_diff;
      result <= next_result;
      common_diff_valid <= next_common_diff_valid;

      // Shifting pipelines for differences and valid mask (8 cycles total)
      diff_reg[6] <= (stage == 3'd0) ? (temp_1 - temp_0) : diff_reg[5];
      prev_temps[6] <= (stage == 3'd0) ? temp_0 : prev_temps[5];
      for (k = 0; k < 6; k = k + 1) begin
        diff_reg[k] <= (k == 0) ? (temp_1 - temp_0) : diff_reg[k-1];
        prev_temps[k] <= (k == 0) ? temp_0 : prev_temps[k-1];
      end

      // Which differences correspond to indices within [0, n-1]?
      // Differences d[0..5] represent temp[2]-temp[1] .. temp[7]-temp[6]
      // They are valid if k+1 < n  =>  k < n-1  =>  k <= n-2
      case (n)
        3'd2: diff_valid_mask <= 7'b0000000; // no differences needed
        3'd3: diff_valid_mask <= 7'b0000001; // only d0 valid
        3'd4: diff_valid_mask <= 7'b0000011; // d0,d1
        3'd5: diff_valid_mask <= 7'b0000111; // d0..d2
        3'd6: diff_valid_mask <= 7'b0001111; // d0..d3
        3'd7: diff_valid_mask <= 7'b0011111; // d0..d4
        3'd8: diff_valid_mask <= 7'b0111111; // d0..d5
        default: diff_valid_mask <= 7'b0000000; // should not occur per spec
      endcase
    end
  end

endmodule
