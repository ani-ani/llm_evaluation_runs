module digit_sum_finder(
  input clk,                // clock
  input rst_n,              // active-low reset
  input start,              // start computation
  input [15:0] A,           // range start (0-9999)
  input [15:0] B,           // range end (>= A)
  input [5:0] S,            // target digit sum (1-36)
  output reg [13:0] count,  // number of matches (0-10000)
  output reg [15:0] smallest_num, // smallest matching number
  output reg done           // high when computation completes
);

  // State machine
  typedef enum logic [1:0] {IDLE = 2'b00, RUN = 2'b01, DONE = 2'b10} state_t;
  state_t state, next_state;

  // Registers
  reg [15:0] current_num;
  reg [15:0] b_reg;
  reg [5:0] s_reg;
  reg [15:0] smallest_reg;
  reg [13:0] count_reg;

  // State and control registers update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 14'd0;
      smallest_num <= 16'hFFFF;
      done <= 1'b0;
      current_num <= 16'd0;
      b_reg <= 16'd0;
      s_reg <= 6'd0;
      smallest_reg <= 16'hFFFF;
      count_reg <= 14'd0;
    end else begin
      state <= next_state;

      // Outputs are set based on current state
      if (state == IDLE) begin
        count <= 14'd0;
        smallest_num <= 16'hFFFF;
        done <= 1'b0;
        count_reg <= 14'd0;
        smallest_reg <= 16'hFFFF;
      end else if (state == RUN) begin
        count <= count_reg;
        smallest_num <= smallest_reg;
        done <= 1'b0;
      end else if (state == DONE) begin
        count <= count_reg;
        smallest_num <= smallest_reg;
        done <= 1'b1;
      end

      // Pipeline latches for current_num, b_reg, s_reg
      current_num <= current_num;
      b_reg <= b_reg;
      s_reg <= s_reg;
    end
  end

  // State transition and datapath logic
  always_comb begin
    next_state = state;
    current_num = current_num;
    b_reg = b_reg;
    s_reg = s_reg;
    count_reg = count_reg;
    smallest_reg = smallest_reg;

    case (state)
      IDLE: begin
        if (start) begin
          current_num = A;
          b_reg = B;
          s_reg = S;
          count_reg = 14'd0;
          smallest_reg = 16'hFFFF;
          if (A > B) begin
            next_state = DONE;
          end else begin
            next_state = RUN;
          end
        end else begin
          next_state = IDLE;
        end
      end

      RUN: begin
        // Compute digit sum for current_num
        if (current_num <= b_reg) begin
          // Split into 4-digit BCD: thousands + hundreds + tens + units
          reg [3:0] thousands;
          reg [3:0] hundreds;
          reg [3:0] tens;
          reg [3:0] units;

          thousands = current_num / 1000;
          hundreds  = (current_num % 1000) / 100;
          tens      = (current_num % 100) / 10;
          units     = current_num % 10;

          if ((thousands + hundreds + tens + units) == s_reg) begin
            count_reg = count_reg + 1;
            if (current_num < smallest_reg) begin
              smallest_reg = current_num;
            end
          end

          current_num = current_num + 1;
        end

        // Check termination after processing
        if (current_num > b_reg) begin
          next_state = DONE;
        end else begin
          next_state = RUN;
        end
      end

      DONE: begin
        // Hold until reset or new start
        if (start) begin
          current_num = A;
          b_reg = B;
          s_reg = S;
          count_reg = 14'd0;
          smallest_reg = 16'hFFFF;
          if (A > B) begin
            next_state = DONE;
          end else begin
            next_state = RUN;
          end
        end else begin
          next_state = DONE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
