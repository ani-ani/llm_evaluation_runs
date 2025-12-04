module lemonade_trader (
  input clk,
  input rst_n,
  input start,
  input [3:0] color_ids [0:7], // array of 4-bit color IDs (0:pink, 1:blue, others)
  input [31:0] rates [0:7],     // exchange rates in Q16.16 fixed-point format (16.16 bits)
  input [2:0] num_children,     // number of trades (0-8)

  output reg [31:0] max_blue_q16, // max blue lemonade in Q16.16 format
  output reg done                  // high when computation complete
);

  // Internal state
  reg started_q;
  reg [2:0] n_trades_q;
  reg [31:0] best_q;

  // Q16.16 constants
  localparam [31:0] ONE_LITER   = 32'h00010000; // 1.0 in Q16.16
  localparam [31:0] CAP_LITERS  = 32'h000A0000; // 10.0 in Q16.16
  localparam [31:0] MAX_Q16     = 32'h7FFFFFFF; // Max positive signed 32-bit
  localparam int     MAX_STEPS  = 8;

  function [31:0] mult_q16 (input [31:0] a, input [31:0] b);
    // a and b are Q16.16 (signed). Result is Q16.16.
    // Multiply 32-bit x 32-bit -> 64-bit then round to 32-bit by taking upper 32 bits.
    mult_q16 = $signed({1'b0, a}) * $signed({1'b0, b});
    mult_q16 = mult_q16[47:16];
  endfunction

  function [31:0] max_q16 (input [31:0] a, input [31:0] b);
    if ($signed(a) >= $signed(b)) max_q16 = a;
    else max_q16 = b;
  endfunction

  function [31:0] cap_q16 (input [31:0] v);
    if ($signed(v) > $signed(CAP_LITERS)) cap_q16 = CAP_LITERS;
    else cap_q16 = v;
  endfunction

  always_comb begin
    // Default outputs when not started
    if (!started_q) begin
      max_blue_q16 = 32'h0;
      done = 1'b0;
    end else begin
      // One-shot combinatorial evaluation within 256 cycles guarantee
      // Iterate all trade sequences up to MAX_STEPS or n_trades_q steps
      int s, i, j;
      reg [3:0] cur_color;
      reg [31:0] cur_amount;
      reg [31:0] best_sofar;
      reg [31:0] tmp_amount;
      reg [31:0] trade_amount;
      reg [3:0] next_color;
      reg [31:0] new_best;
      reg [31:0] temp_best;
      reg [31:0] candidate;
      reg [3:0] candidate_color;

      // Start from 1.0 litre pink
      best_sofar = 32'h0; // best across all colors in the path
      cur_color  = 4'd0;  // 0: pink
      cur_amount = ONE_LITER;
      new_best   = 32'h0;

      for (s = 0; s < MAX_STEPS; s++) begin
        // new_best per step
        new_best = cur_amount; // amount at current node

        // Evaluate all trades at this node
        temp_best = cur_amount;
        candidate_color = cur_color;

        for (i = 0; i < MAX_STEPS; i++) begin
          if (i < n_trades_q) begin
            // Use this child's trade if source matches current color
            if (cur_color == color_ids[i][3:0]) begin
              trade_amount = mult_q16(cur_amount, rates[i]);
              next_color   = color_ids[i][3:0] + 4'd1; // opposite end of the link

              // Maintain best so far across this step's nodes
              if ($signed(trade_amount) > $signed(temp_best)) begin
                temp_best = trade_amount;
                candidate_color = next_color;
              end
            end
          end
        end

        // Update per-step best and new node state for next iteration
        if ($signed(temp_best) > $signed(new_best)) begin
          new_best = temp_best;
        end
        cur_amount = temp_best;   // amount after possibly applying a trade this step
        cur_color  = candidate_color;
        best_sofar = new_best;    // best seen up to this step
      end

      // Cap to 10.0 litres and set outputs
      max_blue_q16 = cap_q16(best_sofar);
      done = 1'b1;
    end
  end

  // Sequential control of start and num_children snapshot
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      started_q  <= 1'b0;
      n_trades_q <= 3'd0;
      best_q     <= 32'h0;
    end else begin
      if (start) begin
        started_q  <= 1'b1;
        n_trades_q <= num_children;
        best_q     <= 32'h0; // not used combinatorially; kept for potential future use
      end
      // held state persists until next reset/start
    end
  end

endmodule
