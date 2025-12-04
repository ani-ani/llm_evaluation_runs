module casino_profit_calculator(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start calculation
  input [15:0] x, // refund percentage (fixed-point: value * 100, e.g., 20.5% = 2050)
  input [15:0] p, // win probability (fixed-point: value * 100, e.g., 49.85% = 4985)
  output reg [31:0] max_profit, // Q16.16 fixed-point output (max profit * 65536)
  output reg done // high when calculation complete
);

  // Internal parameters and types
  localparam MAX_BETS = 16;
  localparam W = 32; // Q16.16
  localparam W_FRAC = 16;
  localparam S_IDLE = 2'b00;
  localparam S_CALC = 2'b01;
  localparam S_DONE = 2'b10;

  // State machine and iteration control
  reg [1:0] state;
  reg [5:0] cycle;  // up to MAX_BETS+1
  reg signed [31:0] cur;     // current value for (2*ones - N) in Q16.16
  reg signed [31:0] best;    // maximum seen so far in Q16.16
  reg [15:0] n_hold;         // N for current iteration
  reg [15:0] p_fp16;         // p in Q0.16
  reg [15:0] x_fp16;         // x in Q0.16

  // Current iteration's result
  wire signed [31:0] cur_result;
  wire signed [31:0] loss_q1616;
  wire signed [31:0] ones_compl;
  wire signed [31:0] ref_gain;
  wire signed [31:0] final_result;

  // Convert inputs: p, x in Q0.16 to Q16.16 (sign-extend to 32-bit)
  assign p_fp16 = p;
  assign x_fp16 = x;

  // Computations for this iteration (combinational)
  // ones = (# of wins) = (N + cur) / 2  -> exact in Q16.16 because N and cur are both even multiples of 1/65536
  assign ones_compl       = (n_hold + cur) >>> 1;
  // losses = N - ones = (N - cur) / 2
  assign loss_q1616       = (n_hold - cur) >>> 1;
  // loss_refunded = losses * (1 - x) = losses - losses * x
  // losses in Q16.16, x in Q0.16 -> product in Q32.32; take high 32 bits for Q16.16
  assign ref_gain         = (loss_q1616 - (($signed({1'b0, loss_q1616}) * $signed({1'b0, x_fp16})) >>> 32));
  // final_result = N - 2*loss_refunded = N - 2*ref_gain
  assign final_result     = $signed({1'b0, n_hold}) - (ref_gain <<< 1);
  // Expected value over N trials: E[2*ones - N] = N*(2*p - 1)
  assign cur_result       = $signed({1'b0, n_hold}) * ($signed({1'b0, p_fp16}) - 32'sh00010000);

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      done       <= 1'b0;
      cycle      <= 6'd0;
      cur        <= 32'sh00000000;
      best       <= 32'sh80000000; // very small
      n_hold     <= 16'd0;
      max_profit <= 32'd0;
      p_fp16     <= 16'd0;
      x_fp16     <= 16'd0;
    end else begin
      case (state)
        S_IDLE: begin
          if (start) begin
            // Latch inputs, initialize accumulator and best
            p_fp16     <= p;
            x_fp16     <= x;
            n_hold     <= 16'd0;
            cur        <= 32'sh00000000;     // ones=0 => cur=(0*2 - 0)=0
            best       <= cur_result;        // N=0 -> 0
            cycle      <= 6'd1;              // next cycle will compute N=1
            state      <= S_CALC;
            done       <= 1'b0;
          end else begin
            state      <= S_IDLE;
            done       <= 1'b0;
            cycle      <= 6'd0;
            cur        <= 32'sh00000000;
            best       <= 32'sh80000000;
            n_hold     <= 16'd0;
            p_fp16     <= p_fp16;
            x_fp16     <= x_fp16;
          end
        end

        S_CALC: begin
          // Update cur to next N using the recurrence:
          // cur_next = cur * p_fp16 - (1 - p_fp16) * (ones - losses)
          // ones - losses = N - 2*losses = cur
          // cur_next = cur * p_fp16 - (1 - p_fp16) * cur = cur * (2*p - 1)
          cur <= cur * $signed({1'b0, p_fp16}) - (cur * ($signed({1'b0, 16'h00010000}) - $signed({1'b0, p_fp16})));
          n_hold <= cycle;
          best   <= (cur_result > best) ? cur_result : best;
          cycle  <= cycle + 1;
          if (cycle == MAX_BETS) begin
            state <= S_DONE;
            done  <= 1'b1;
            max_profit <= best;
          end else begin
            state <= S_CALC;
            done  <= 1'b0;
          end
        end

        S_DONE: begin
          // Hold outputs until start is deasserted, then return to IDLE
          max_profit <= best;
          done       <= 1'b1;
          if (start) begin
            state <= S_DONE;
            cycle <= MAX_BETS; // keep cycle stable in done state
          end else begin
            state <= S_IDLE;
            cycle <= 6'd0;
          end
        end

        default: begin
          state      <= S_IDLE;
          done       <= 1'b0;
          cycle      <= 6'd0;
          cur        <= 32'sh00000000;
          best       <= 32'sh80000000;
          n_hold     <= 16'd0;
          p_fp16     <= 16'd0;
          x_fp16     <= 16'd0;
          max_profit <= 32'd0;
        end
      endcase
    end
  end

endmodule
