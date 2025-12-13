module jacobsthal_calculator(
  input  clk,
  input  rst_n,
  input  start,
  input  [3:0] n,
  output reg [15:0] result,
  output reg done
);

  // FSM states
  localparam IDLE = 2'b00;
  localparam CALC = 2'b01;

  reg [1:0]  state, next_state;
  reg [3:0]  count, next_count;      // iteration counter i
  reg [15:0] j_prev, next_j_prev;   // J(i-1)
  reg [15:0] j_prev2, next_j_prev2; // J(i-2)
  reg [15:0] next_result;
  reg        next_done;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      count    <= 4'd0;
      j_prev   <= 16'd0;
      j_prev2  <= 16'd0;
      result   <= 16'd0;
      done     <= 1'b0;
    end else begin
      state    <= next_state;
      count    <= next_count;
      j_prev   <= next_j_prev;
      j_prev2  <= next_j_prev2;
      result   <= next_result;
      done     <= next_done;
    end
  end

  // Combinational next-state logic
  always @* begin
    // Defaults
    next_state   = state;
    next_count   = count;
    next_j_prev  = j_prev;
    next_j_prev2 = j_prev2;
    next_result  = result;
    next_done    = 1'b0; // done is a one-cycle pulse

    case (state)
      IDLE: begin
        if (start) begin
          // Handle base cases and initialization
          if (n == 4'd0) begin
            next_result = 16'd0;
            next_done   = 1'b1;
            next_state  = IDLE; // result ready in this cycle
          end else if (n == 4'd1) begin
            next_result = 16'd1;
            next_done   = 1'b1;
            next_state  = IDLE;
          end else begin
            // n >= 2: initialize for iterative computation
            // J(0)=0, J(1)=1
            next_j_prev2 = 16'd0; // J(0)
            next_j_prev  = 16'd1; // J(1)
            next_count   = 4'd2; // start from i=2
            next_state   = CALC;
          end
        end
      end

      CALC: begin
        // Compute J(i) = J(i-1) + 2*J(i-2)
        // Use current j_prev (J(i-1)) and j_prev2 (J(i-2))
        // Then shift for next iteration
        // temp = j_prev + (j_prev2 << 1)
        // next_j_prev2 = j_prev;
        // next_j_prev  = temp;

        // Calculate next Jacobsthal value
        // Use a temporary wire via implicit combinational expression
        // to avoid extra regs: directly assign into next_j_prev
        begin
          reg [15:0] temp;
          temp = j_prev + (j_prev2 << 1);
          next_j_prev2 = j_prev;
          next_j_prev  = temp;

          if (count == n) begin
            // Completed: temp holds J(n)
            next_result = temp;
            next_done   = 1'b1;
            next_state  = IDLE;
          end else begin
            // Continue iterations
            next_count = count + 4'd1;
            next_state = CALC;
          end
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule