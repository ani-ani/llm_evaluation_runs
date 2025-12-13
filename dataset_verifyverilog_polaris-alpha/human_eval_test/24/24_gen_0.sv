module largest_divisor(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] n,
  output reg [7:0] divisor,
  output reg done
);

  // State encoding
  localparam IDLE  = 2'b00;
  localparam CALC  = 2'b01;
  localparam DONE  = 2'b10;

  reg [1:0] state, next_state;
  reg [7:0] check_value, next_check_value;
  reg [7:0] next_divisor;
  reg next_done;

  // Combinational next-state and output logic
  always @* begin
    // Default assignments
    next_state       = state;
    next_check_value = check_value;
    next_divisor     = divisor;
    next_done        = 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          if (n < 8'd2) begin
            next_divisor = 8'd0;
            next_state   = DONE;
          end else begin
            next_check_value = n - 8'd1;
            next_state       = CALC;
          end
        end
      end

      CALC: begin
        if (check_value <= 8'd1) begin
          // No larger divisor found; 1 is the largest proper divisor
          next_divisor = 8'd1;
          next_state   = DONE;
        end else if ((n % check_value) == 8'd0) begin
          // Found largest proper divisor
          next_divisor = check_value;
          next_state   = DONE;
        end else begin
          // Continue searching
          next_check_value = check_value - 8'd1;
        end
      end

      DONE: begin
        // Assert done for one cycle
        next_done  = 1'b1;
        // Return to IDLE; wait for next start
        next_state = IDLE;
      end

      default: begin
        next_state       = IDLE;
        next_check_value = 8'd0;
        next_divisor     = 8'd0;
        next_done        = 1'b0;
      end
    endcase
  end

  // Sequential state and registers update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      check_value  <= 8'd0;
      divisor      <= 8'd0;
      done         <= 1'b0;
    end else begin
      state        <= next_state;
      check_value  <= next_check_value;
      divisor      <= next_divisor;
      done         <= next_done;
    end
  end

endmodule