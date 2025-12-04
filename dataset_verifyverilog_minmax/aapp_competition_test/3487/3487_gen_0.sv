module fluid_optimizer(
  input clk,
  input rst_n,
  input start,                // Start computation
  input [15:0] v,             // Viscosity in Q8.8
  input [15:0] a,             // Alpha in Q8.8
  input [2:0] pipe_j [0:15],  // Pipe start nodes (8 pipes max)
  input [2:0] pipe_k [0:15],  // Pipe end nodes
  input [7:0] pipe_cap [0:15],// Pipe capacities (water units)
  input [3:0] p,              // Actual pipe count (1-8)
  output reg [15:0] flubber_rates [0:15], // Q8.8 Flubber rates
  output reg [15:0] water_rates [0:15],   // Q8.8 Water rates
  output reg [15:0] optimal_value,       // Maximized value Q8.8
  output reg done            // Computation complete
);

  // Internal state
  reg [7:0] iter_cnt;              // 0..255
  reg running;

  // Gradients and per-iteration variables
  reg [15:0] gradF, gradW;         // Q8.8
  reg [15:0] water_out_sum;        // Q8.8, sum of water leaving sources (pipe_k == 3)
  reg [15:0] temp_sum;             // Q8.8
  reg [15:0] next_F, next_W;       // Q8.8
  integer i;

  // Q8.8 multiply with saturation to 16-bit (1.8.8)
  function [15:0] fixed_mul;
    input [15:0] a;
    input [15:0] b;
    reg [31:0] prod;
    begin
      prod = $signed({1'b0, a}) * $signed({1'b0, b}); // 16x16 -> 32
      // Keep top 16 bits, round nearest (ties away from zero)
      fixed_mul = prod[31:16] + (prod[15] ? 1 : 0);
    end
  endfunction

  // Saturate to Q8.8 16-bit range [-128.0, 127.996...]
  function [15:0] sat16;
    input [31:0] x;
    begin
      if (x > 16'h7FFF) sat16 = 16'h7FFF;
      else if (x < 16'h8000) sat16 = 16'h8000;
      else sat16 = x[15:0];
    end
  endfunction

  // Update step: compute gradients and update flows for the current iteration
  always @(*) begin
    // Defaults to prevent latches
    water_out_sum = 16'h0;
    gradF = 16'h0;
    gradW = 16'h0;

    // Sum water flows exiting pipe_k==3 to compute W = sum of flubber at FD
    for (i = 0; i < 16; i = i + 1) begin
      if (i < p) begin
        if (pipe_k[i] == 3) begin
          water_out_sum = water_out_sum + flubber_rates[i];
        end
      end
    end

    // Gradients for one flubber-water pair in U-shaped path: (1 -> j), (j -> 3), (3 -> k), (k -> 2)
    // L = a*F*log(F) + (1-a)*W*log(W) - sum_m lam_m[(v_m*F + W) - cap_m] - mu*(F - W)
    // dL/dF:  a*(log(F) + 1) - v^T*F - mu
    // dL/dW:  (1-a)*(log(W) + 1) - 1^T*W + mu
    temp_sum = 16'h0;
    for (i = 0; i < 16; i = i + 1) begin
      if (i < p) begin
        if (pipe_j[i] == 1) begin
          temp_sum = temp_sum + v; // Q8.8 + Q8.8 = Q8.8
        end
      end
    end
    // gradF = a*(1 + log(F)) - v_sum
    gradF = fixed_mul(a, $clog2(flubber_rates[0]) + 16'h0100) - temp_sum; // log2 approximation
    // gradW = (1-a)*(1 + log(W)) - ones_sum + ones_sum (cancels) -> (1-a)*(1 + log(W))
    gradW = fixed_mul((16'h0100 - a), $clog2(water_out_sum) + 16'h0100); // log2 approximation

    // Update flows
    // next_F = F - lr * gradF  (gradient ascent on -L)
    // next_W = W - lr * gradW  (fixed point learning rate lr = 0.5 in Q8.8 = 16'h0080)
    next_F = flubber_rates[0] - fixed_mul(16'h0080, gradF);
    next_W = water_out_sum - fixed_mul(16'h0080, gradW);

    // Capacity projection: ensure v*F + W <= cap for all relevant pipes
    for (i = 0; i < 16; i = i + 1) begin
      if (i < p) begin
        if (pipe_j[i] == 1) begin
          // Saturated projected update for this pipe
          // (W <= cap - v*F)
          next_W = sat16($signed(pipe_cap[i] << 8) - fixed_mul(v, next_F));
        end
      end
    end
  end

  // Sequential behavior
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 16; i = i + 1) begin
        flubber_rates[i] <= 16'h0;
        water_rates[i]   <= 16'h0;
      end
      optimal_value <= 16'h0;
      iter_cnt      <= 8'h0;
      done          <= 1'b0;
      running       <= 1'b0;
    end else begin
      if (start) begin
        for (i = 0; i < 16; i = i + 1) begin
          flubber_rates[i] <= 16'h0;
          water_rates[i]   <= 16'h0;
        end
        optimal_value <= 16'h0;
        iter_cnt      <= 8'h0;
        done          <= 1'b0;
        running       <= 1'b1;
      end else if (running) begin
        if (iter_cnt < 8'hFF) begin
          // Apply updates for the single active path
          flubber_rates[0] <= sat16(next_F);
          water_rates[0]   <= sat16(next_W);
          iter_cnt <= iter_cnt + 1;
        end else begin
          // Final projection and outputs
          for (i = 0; i < 16; i = i + 1) begin
            if (i < p) begin
              if (pipe_j[i] == 1) begin
                flubber_rates[i] <= sat16(flubber_rates[0]);
                water_rates[i]   <= sat16(next_W);
              end else begin
                flubber_rates[i] <= 16'h0;
                water_rates[i]   <= 16'h0;
              end
            end else begin
              flubber_rates[i] <= 16'h0;
              water_rates[i]   <= 16'h0;
            end
          end
          // Optimal value at FD (sum of water flows into node 3)
          optimal_value <= sat16(next_W);
          done          <= 1'b1;
          running       <= 1'b0;
        end
      end
    end
  end

endmodule