module painting_purchases(
  input clk,
  input rst_n,
  input start,
  input [1:0] client_sel,
  input [7:0] a_i,
  input [7:0] b_i,
  input [3:0] C_param,
  output reg [15:0] result,
  output reg done
);

  // Parameter
  localparam MOD = 16'd10007;

  // Client parameter storage
  reg [7:0] a[0:3];
  reg [7:0] b[0:3];

  // FSM states
  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_LOAD  = 2'b01,
    S_CALC  = 2'b10,
    S_DONE  = 2'b11
  } state_t;

  state_t state, next_state;

  // Cycle counter to manage timing (support up to 20 cycles for N=4,C=4)
  reg [4:0] cycle_cnt;

  // Subset index (0..15)
  reg [3:0] subset_idx;

  // Accumulator for result (mod 10007)
  reg [15:0] acc;

  // Latched C parameter
  reg [3:0] C_reg;

  // Control: start edge detect to enter LOAD deterministically
  reg start_d;
  wire start_rise = (start && !start_d);

  // Combinational signals for subset processing
  reg [2:0] subset_size;
  reg [15:0] contrib;
  reg [15:0] prod;

  // Start edge FF
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= start;
  end

  // FSM state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= S_IDLE;
    else
      state <= next_state;
  end

  // FSM next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start_rise)
          next_state = S_LOAD;
      end
      S_LOAD: begin
        // Loading is controlled externally via client_sel and start window.
        // Transition to CALC when start is deasserted after at least one load.
        if (!start)
          next_state = S_CALC;
      end
      S_CALC: begin
        // We process all 16 subsets in 16 cycles
        if (subset_idx == 4'd15)
          next_state = S_DONE;
      end
      S_DONE: begin
        // Stay in DONE until a new start edge
        if (start_rise)
          next_state = S_LOAD;
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Parameter loading and control registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a[0] <= 8'd0; a[1] <= 8'd0; a[2] <= 8'd0; a[3] <= 8'd0;
      b[0] <= 8'd0; b[1] <= 8'd0; b[2] <= 8'd0; b[3] <= 8'd0;
      C_reg <= 4'd0;
      subset_idx <= 4'd0;
      acc <= 16'd0;
      result <= 16'd0;
      done <= 1'b0;
      cycle_cnt <= 5'd0;
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          subset_idx <= 4'd0;
          acc <= 16'd0;
          cycle_cnt <= 5'd0;
          if (start_rise) begin
            // latch C_param at start of new operation
            C_reg <= C_param;
          end
        end

        S_LOAD: begin
          done <= 1'b0;
          cycle_cnt <= cycle_cnt + 5'd1;
          // Load selected client parameters while start is asserted
          // External environment provides 4 cycles (client_sel=0..3)
          a[client_sel] <= a_i;
          b[client_sel] <= b_i;
          // Keep acc and subset_idx cleared during load
          acc <= 16'd0;
          subset_idx <= 4'd0;
        end

        S_CALC: begin
          done <= 1'b0;
          cycle_cnt <= cycle_cnt + 5'd1;

          // Add contribution of current subset (combinational contrib)
          acc <= (acc + contrib);

          // Advance subset index
          if (subset_idx != 4'd15)
            subset_idx <= subset_idx + 4'd1;
        end

        S_DONE: begin
          // Final result is acc after last subset
          done <= 1'b1;
          result <= acc % MOD;
          cycle_cnt <= cycle_cnt; // hold
          subset_idx <= subset_idx;
        end

        default: begin
          // Should not occur
          done <= 1'b0;
        end
      endcase
    end
  end

  // Combinational subset evaluation
  // For subset_idx, bit i=1 => client i chooses colored; bit i=0 => B&W
  always @(*) begin
    // Compute subset size
    subset_size = subset_idx[0] + subset_idx[1] + subset_idx[2] + subset_idx[3];

    // Default
    prod = 16'd1;

    // Only valid if subset_size >= C_reg and C_reg>=1
    if ((subset_size >= C_reg) && (C_reg != 4'd0)) begin
      // Client 0
      if (subset_idx[0])
        prod = prod * (a[0] + 16'd1);
      else
        prod = prod * (b[0] + 16'd1);
      // Client 1
      if (subset_idx[1])
        prod = (prod * (a[1] + 16'd1));
      else
        prod = (prod * (b[1] + 16'd1));
      // Client 2
      if (subset_idx[2])
        prod = (prod * (a[2] + 16'd1));
      else
        prod = (prod * (b[2] + 16'd1));
      // Client 3
      if (subset_idx[3])
        prod = (prod * (a[3] + 16'd1));
      else
        prod = (prod * (b[3] + 16'd1));

      // Modulo reduction (combinational)
      contrib = prod % MOD;
    end else begin
      contrib = 16'd0;
    end
  end

endmodule