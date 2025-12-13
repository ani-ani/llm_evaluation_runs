module max_bling_calculator(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0]  days_remaining,
  input  [15:0] initial_bling,
  input  [6:0]  initial_fruits,
  input  [6:0]  t0,
  input  [6:0]  t1,
  input  [6:0]  t2,
  output reg [15:0] max_bling,
  output reg done
);

  // State encoding
  localparam [1:0]
    IDLE       = 2'b00,
    PROCESSING = 2'b01,
    DONE       = 2'b10;

  reg [1:0] state, next_state;

  // Internal registers
  reg [2:0]  days_left, days_left_n;
  reg [15:0] bling, bling_n;
  reg [15:0] fruits, fruits_n;      // total fruits (normal + exotic), up to days<=8

  // Normal tree pipelines
  reg [6:0] nt0, nt1, nt2;
  reg [6:0] nt0_n, nt1_n, nt2_n;

  // Exotic tree pipelines
  reg [6:0] et0, et1, et2;
  reg [6:0] et0_n, et1_n, et2_n;

  // Combinational signals
  reg [15:0] bling_tmp;
  reg [15:0] fruits_tmp;
  reg [6:0]  new_exotic_trees;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      days_left  <= 3'd0;
      bling      <= 16'd0;
      fruits     <= 16'd0;
      nt0        <= 7'd0;
      nt1        <= 7'd0;
      nt2        <= 7'd0;
      et0        <= 7'd0;
      et1        <= 7'd0;
      et2        <= 7'd0;
      max_bling  <= 16'd0;
      done       <= 1'b0;
    end else begin
      state     <= next_state;
      days_left <= days_left_n;
      bling     <= bling_n;
      fruits    <= fruits_n;
      nt0       <= nt0_n;
      nt1       <= nt1_n;
      nt2       <= nt2_n;
      et0       <= et0_n;
      et1       <= et1_n;
      et2       <= et2_n;

      if (next_state == DONE) begin
        max_bling <= bling_n;
        done      <= 1'b1;
      end else if (next_state == IDLE) begin
        done      <= 1'b0;
      end
    end
  end

  // Combinational next-state and datapath
  always @* begin
    // Default assignments
    next_state     = state;

    days_left_n    = days_left;
    bling_n        = bling;
    fruits_n       = fruits;

    nt0_n          = nt0;
    nt1_n          = nt1;
    nt2_n          = nt2;

    et0_n          = et0;
    et1_n          = et1;
    et2_n          = et2;

    bling_tmp      = bling;
    fruits_tmp     = fruits;
    new_exotic_trees = 7'd0;

    case (state)
      IDLE: begin
        if (start) begin
          // Initialize for new run
          days_left_n = days_remaining;
          bling_n     = initial_bling;
          fruits_n    = initial_fruits;

          nt0_n       = t0;
          nt1_n       = t1;
          nt2_n       = t2;

          et0_n       = 7'd0;
          et1_n       = 7'd0;
          et2_n       = 7'd0;

          next_state  = (days_remaining != 3'd0) ? PROCESSING : DONE;
        end
      end

      PROCESSING: begin
        // ===== Harvest phase =====
        // Each tree (normal or exotic) yields 3 fruits on day in t0.
        // Harvest from nt0 and et0.
        bling_tmp  = bling;
        fruits_tmp = fruits;

        // Add harvest fruits
        bling_tmp  = bling_tmp; // no direct bling from harvest
        fruits_tmp = fruits_tmp + (nt0 * 3) + (et0 * 3);

        // Shift pipelines: t0<-t1, t1<-t2, t2<-0
        nt0_n = nt1;
        nt1_n = nt2;
        nt2_n = 7'd0;

        et0_n = et1;
        et1_n = et2;
        et2_n = 7'd0;

        // ===== Action phase =====
        // 1) If bling>=400, buy one exotic fruit
        if (bling_tmp >= 16'd400) begin
          bling_tmp = bling_tmp - 16'd400;
          if (days_left >= 3'd3) begin
            // plant as exotic tree (goes to et2)
            new_exotic_trees = 7'd1;
          end else begin
            // sell immediately as fruit (assume 1 fruit unit; cannot plant)
            // For consistency with sell below, treat as 1 fruit to be sold immediately.
            // We model this by increasing fruits_tmp by 1, which will be sold.
            fruits_tmp = fruits_tmp + 16'd1;
          end
        end

        // Add any new exotic trees to et2_n
        et2_n = et2_n + new_exotic_trees;

        // 2) Plant or sell all fruits (normal + exotic fruits in hand)
        if (days_left >= 3'd3) begin
          // Plant all fruits into normal trees that will yield in 3 days
          // Each fruit becomes one tree in nt2
          if (fruits_tmp[15:7] != 0) begin
            // Saturate to 7 bits if more than 127
            nt2_n = nt2_n + 7'h7F;
          end else begin
            nt2_n = nt2_n + fruits_tmp[6:0];
          end
          fruits_tmp = 16'd0;
        end else begin
          // Not enough time: sell all fruits immediately
          // Assume each fruit sells for 1 Bling
          bling_tmp  = bling_tmp + fruits_tmp;
          fruits_tmp = 16'd0;
        end

        // Update registers
        bling_n  = bling_tmp;
        fruits_n = fruits_tmp;

        // Decrement days
        if (days_left > 3'd0)
          days_left_n = days_left - 3'd1;
        else
          days_left_n = 3'd0;

        // Advance state if finished
        if (days_left == 3'd1) begin
          next_state = DONE;
        end else begin
          next_state = PROCESSING;
        end
      end

      DONE: begin
        // Hold result until next start
        if (start) begin
          days_left_n = days_remaining;
          bling_n     = initial_bling;
          fruits_n    = initial_fruits;

          nt0_n       = t0;
          nt1_n       = t1;
          nt2_n       = t2;

          et0_n       = 7'd0;
          et1_n       = 7'd0;
          et2_n       = 7'd0;

          next_state  = (days_remaining != 3'd0) ? PROCESSING : DONE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule