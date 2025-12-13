module aesthetic_path_colors(
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [7:0] result,
  output reg done
);

  // State encoding
  localparam IDLE         = 2'b00;
  localparam FIND_DIVISOR = 2'b01;
  localparam CHECK_POW    = 2'b10;
  localparam DONE         = 2'b11;

  reg [1:0] state, next_state;

  reg [7:0] n_reg;          // Latched input n
  reg [7:0] divisor;        // Current divisor candidate
  reg [7:0] smallest_div;   // Found smallest divisor
  reg [7:0] temp_n;         // For repeated division
  reg       has_divisor;    // Indicates a divisor was found
  reg       power_ok;       // Indicates n is power of smallest_div

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      n_reg         <= 8'd0;
      divisor       <= 8'd0;
      smallest_div  <= 8'd0;
      temp_n        <= 8'd0;
      has_divisor   <= 1'b0;
      power_ok      <= 1'b0;
      result        <= 8'd0;
      done          <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            n_reg        <= n;
            divisor      <= 8'd2;
            smallest_div <= 8'd0;
            temp_n       <= 8'd0;
            has_divisor  <= 1'b0;
            power_ok     <= 1'b0;
            done         <= 1'b0;
            result       <= 8'd0;
          end else begin
            // Hold result/done until next start
            done <= done;
            result <= result;
          end
        end

        FIND_DIVISOR: begin
          // Only search if no divisor found yet and divisor^2 <= n_reg
          if (!has_divisor) begin
            if ((divisor * divisor) > n_reg) begin
              // No divisor found, n is prime
              has_divisor  <= 1'b0;
              smallest_div <= 8'd0;
            end else if (n_reg % divisor == 8'd0) begin
              has_divisor  <= 1'b1;
              smallest_div <= divisor;
              temp_n       <= n_reg / divisor;
              power_ok     <= 1'b1; // assume ok until disproved
            end else begin
              divisor <= divisor + 8'd1;
            end
          end
        end

        CHECK_POW: begin
          // Verify n_reg is a pure power of smallest_div
          if (temp_n == 8'd1) begin
            // Exactly power
            power_ok <= power_ok;
          end else if (temp_n % smallest_div != 8'd0) begin
            power_ok <= 1'b0;
          end else begin
            temp_n <= temp_n / smallest_div;
          end
        end

        DONE: begin
          done   <= 1'b1;
          result <= result;
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state logic and result generation
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start) begin
          if (n == 8'd1) begin
            // Directly handle n=1
            next_state = DONE;
          end else begin
            next_state = FIND_DIVISOR;
          end
        end
      end

      FIND_DIVISOR: begin
        if (!has_divisor) begin
          if ((divisor * divisor) > n_reg) begin
            // No divisor found => n is prime
            next_state = DONE;
          end else begin
            // Continue searching in this state
            next_state = FIND_DIVISOR;
          end
        end else begin
          // Have smallest_div, proceed to power check
          next_state = CHECK_POW;
        end
      end

      CHECK_POW: begin
        if (!power_ok) begin
          // Early exit: not a pure power
          next_state = DONE;
        end else if (temp_n == 8'd1) begin
          // Confirmed power
          next_state = DONE;
        end else begin
          // Continue dividing
          next_state = CHECK_POW;
        end
      end

      DONE: begin
        // Done holds until next start
        if (start) begin
          next_state = IDLE;
        end else begin
          next_state = DONE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Combinational result selection (based on final conditions)
  always @(*) begin
    // Default: hold previous result unless overridden
    reg [7:0] res_next;
    res_next = result;

    case (state)
      IDLE: begin
        if (start) begin
          if (n == 8'd1)
            res_next = 8'd1;
          else
            res_next = 8'd0;
        end
      end

      FIND_DIVISOR: begin
        if (!has_divisor && (divisor * divisor) > n_reg) begin
          // n is prime: per spec, result = n
          res_next = n_reg;
        end else if (has_divisor) begin
          // Not final yet; result decided after CHECK_POW
          res_next = res_next;
        end
      end

      CHECK_POW: begin
        if (!power_ok) begin
          // Not a pure power => per spec, result = 1
          res_next = 8'd1;
        end else if (temp_n == 8'd1) begin
          // Pure power => result = smallest_div
          res_next = smallest_div;
        end
      end

      DONE: begin
        // Hold
        res_next = result;
      end

      default: begin
        res_next = res_next;
      end
    endcase

    // Drive to output register via continuous assignment style
    // (captured in sequential always block through result <= result; DONE state)
  end

endmodule