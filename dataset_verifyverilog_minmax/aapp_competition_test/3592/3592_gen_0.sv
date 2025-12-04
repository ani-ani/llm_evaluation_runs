module pita_pizza_calculator(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start calculation
  input [13:0] total_profit, // in cents (0-10000 = $0-$100.00)
  input [9:0] pita_profit, // profit per pita in cents (1-1000 = $0.01-$10.00)
  input [9:0] pizza_profit, // profit per pizza in cents (1-1000)
  output reg [6:0] pita_count, // number of pitas (0-100)
  output reg [6:0] pizza_count, // number of pizzas (0-100)
  output reg valid, // high when values are output valid
  output reg done // high when calculation complete
);

  // State encoding
  localparam IDLE  = 2'b00;
  localparam COUNT = 2'b01;
  localparam DONE  = 2'b10;

  reg [1:0] state, state_n;
  reg [6:0] cnt, cnt_n; // 0..100
  reg [13:0] profit_n;
  reg [9:0] pita_p_n, pizza_p_n;

  // Registered output pipeline (result found in same cycle as comparator, output next cycle)
  reg [6:0] out_pita_r, out_pita_n;
  reg [6:0] out_pizza_r, out_pizza_n;
  reg out_valid_n;

  // Next-state logic with registered outputs
  always @(*) begin
    // default holds
    state_n     = state;
    cnt_n       = cnt;
    profit_n    = total_profit;
    pita_p_n    = pita_profit;
    pizza_p_n   = pizza_profit;

    out_pita_n  = out_pita_r;
    out_pizza_n = out_pizza_r;
    out_valid_n = 1'b0;

    case (state)
      IDLE: begin
        // Hold outputs at reset/idle values
        out_pita_n  = 7'd0;
        out_pizza_n = 7'd0;
        out_valid_n = 1'b0;
        cnt_n       = 7'd0;
        if (start) begin
          state_n     = COUNT;
          profit_n    = total_profit;
          pita_p_n    = pita_profit;
          pizza_p_n   = pizza_profit;
        end
      end

      COUNT: begin
        // Compute potential result for current cnt in same cycle
        profit_n  = total_profit;
        pita_p_n  = pita_profit;
        pizza_p_n = pizza_profit;
        cnt_n     = cnt;

        // temp = total_profit - cnt * pita_profit
        if (cnt * pita_profit <= profit_n) begin
          if (profit_n % pizza_p_n == 0) begin
            if ((profit_n / pizza_p_n) <= 7'd100) begin
              out_pita_n  = cnt;
              out_pizza_n = profit_n / pizza_p_n;
              out_valid_n = 1'b1;
            end
          end
        end

        // advance to next pita count or finish
        if (cnt == 7'd100) begin
          state_n = DONE;
        end else begin
          cnt_n = cnt + 1'b1;
        end
      end

      DONE: begin
        // hold final outputs (valid=0 during DONE state)
        out_pita_n  = 7'd0;
        out_pizza_n = 7'd0;
        out_valid_n = 1'b0;
        cnt_n       = 7'd0;
        if (start) begin
          state_n     = COUNT;
          profit_n    = total_profit;
          pita_p_n    = pita_profit;
          pizza_p_n   = pizza_profit;
        end
      end

      default: begin
        state_n = IDLE;
      end
    endcase
  end

  // State and output registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      cnt          <= 7'd0;
      out_pita_r   <= 7'd0;
      out_pizza_r  <= 7'd0;
    end else begin
      state        <= state_n;
      cnt          <= cnt_n;
      out_pita_r   <= out_pita_n;
      out_pizza_r  <= out_pizza_n;
    end
  end

  // Registered output assignment
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pita_count <= 7'd0;
      pizza_count<= 7'd0;
      valid      <= 1'b0;
      done       <= 1'b0;
    end else begin
      // Registered outputs
      pita_count <= out_pita_r;
      pizza_count<= out_pizza_r;
      valid      <= out_valid_n;

      // done is high only in DONE state
      done       <= (state_n == DONE);
    end
  end

endmodule
