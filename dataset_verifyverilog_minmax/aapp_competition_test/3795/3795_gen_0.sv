module currency_exchange(
  input clk,
  input rst_n,
  input start,        // pulse high to begin
  input [15:0] n,     // initial rubles (1-65535)
  input [7:0] d,      // dollar rate (30-100)
  input [7:0] e,      // euro rate (30-100)
  output reg [15:0] min_rubles, // minimized rubles result
  output reg done                     // high for 1 cycle when done
);

  // 5*e cannot exceed 500 -> 9 bits sufficient
  logic [8:0] e5;
  assign e5 = 5 * e;

  // State encoding
  localparam IDLE = 2'b00;
  localparam CALC = 2'b01;
  localparam DONE = 2'b10;

  reg [1:0] state, next_state;
  reg [7:0] i;               // iteration counter (0..255)
  reg [7:0] i_max_q;         // latched iteration bound (0..255)
  reg [15:0] curr_rem;       // (n - i*5*e) % d at current i
  reg [15:0] best;           // best(min) remainder seen so far
  reg start_d;
  wire start_posedge = start && !start_d;

  // Latch inputs on start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 8'b0;
      i_max_q <= 8'b0;
      curr_rem <= 16'b0;
      best <= 16'hFFFF;
      min_rubles <= 16'b0;
      done <= 1'b0;
      start_d <= 1'b0;
    end else begin
      start_d <= start;
      state <= next_state;

      case (state)
        IDLE: begin
          i <= 8'b0;
          best <= 16'hFFFF;
          done <= 1'b0;
          if (start_posedge) begin
            // l_max = min(n/(5*e), 256)
            // We use i in [0, i_max_q], so bound i_max_q to 0..255.
            // If l_max = 256, i_max_q becomes 255 and we iterate 0..255.
            if (e5 == 0) begin
              i_max_q <= 8'b0;
            end else begin
              i_max_q <= (n / e5) > 16'd255 ? 8'd255 : n / e5;
            end
            // i=0: curr_rem = n % d
            curr_rem <= n % d;
            best <= n % d;
            min_rubles <= n % d;
          end
        end

        CALC: begin
          // Update best and curr_rem for this iteration
          if (curr_rem < best) begin
            best <= curr_rem;
            min_rubles <= curr_rem;
          end

          // Early exit if remainder is zero
          if (curr_rem == 16'b0) begin
            // Prepare to exit next cycle
            i <= i;   // keep current i
          end else begin
            // i = i + 1 (saturate at 255)
            i <= (i == 8'd255) ? 8'd255 : (i + 1);

            // Next remainder: ((n - i*5*e) - 5*e) % d = (curr_rem - e5) % d
            if (e5 <= curr_rem) begin
              curr_rem <= curr_rem - e5;
            end else begin
              curr_rem <= curr_rem - e5 + d; // ensure non-negative mod
            end
          end
        end

        DONE: begin
          done <= 1'b0; // done is 1 cycle pulse
        end

        default: state <= IDLE;
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: next_state = start_posedge ? CALC : IDLE;
      CALC: begin
        if (curr_rem == 16'b0) begin
          next_state = DONE; // finish early
        end else if (i >= i_max_q) begin
          next_state = DONE; // last iteration reached
        end else begin
          next_state = CALC;
        end
      end
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // done is 1 cycle in DONE
  always @(*) begin
    done = (state == DONE);
  end

endmodule
