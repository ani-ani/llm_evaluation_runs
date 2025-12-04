module lucky_number_supply(
  input clk, // System clock
  input rst_n, // Active-low reset
  input start, // Start computation (pulse high)
  input [3:0] n, // Digit count (2-3)
  output reg [15:0] supply_count, // Result (number of valid numbers)
  output reg done // High when computation completes
);

  // State encoding
  localparam IDLE        = 3'd0;
  localparam GEN_DIGIT_1 = 3'd1;
  localparam GEN_DIGIT_2 = 3'd2;
  localparam GEN_DIGIT_3 = 3'd3;
  localparam DONE        = 3'd4;

  reg [2:0] state, next_state;

  // Digit registers
  reg [3:0] d1; // first digit: 1-9
  reg [3:0] d2; // second digit: 0-9
  reg [3:0] d3; // third digit: 0-9

  // Start edge detection
  reg start_d;
  wire start_pulse = start & ~start_d;

  // Sequential logic: state, counters, and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      supply_count <= 16'd0;
      done <= 1'b0;
      d1 <= 4'd0;
      d2 <= 4'd0;
      d3 <= 4'd0;
      start_d <= 1'b0;
    end else begin
      start_d <= start;
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          supply_count <= 16'd0;
          if (start_pulse) begin
            // Initialize for first digit generation
            d1 <= 4'd1; // start from 1
            d2 <= 4'd0;
            d3 <= 4'd0;
          end
        end

        GEN_DIGIT_1: begin
          // GEN_DIGIT_1 simply transitions to GEN_DIGIT_2
          // d1 already initialized to 1 on start
        end

        GEN_DIGIT_2: begin
          // For each cycle, evaluate current (d1,d2) pair
          // Check divisibility of 2-digit prefix by 2
          if (((d1 * 10 + d2) % 2) == 0) begin
            if (n == 4'd2) begin
              // Valid 2-digit lucky number
              supply_count <= supply_count + 16'd1;
            end
          end

          // Increment digit iterators for next cycle
          if (d2 == 4'd9) begin
            d2 <= 4'd0;
            if (d1 == 4'd9) begin
              // Completed all d1=1..9 and d2=0..9
              // Transition handled by next_state logic
            end else begin
              d1 <= d1 + 4'd1;
            end
          end else begin
            d2 <= d2 + 4'd1;
          end
        end

        GEN_DIGIT_3: begin
          // Only used when n >= 3
          // We iterate all digits here and only count on valid 2-digit prefixes

          // First ensure current 2-digit prefix is valid
          if (((d1 * 10 + d2) % 2) == 0) begin
            // For each candidate d3, check 3-digit divisibility by 3
            if (((d1 * 100 + d2 * 10 + d3) % 3) == 0) begin
              supply_count <= supply_count + 16'd1;
            end
          end

          // Increment digit iterators for next (d1,d2,d3)
          if (d3 == 4'd9) begin
            d3 <= 4'd0;
            if (d2 == 4'd9) begin
              d2 <= 4'd0;
              if (d1 == 4'd9) begin
                // Completed all combinations; transition handled by next_state
              end else begin
                d1 <= d1 + 4'd1;
              end
            end else begin
              d2 <= d2 + 4'd1;
            end
          end else begin
            d3 <= d3 + 4'd1;
          end
        end

        DONE: begin
          done <= 1'b1;
          // Hold supply_count until next start
        end

        default: begin
          // Safety fallback
          state <= IDLE;
        end
      endcase
    end
  end

  // Next state combinational logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start_pulse) begin
          next_state = GEN_DIGIT_1;
        end
      end

      GEN_DIGIT_1: begin
        // Immediately proceed to digit 2 generation
        next_state = GEN_DIGIT_2;
      end

      GEN_DIGIT_2: begin
        if (n == 4'd2) begin
          // For n=2, when all (d1,d2) combos done -> DONE
          if ((d1 == 4'd9) && (d2 == 4'd9)) begin
            next_state = DONE;
          end else begin
            next_state = GEN_DIGIT_2;
          end
        end else begin
          // n >= 3: when all (d1,d2) combos done, go to GEN_DIGIT_3
          if ((d1 == 4'd9) && (d2 == 4'd9)) begin
            // Re-initialize counters at beginning of GEN_DIGIT_3 via sequential logic
            next_state = GEN_DIGIT_3;
          end else begin
            next_state = GEN_DIGIT_2;
          end
        end
      end

      GEN_DIGIT_3: begin
        // For n>=3: when all (d1,d2,d3) combos done -> DONE
        if ((d1 == 4'd9) && (d2 == 4'd9) && (d3 == 4'd9)) begin
          next_state = DONE;
        end else begin
          next_state = GEN_DIGIT_3;
        end
      end

      DONE: begin
        // Wait here until a new start pulse
        if (start_pulse) begin
          next_state = GEN_DIGIT_1;
        end else begin
          next_state = DONE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Ensure proper initialization for GEN_DIGIT_3 when transitioning from GEN_DIGIT_2
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // already handled in main reset
    end else begin
      if ((state == GEN_DIGIT_2) && (next_state == GEN_DIGIT_3)) begin
        // Initialize to first combination for 3-digit search
        d1 <= 4'd1;
        d2 <= 4'd0;
        d3 <= 4'd0;
      end
    end
  end

endmodule