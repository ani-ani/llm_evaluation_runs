module diophantine_solver(
  input clk,
  input rst_n,
  input start,
  input [7:0] a,
  input [7:0] b,
  input [7:0] n,
  output reg [7:0] x,
  output reg [7:0] y,
  output reg valid,
  output reg done
);

  // States
  localparam IDLE      = 3'b000;
  localparam CHECK     = 3'b001;
  localparam CALC      = 3'b010;
  localparam FOUND     = 3'b011;
  localparam NOT_FOUND = 3'b100;

  reg [2:0] state;
  reg [2:0] next_state;

  // Internal Registers
  reg [7:0] x_cnt;
  reg [15:0] mul_reg;
  reg [15:0] remainder_reg;
  reg [7:0] y_reg;

  // Next State Logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start)
          next_state = CHECK;
        else
          next_state = IDLE;
      end
      CHECK: begin
        if (x_cnt > 15)
          next_state = NOT_FOUND;
        else if (mul_reg <= n) 
          next_state = CALC;
        else
          next_state = NOT_FOUND;
      end
      CALC: begin
        if (remainder_reg[15]) begin
          // remainder < 0 (negative flag)
          next_state = NOT_FOUND;
        end else begin
          // Check divisibility: remainder % b == 0
          // remainder_reg is guaranteed non-negative here
          if (remainder_reg[7:0] % b == 0) begin
            next_state = FOUND;
          end else begin
            next_state = CHECK;
          end
        end
      end
      FOUND: begin
        next_state = IDLE;
      end
      NOT_FOUND: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // State Register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Output and Data Path Logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x <= 8'b0;
      y <= 8'b0;
      valid <= 1'b0;
      done <= 1'b0;
      x_cnt <= 8'b0;
      mul_reg <= 16'b0;
      remainder_reg <= 16'b0;
      y_reg <= 8'b0;
    end else begin
      case (state)
        IDLE: begin
          valid <= 1'b0;
          done <= 1'b0;
          if (start) begin
            x_cnt <= 8'b0;
            mul_reg <= 16'b0; // 0 * a = 0
          end
        end
        CHECK: begin
          // If continuing search, increment x and calculate next mul
          if (state != next_state && next_state == CHECK) begin
            x_cnt <= x_cnt + 1;
            mul_reg <= (x_cnt + 1) * a;
          end else if (state != next_state && next_state == CALC) begin
            // Check passed, stay on current x_cnt, mul_reg already calculated in previous cycle or setup in IDLE
            // Actually, to avoid glitch, calculate mul_reg if we just entered CHECK from IDLE or CALC
            if (x_cnt == 0 && mul_reg == 0) begin
               mul_reg <= x_cnt * a;
            end
          end
        end
        CALC: begin
          remainder_reg <= n - mul_reg;
          if (remainder_reg[15]) begin
             // Do nothing, go to NOT_FOUND
          end else begin
            // Check divisibility logic happens in combinational next_state logic
            // If valid, we might want to store y result early if we stay in CALC, 
            // but we need to wait for next_state decision.
            // If found, we calculate y here or in FOUND state.
            if (remainder_reg[7:0] % b == 0) begin
              y_reg <= remainder_reg[7:0] / b;
            end
          end
          // Prepare for next iteration if needed (Moores machine logic usually handles this in transition, 
          // but explicit path update helps)
          if (next_state == CHECK) begin
            x_cnt <= x_cnt + 1;
            mul_reg <= (x_cnt + 1) * a;
          end
        end
        FOUND: begin
          x <= x_cnt;
          y <= y_reg;
          valid <= 1'b1;
          done <= 1'b1;
        end
        NOT_FOUND: begin
          x <= 8'b0;
          y <= 8'b0;
          valid <= 1'b0;
          done <= 1'b1;
        end
      endcase
      
      // Continuous updates for combinational paths that need to persist
      // In CHECK state (from IDLE or CALC), if we are just starting or iterating, ensure mul is ready
      if (state == CHECK && (next_state == CALC || next_state == NOT_FOUND)) begin
         // If we entered CHECK from IDLE (start), x_cnt is 0. mul_reg might be 0 or need update.
         // If we entered CHECK from CALC (increment), x_cnt was updated in CALC.
         // We need mul_reg to be (x_cnt * a) for the decision.
         // Optimization: Calculate mul_reg continuously based on x_cnt if needed, 
         // or strictly in the state transitions.
         // Let's rely on the explicit updates in CALC and IDLE, and fix CHECK input.
         // In CHECK, we need to compare (x_cnt * a) <= n.
         // We will compute mul_reg in the clock cycle BEFORE entering CALC if possible, 
         // or compute it inside CHECK.
         
         // Let's modify: Calculate mul_reg inside the state logic always or make it combinational.
         // To save registers, we can just compute mul_reg in the state logic.
         // However, the prompt asked for a register for mul_reg.
         // Let's fix the logic: 
         mul_reg <= x_cnt * a;
      end
    end
  end

endmodule