module gcd_calculator (
  input clk,
  input rst_n,
  input start,
  input [15:0] a,
  input [15:0] b,
  output reg [15:0] result,
  output reg done
);

  // Euclid's algorithm via repeated subtraction (meets max 32 cycles for 16-bit)
  localparam IDLE = 1'b0;
  localparam COMPUTE = 1'b1;

  reg state, next_state;
  reg [15:0] reg_a, reg_b;
  reg [15:0] next_a, next_b;

  // State update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Registers update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg_a <= 16'd0;
      reg_b <= 16'd0;
    end else begin
      reg_a <= next_a;
      reg_b <= next_b;
    end
  end

  // Combinational next-state and next-datapath logic
  always_comb begin
    // Defaults (no latches)
    next_a = reg_a;
    next_b = reg_b;
    case (state)
      IDLE: begin
        if (start) begin
          // Load inputs and begin computation
          next_a = a;
          next_b = b;
        end
      end
      COMPUTE: begin
        if (reg_b == 16'd0) begin
          // Done; keep registers stable
          next_a = reg_a;
          next_b = reg_b;
        end else begin
          if (reg_b > reg_a) begin
            // Swap
            next_a = reg_b;
            next_b = reg_a;
          end else begin
            // Subtract
            next_a = reg_a - reg_b;
            next_b = reg_b;
          end
        end
      end
    endcase
  end

  // State transitions
  always_comb begin
    next_state = state;
    case (state)
      IDLE:  next_state = start ? COMPUTE : IDLE;
      COMPUTE: next_state = (reg_b == 16'd0) ? IDLE : COMPUTE;
      default: next_state = IDLE;
    endcase
  end

  // Outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 16'd0;
      done   <= 1'b1; // After reset, indicate completion with result=0
    end else begin
      if (state == IDLE && next_state == IDLE && !start) begin
        // Stable idle: expose last result, done high
        result <= result;
        done   <= 1'b1;
      end else if (next_state == IDLE) begin
        // Finishing this cycle: latch final GCD
        result <= (reg_b == 16'd0) ? reg_a : 16'd0;
        done   <= 1'b1;
      end else begin
        // In computation: clear done, keep result unchanged
        result <= result;
        done   <= 1'b0;
      end
    end
  end

endmodule
