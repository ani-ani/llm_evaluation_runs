module clock_setter (
  input clk,
  input rst_n,
  input start,
  input [7:0] start_hh,
  input [7:0] start_mm,
  input [7:0] target_hh,
  input [7:0] target_mm,
  output reg [7:0] current_hh,
  output reg [7:0] current_mm,
  output reg done,
  output reg [3:0] count
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    SETUP_MIN_ONES,
    SETUP_MIN_TENS,
    SETUP_MIN_ONES2,
    SETUP_HR_ONES,
    SETUP_HR_TENS,
    SETUP_HR_ONES2,
    DONE
  } state_t;

  state_t state, next_state;
  reg [7:0] current_hh_reg, current_mm_reg;
  reg [3:0] count_reg;
  reg done_reg;

  // Extract digits from BCD
  function [3:0] get_ones(input [7:0] bcd);
    return bcd[3:0];
  endfunction

  function [3:0] get_tens(input [7:0] bcd);
    return bcd[7:4];
  endfunction

  // Create BCD from digits
  function [7:0] make_bcd(input [3:0] tens, input [3:0] ones);
    return {tens, ones};
  endfunction

  // Calculate shortest path for ones digit (with wraparound)
  function logic [1:0] get_ones_dir(input [3:0] current, input [3:0] target);
    if (current == target) return 2'b00; // no change
    if ((current + 1) % 10 == target) return 2'b01; // increment
    if ((current - 1 + 10) % 10 == target) return 2'b10; // decrement
    // For multiple steps, choose direction with fewer steps
    if ((target - current + 10) % 10 <= 5) return 2'b01; // increment
    else return 2'b10; // decrement
  endfunction

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_hh_reg <= 8'h00;
      current_mm_reg <= 8'h00;
      count_reg <= 4'h0;
      done_reg <= 1'b0;
    end else begin
      state <= next_state;
      current_hh_reg <= current_hh_reg;
      current_mm_reg <= current_mm_reg;
      count_reg <= count_reg;
      done_reg <= done_reg;
    end
  end

  always @(*) begin
    next_state = state;
    current_hh = current_hh_reg;
    current_mm = current_mm_reg;
    count = count_reg;
    done = done_reg;

    case (state)
      IDLE: begin
        if (start) begin
          current_hh_reg = start_hh;
          current_mm_reg = start_mm;
          count_reg = 4'h0;
          done_reg = 1'b0;
          next_state = SETUP_MIN_ONES;
        end
      end

      SETUP_MIN_ONES: begin
        // Process minutes ones digit
        reg [3:0] current_ones = get_ones(current_mm_reg);
        reg [3:0] target_ones = get_ones(target_mm);
        reg [3:0] current_tens = get_tens(current_mm_reg);
        reg [3:0] target_tens = get_tens(target_mm);

        if (current_ones == target_ones) begin
          // No change needed for ones digit
          if (current_tens == target_tens) begin
            // Minutes already match, move to hours
            next_state = SETUP_HR_ONES;
          end else begin
            // Only tens digit needs change
            next_state = SETUP_MIN_TENS;
          end
        end else begin
          // Change ones digit
          reg [1:0] dir = get_ones_dir(current_ones, target_ones);
          if (dir == 2'b01) begin
            current_ones = current_ones + 1;
            if (current_ones == 4'hA) current_ones = 4'h0;
          end else if (dir == 2'b10) begin
            current_ones = current_ones - 1;
            if (current_ones == 4'hF) current_ones = 4'h9;
          end

          current_mm_reg = make_bcd(current_tens, current_ones);
          count_reg = count_reg + 1;

          // Check if we need to go through 00
          if (current_tens != target_tens && current_ones == 4'h0) begin
            next_state = SETUP_MIN_TENS;
          end else if (current_ones == target_ones) begin
            if (current_tens == target_tens) begin
              next_state = SETUP_HR_ONES;
            end else begin
              next_state = SETUP_MIN_TENS;
            end
          end
        end
      end

      SETUP_MIN_TENS: begin
        // Process minutes tens digit
        reg [3:0] current_ones = get_ones(current_mm_reg);
        reg [3:0] target_ones = get_ones(target_mm);
        reg [3:0] current_tens = get_tens(current_mm_reg);
        reg [3:0] target_tens = get_tens(target_mm);

        if (current_tens == target_tens) begin
          // Tens digit already matches
          if (current_ones == target_ones) begin
            next_state = SETUP_HR_ONES;
          end else begin
            next_state = SETUP_MIN_ONES2;
          end
        end else begin
          // Change tens digit linearly
          if (current_tens < target_tens) begin
            current_tens = current_tens + 1;
          end else begin
            current_tens = current_tens - 1;
          end

          current_mm_reg = make_bcd(current_tens, current_ones);
          count_reg = count_reg + 1;

          if (current_tens == target_tens) begin
            if (current_ones == target_ones) begin
              next_state = SETUP_HR_ONES;
            end else begin
              next_state = SETUP_MIN_ONES2;
            end
          end
        end
      end

      SETUP_MIN_ONES2: begin
        // Process minutes ones digit after tens change
        reg [3:0] current_ones = get_ones(current_mm_reg);
        reg [3:0] target_ones = get_ones(target_mm);
        reg [3:0] current_tens = get_tens(current_mm_reg);

        if (current_ones == target_ones) begin
          next_state = SETUP_HR_ONES;
        end else begin
          reg [1:0] dir = get_ones_dir(current_ones, target_ones);
          if (dir == 2'b01) begin
            current_ones = current_ones + 1;
            if (current_ones == 4'hA) current_ones = 4'h0;
          end else if (dir == 2'b10) begin
            current_ones = current_ones - 1;
            if (current_ones == 4'hF) current_ones = 4'h9;
          end

          current_mm_reg = make_bcd(current_tens, current_ones);
          count_reg = count_reg + 1;

          if (current_ones == target_ones) begin
            next_state = SETUP_HR_ONES;
          end
        end
      end

      SETUP_HR_ONES: begin
        // Process hours ones digit
        reg [3:0] current_ones = get_ones(current_hh_reg);
        reg [3:0] target_ones = get_ones(target_hh);
        reg [3:0] current_tens = get_tens(current_hh_reg);
        reg [3:0] target_tens = get_tens(target_hh);

        if (current_ones == target_ones) begin
          // No change needed for ones digit
          if (current_tens == target_tens) begin
            // Hours already match, we're done
            next_state = DONE;
          end else begin
            // Only tens digit needs change
            next_state = SETUP_HR_TENS;
          end
        end else begin
          // Change ones digit
          reg [1:0] dir = get_ones_dir(current_ones, target_ones);
          if (dir == 2'b01) begin
            current_ones = current_ones + 1;
            if (current_ones == 4'hA) current_ones = 4'h0;
          end else if (dir == 2'b10) begin
            current_ones = current_ones - 1;
            if (current_ones == 4'hF) current_ones = 4'h9;
          end

          current_hh_reg = make_bcd(current_tens, current_ones);
          count_reg = count_reg + 1;

          // Check if we need to go through 00
          if (current_tens != target_tens && current_ones == 4'h0) begin
            next_state = SETUP_HR_TENS;
          end else if (current_ones == target_ones) begin
            if (current_tens == target_tens) begin
              next_state = DONE;
            end else begin
              next_state = SETUP_HR_TENS;
            end
          end
        end
      end

      SETUP_HR_TENS: begin
        // Process hours tens digit
        reg [3:0] current_ones = get_ones(current_hh_reg);
        reg [3:0] target_ones = get_ones(target_hh);
        reg [3:0] current_tens = get_tens(current_hh_reg);
        reg [3:0] target_tens = get_tens(target_hh);

        if (current_tens == target_tens) begin
          // Tens digit already matches
          if (current_ones == target_ones) begin
            next_state = DONE;
          end else begin
            next_state = SETUP_HR_ONES2;
          end
        end else begin
          // Change tens digit linearly
          if (current_tens < target_tens) begin
            current_tens = current_tens + 1;
          end else begin
            current_tens = current_tens - 1;
          end

          current_hh_reg = make_bcd(current_tens, current_ones);
          count_reg = count_reg + 1;

          if (current_tens == target_tens) begin
            if (current_ones == target_ones) begin
              next_state = DONE;
            end else begin
              next_state = SETUP_HR_ONES2;
            end
          end
        end
      end

      SETUP_HR_ONES2: begin
        // Process hours ones digit after tens change
        reg [3:0] current_ones = get_ones(current_hh_reg);
        reg [3:0] target_ones = get_ones(target_hh);
        reg [3:0] current_tens = get_tens(current_hh_reg);

        if (current_ones == target_ones) begin
          next_state = DONE;
        end else begin
          reg [1:0] dir = get_ones_dir(current_ones, target_ones);
          if (dir == 2'b01) begin
            current_ones = current_ones + 1;
            if (current_ones == 4'hA) current_ones = 4'h0;
          end else if (dir == 2'b10) begin
            current_ones = current_ones - 1;
            if (current_ones == 4'hF) current_ones = 4'h9;
          end

          current_hh_reg = make_bcd(current_tens, current_ones);
          count_reg = count_reg + 1;

          if (current_ones == target_ones) begin
            next_state = DONE;
          end
        end
      end

      DONE: begin
        done_reg = 1'b1;
        if (!start) begin
          next_state = IDLE;
          done_reg = 1'b0;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule