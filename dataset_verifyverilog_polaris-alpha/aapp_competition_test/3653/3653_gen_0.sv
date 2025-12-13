module dog_chain_calculator(
  input clk,
  input rst_n,
  input start,
  input [11:0] L,
  output reg [7:0] chain_length,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE    = 3'd0,
    COMPUTE = 3'd1,
    DIVIDE  = 3'd2,
    SQRT    = 3'd3,
    DONE    = 3'd4
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [23:0] temp;           // temp = L * 226 (12b * 8b => up to 20b, use 24b for margin)
  reg [15:0] quotient;       // to hold division result
  reg [15:0] quotient_adj;   // adjusted for ceil
  reg [7:0]  r;              // current sqrt candidate
  reg [7:0]  next_r;
  reg        rem_nonzero;    // remainder flag from division
  reg [3:0]  cycle_cnt;      // simple cycle counter (for approx timing control)

  // Combinational next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = COMPUTE;
      end
      COMPUTE: begin
        // Move to DIVIDE next cycle after computing temp
        next_state = DIVIDE;
      end
      DIVIDE: begin
        // Move to SQRT after division & ceil adjustment
        next_state = SQRT;
      end
      SQRT: begin
        // Continue SQRT until condition met, then go DONE
        if ((r * r) >= quotient_adj)
          next_state = DONE;
        else
          next_state = SQRT;
      end
      DONE: begin
        // Done is asserted for 1 cycle, then back to IDLE
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state         <= IDLE;
      temp          <= 24'd0;
      quotient      <= 16'd0;
      quotient_adj  <= 16'd0;
      rem_nonzero   <= 1'b0;
      r             <= 8'd0;
      chain_length  <= 8'd0;
      done          <= 1'b0;
      cycle_cnt     <= 4'd0;
    end else begin
      state <= next_state;
      done  <= 1'b0; // default, only set high in DONE state

      case (state)
        IDLE: begin
          cycle_cnt <= 4'd0;
          if (start) begin
            // L is captured implicitly via temp calculation next state
          end
        end

        COMPUTE: begin
          // temp = L * 226 (2L * 113)
          temp      <= L * 12'd226;
          cycle_cnt <= cycle_cnt + 4'd1;
        end

        DIVIDE: begin
          // Perform division by 355 and record remainder
          // Simple combinational divide; suitable for small widths.
          quotient    <= temp / 16'd355;
          rem_nonzero <= (temp % 16'd355) != 16'd0;

          // Apply ceiling: if remainder non-zero, increment quotient
          if ((temp % 16'd355) != 16'd0)
            quotient_adj <= (temp / 16'd355) + 16'd1;
          else
            quotient_adj <= (temp / 16'd355);

          cycle_cnt <= cycle_cnt + 4'd1;
        end

        SQRT: begin
          // Incrementally search for smallest r such that r*r >= quotient_adj
          if (cycle_cnt == 4'd0) begin
            r <= 8'd0;
          end else begin
            if ((r * r) < quotient_adj)
              r <= r + 8'd1;
          end
          cycle_cnt <= cycle_cnt + 4'd1;
        end

        DONE: begin
          // Latch final r as chain_length, assert done for 1 cycle
          chain_length <= r;
          done         <= 1'b1;
          cycle_cnt    <= 4'd0;
        end

        default: begin
          // No-op
        end
      endcase
    end
  end

endmodule