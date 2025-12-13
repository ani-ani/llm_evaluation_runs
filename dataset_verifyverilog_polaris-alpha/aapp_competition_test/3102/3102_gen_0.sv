module house_number_counter(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start processing
  input [15:0] L, // Lower bound
  input [15:0] R, // Upper bound
  output reg [15:0] count, // Valid house count
  output reg done // High when counting complete
);

  // State encoding
  localparam IDLE      = 2'b00;
  localparam COUNTING  = 2'b01;
  localparam DONE_WAIT = 2'b10;

  reg [1:0] state, next_state;
  reg [15:0] current_number, next_current_number;
  reg [15:0] next_count;
  reg next_done;

  // Combinational signals for digit evaluation
  reg [15:0] num_val;
  reg [3:0] d4, d3, d2, d1, d0; // 5 decimal digits
  reg has4;
  reg [2:0] lucky_cnt;
  reg [2:0] non_lucky_cnt;
  reg started;
  reg [15:0] diff;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      current_number <= 16'd0;
      count          <= 16'd0;
      done           <= 1'b0;
    end else begin
      state          <= next_state;
      current_number <= next_current_number;
      count          <= next_count;
      done           <= next_done;
    end
  end

  // Combinational next-state and output logic
  always @* begin
    // Default assignments
    next_state          = state;
    next_current_number = current_number;
    next_count          = count;
    next_done           = 1'b0;

    // Defaults for digit processing
    num_val       = current_number;
    d4 = 4'd0;
    d3 = 4'd0;
    d2 = 4'd0;
    d1 = 4'd0;
    d0 = 4'd0;
    has4          = 1'b0;
    lucky_cnt     = 3'd0;
    non_lucky_cnt = 3'd0;
    started       = 1'b0;
    diff          = 16'd0;

    case (state)
      IDLE: begin
        // Wait for start; initialize when asserted
        if (start) begin
          next_state          = COUNTING;
          next_current_number = L;
          next_count          = 16'd0;
        end
      end

      COUNTING: begin
        // If range finished, move to DONE_WAIT
        if (current_number > R) begin
          next_state = DONE_WAIT;
        end else begin
          // Decimal conversion (5-digit, 0..65535)
          // d4: ten-thousands digit
          if (num_val >= 16'd50000) begin
            d4     = 4'd5;
            diff   = num_val - 16'd50000;
          end else if (num_val >= 16'd40000) begin
            d4     = 4'd4;
            diff   = num_val - 16'd40000;
          end else if (num_val >= 16'd30000) begin
            d4     = 4'd3;
            diff   = num_val - 16'd30000;
          end else if (num_val >= 16'd20000) begin
            d4     = 4'd2;
            diff   = num_val - 16'd20000;
          end else if (num_val >= 16'd10000) begin
            d4     = 4'd1;
            diff   = num_val - 16'd10000;
          end else begin
            d4     = 4'd0;
            diff   = num_val;
          end

          // d3: thousands digit
          if (diff >= 16'd9000) begin
            d3   = 4'd9;
            diff = diff - 16'd9000;
          end else if (diff >= 16'd8000) begin
            d3   = 4'd8;
            diff = diff - 16'd8000;
          end else if (diff >= 16'd7000) begin
            d3   = 4'd7;
            diff = diff - 16'd7000;
          end else if (diff >= 16'd6000) begin
            d3   = 4'd6;
            diff = diff - 16'd6000;
          end else if (diff >= 16'd5000) begin
            d3   = 4'd5;
            diff = diff - 16'd5000;
          end else if (diff >= 16'd4000) begin
            d3   = 4'd4;
            diff = diff - 16'd4000;
          end else if (diff >= 16'd3000) begin
            d3   = 4'd3;
            diff = diff - 16'd3000;
          end else if (diff >= 16'd2000) begin
            d3   = 4'd2;
            diff = diff - 16'd2000;
          end else if (diff >= 16'd1000) begin
            d3   = 4'd1;
            diff = diff - 16'd1000;
          end else begin
            d3   = 4'd0;
          end

          // d2: hundreds digit
          if (diff >= 16'd900) begin
            d2   = 4'd9;
            diff = diff - 16'd900;
          end else if (diff >= 16'd800) begin
            d2   = 4'd8;
            diff = diff - 16'd800;
          end else if (diff >= 16'd700) begin
            d2   = 4'd7;
            diff = diff - 16'd700;
          end else if (diff >= 16'd600) begin
            d2   = 4'd6;
            diff = diff - 16'd600;
          end else if (diff >= 16'd500) begin
            d2   = 4'd5;
            diff = diff - 16'd500;
          end else if (diff >= 16'd400) begin
            d2   = 4'd4;
            diff = diff - 16'd400;
          end else if (diff >= 16'd300) begin
            d2   = 4'd3;
            diff = diff - 16'd300;
          end else if (diff >= 16'd200) begin
            d2   = 4'd2;
            diff = diff - 16'd200;
          end else if (diff >= 16'd100) begin
            d2   = 4'd1;
            diff = diff - 16'd100;
          end else begin
            d2   = 4'd0;
          end

          // d1: tens digit
          if (diff >= 16'd90) begin
            d1   = 4'd9;
            diff = diff - 16'd90;
          end else if (diff >= 16'd80) begin
            d1   = 4'd8;
            diff = diff - 16'd80;
          end else if (diff >= 16'd70) begin
            d1   = 4'd7;
            diff = diff - 16'd70;
          end else if (diff >= 16'd60) begin
            d1   = 4'd6;
            diff = diff - 16'd60;
          end else if (diff >= 16'd50) begin
            d1   = 4'd5;
            diff = diff - 16'd50;
          end else if (diff >= 16'd40) begin
            d1   = 4'd4;
            diff = diff - 16'd40;
          end else if (diff >= 16'd30) begin
            d1   = 4'd3;
            diff = diff - 16'd30;
          end else if (diff >= 16'd20) begin
            d1   = 4'd2;
            diff = diff - 16'd20;
          end else if (diff >= 16'd10) begin
            d1   = 4'd1;
            diff = diff - 16'd10;
          end else begin
            d1   = 4'd0;
          end

          // d0: ones digit
          d0 = diff[3:0];

          // Check for digit '4'
          has4 = (d4 == 4'd4) || (d3 == 4'd4) || (d2 == 4'd4) || (d1 == 4'd4) || (d0 == 4'd4);

          // Count lucky (6,8) and non-lucky digits from first non-zero digit
          lucky_cnt     = 3'd0;
          non_lucky_cnt = 3'd0;
          started       = 1'b0;

          // d4
          if (!started && d4 != 4'd0)
            started = 1'b1;
          if (started) begin
            if (d4 == 4'd6 || d4 == 4'd8)
              lucky_cnt = lucky_cnt + 3'd1;
            else
              non_lucky_cnt = non_lucky_cnt + 3'd1;
          end

          // d3
          if (!started && d3 != 4'd0)
            started = 1'b1;
          if (started) begin
            if (d3 == 4'd6 || d3 == 4'd8)
              lucky_cnt = lucky_cnt + 3'd1;
            else
              non_lucky_cnt = non_lucky_cnt + 3'd1;
          end

          // d2
          if (!started && d2 != 4'd0)
            started = 1'b1;
          if (started) begin
            if (d2 == 4'd6 || d2 == 4'd8)
              lucky_cnt = lucky_cnt + 3'd1;
            else
              non_lucky_cnt = non_lucky_cnt + 3'd1;
          end

          // d1
          if (!started && d1 != 4'd0)
            started = 1'b1;
          if (started) begin
            if (d1 == 4'd6 || d1 == 4'd8)
              lucky_cnt = lucky_cnt + 3'd1;
            else
              non_lucky_cnt = non_lucky_cnt + 3'd1;
          end

          // d0 (always part of number; if all zero, it's the only digit and started should be considered here)
          if (!started) begin
            // handle value 0: treat as single digit '0'
            started = 1'b1;
          end
          if (d0 == 4'd6 || d0 == 4'd8)
            lucky_cnt = lucky_cnt + 3'd1;
          else
            non_lucky_cnt = non_lucky_cnt + 3'd1;

          // Update count if valid
          if (!has4 && (lucky_cnt == non_lucky_cnt)) begin
            next_count = count + 16'd1;
          end

          // Increment number for next cycle
          next_current_number = current_number + 16'd1;
        end
      end

      DONE_WAIT: begin
        // Assert done for one cycle, then go back to IDLE
        next_done  = 1'b1;
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule