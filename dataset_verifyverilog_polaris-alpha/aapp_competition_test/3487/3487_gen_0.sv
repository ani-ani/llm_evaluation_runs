module fluid_optimizer(
  input clk,
  input rst_n,
  input start,
  input [15:0] v,
  input [15:0] a,
  input [2:0] pipe_j [0:15],
  input [2:0] pipe_k [0:15],
  input [7:0] pipe_cap [0:15],
  input [3:0] p,
  output reg [15:0] flubber_rates [0:15],
  output reg [15:0] water_rates [0:15],
  output reg [15:0] optimal_value,
  output reg done
);

  // Q8.8 helpers
  function automatic [15:0] qmul(input [15:0] x, input [15:0] y);
    reg signed [31:0] prod;
    begin
      prod = $signed(x) * $signed(y);
      qmul = prod[23:8];
    end
  endfunction

  function automatic [15:0] qdiv(input [15:0] num, input [15:0] den);
    reg signed [31:0] quot;
    begin
      if (den == 16'd0) begin
        quot = 32'sd0;
      end else begin
        quot = ($signed(num) <<< 8) / $signed(den);
      end
      qdiv = quot[15:0];
    end
  endfunction

  // clip to [0, capacity]
  function automatic [15:0] clip_rate(
    input [15:0] val,
    input [7:0] cap
  );
    reg [15:0] cap_q;
    begin
      cap_q = {cap,8'd0};
      if ($signed(val) < 0)
        clip_rate = 16'd0;
      else if (val > cap_q)
        clip_rate = cap_q;
      else
        clip_rate = val;
    end
  endfunction

  // compute objective F^a * W^(1-a);
  function automatic [15:0] pow_q(
    input [15:0] base,
    input [15:0] exp_q
  );
    // very rough approximation via repeated multiplication for small integer part
    integer i;
    reg [15:0] res;
    reg [7:0] int_exp;
    begin
      if (base <= 16'd0) begin
        pow_q = 16'd0;
      end else begin
        int_exp = exp_q[15:8];
        res = 16'h0100; // 1.0
        for (i = 0; i < 8; i = i + 1) begin
          if (i < int_exp)
            res = qmul(res, base);
        end
        pow_q = res;
      end
    end
  endfunction

  // FSM
  localparam IDLE  = 2'd0;
  localparam RUN   = 2'd1;
  localparam DONE  = 2'd2;

  reg [1:0] state;
  reg [7:0] iter_cnt; // up to 255, plus 0 = 256 iterations

  // Internal rates
  reg [15:0] F [0:15];
  reg [15:0] W [0:15];

  // Step sizes (constants in Q8.8)
  localparam [15:0] STEP_F = 16'h0010; // 0.0625
  localparam [15:0] STEP_W = 16'h0010; // 0.0625

  // Precompute 1-a
  wire [15:0] one_q = 16'h0100; // 1.0
  wire [15:0] one_minus_a = one_q - a;

  integer i;

  // combinational gradient signals
  reg [15:0] sumF;
  reg [15:0] sumW;
  reg [15:0] gradF_common;
  reg [15:0] gradW_common;

  // objective accumulation
  reg [15:0] obj_F_pow;
  reg [15:0] obj_W_pow;
  reg [15:0] obj_val;

  // recompute sums and gradients combinationally from current F,W
  always @* begin
    sumF = 16'd0;
    sumW = 16'd0;
    for (i = 0; i < 16; i = i + 1) begin
      if (i < p) begin
        sumF = sumF + F[i];
        sumW = sumW + W[i];
      end
    end

    // Avoid divide; use heuristic gradients proportional to partial derivatives sign:
    // d/dF ~ a / F , d/dW ~ (1-a)/W; approximate with 1/(sumF+eps),1/(sumW+eps)
    // Use small epsilon 0.5 (0x0080)
    begin
      reg [15:0] eps;
      eps = 16'h0080;
      gradF_common = qdiv(a, (sumF + eps));
      gradW_common = qdiv(one_minus_a, (sumW + eps));
    end

    // objective approximation at end of run
    obj_F_pow = pow_q(sumF, a);
    obj_W_pow = pow_q(sumW, one_minus_a);
    obj_val   = qmul(obj_F_pow, obj_W_pow);
  end

  // sequential updates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      iter_cnt <= 8'd0;
      done <= 1'b0;
      optimal_value <= 16'd0;
      for (i = 0; i < 16; i = i + 1) begin
        F[i] <= 16'd0;
        W[i] <= 16'd0;
        flubber_rates[i] <= 16'd0;
        water_rates[i] <= 16'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // initialize
            iter_cnt <= 8'd0;
            for (i = 0; i < 16; i = i + 1) begin
              F[i] <= 16'd0;
              W[i] <= 16'd0;
            end
            state <= RUN;
          end
        end

        RUN: begin
          // One gradient-ascent step per cycle (in parallel for all active pipes)
          for (i = 0; i < 16; i = i + 1) begin
            if (i < p) begin
              // basic unconstrained update
              reg [15:0] dF;
              reg [15:0] dW;
              reg [15:0] F_new;
              reg [15:0] W_new;
              reg [15:0] cap_q;

              dF = qmul(STEP_F, gradF_common);
              dW = qmul(STEP_W, gradW_common);

              F_new = F[i] + dF;
              W_new = W[i] + dW;

              // Enforce v*F + W <= cap and non-negative
              cap_q = {pipe_cap[i],8'd0};

              // Clip negatives
              if ($signed(F_new) < 0) F_new = 16'd0;
              if ($signed(W_new) < 0) W_new = 16'd0;

              // If constraint violated, project along line v*F+W=cap while keeping ratio
              if ($signed(qmul(v,F_new) + W_new) > $signed(cap_q)) begin
                // scale down by lambda so v*F+W == cap
                // lambda = cap / (v*F+W)
                reg [15:0] denom;
                reg [15:0] lambda;
                denom = qmul(v,F_new) + W_new;
                lambda = qdiv(cap_q, denom);
                F_new = qmul(F_new, lambda);
                W_new = qmul(W_new, lambda);
              end

              F[i] <= F_new;
              W[i] <= W_new;
            end else begin
              F[i] <= 16'd0;
              W[i] <= 16'd0;
            end
          end

          iter_cnt <= iter_cnt + 8'd1;
          if (iter_cnt == 8'd255) begin
            // After 256th iteration (0..255), latch outputs next
            state <= DONE;
          end
        end

        DONE: begin
          // capture final rates and objective
          for (i = 0; i < 16; i = i + 1) begin
            flubber_rates[i] <= F[i];
            water_rates[i]   <= W[i];
          end
          optimal_value <= obj_val;
          done <= 1'b1;
          if (!start) begin
            // wait for start to deassert, then go idle
            state <= IDLE;
            done <= 1'b0;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule