module max_bling_calculator (
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] days_remaining,
  input  [15:0] initial_bling,
  input  [6:0] initial_fruits,
  input  [6:0] t0,
  input  [6:0] t1,
  input  [6:0] t2,
  output reg [15:0] max_bling,
  output reg done
);

  // Local parameters (constant values; tweak if your model differs)
  parameter FRUIT_VALUE     = 10; // Bling per fruit when sold
  parameter EXOTIC_COST     = 400; // Bling to buy an exotic fruit
  parameter FRUITS_PER_TREE = 3;   // Fruits harvested per tree per day

  // State machine encoding
  typedef enum logic [1:0] { IDLE = 2'b00, PROCESSING = 2'b01, DONE = 2'b10 } state_t;
  state_t state, state_next;

  // Day counter and capture
  reg [2:0] days_left, days_left_next;
  reg [2:0] days_captured;

  // Working registers
  reg [15:0] bling, bling_next;
  reg [6:0]  fruits, fruits_next;       // normal fruits
  reg [6:0]  exotic_fruits, exotic_fruits_next;

  // Normal tree counters
  reg [6:0] nt0, nt0_next;
  reg [6:0] nt1, nt1_next;
  reg [6:0] nt2, nt2_next;

  // Exotic tree counters
  reg [6:0] et0, et0_next;
  reg [6:0] et1, et1_next;
  reg [6:0] et2, et2_next;

  // Sequential (async reset)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      days_left      <= 3'd0;
      days_captured  <= 3'd0;
      bling          <= 16'd0;
      fruits         <= 7'd0;
      exotic_fruits  <= 7'd0;
      nt0            <= 7'd0;
      nt1            <= 7'd0;
      nt2            <= 7'd0;
      et0            <= 7'd0;
      et1            <= 7'd0;
      et2            <= 7'd0;
      max_bling      <= 16'd0;
      done           <= 1'b0;
    end else begin
      state          <= state_next;
      days_left      <= days_left_next;
      days_captured  <= days_captured;
      bling          <= bling_next;
      fruits         <= fruits_next;
      exotic_fruits  <= exotic_fruits_next;
      nt0            <= nt0_next;
      nt1            <= nt1_next;
      nt2            <= nt2_next;
      et0            <= et0_next;
      et1            <= et1_next;
      et2            <= et2_next;
      max_bling      <= (state_next == DONE) ? bling_next : max_bling;
      done           <= (state_next == DONE);
    end
  end

  // Combinational next-state logic
  always_comb begin
    // Defaults (prevent latches)
    state_next         = state;
    days_left_next     = days_left;
    days_captured      = days_captured;
    bling_next         = bling;
    fruits_next        = fruits;
    exotic_fruits_next = exotic_fruits;
    nt0_next           = nt0;
    nt1_next           = nt1;
    nt2_next           = nt2;
    et0_next           = et0;
    et1_next           = et1;
    et2_next           = et2;

    case (state)
      IDLE: begin
        if (start) begin
          // Latch inputs and initialize counters
          days_captured  = days_remaining; // used to decide planting eligibility
          days_left_next = days_remaining;
          bling_next     = initial_bling;
          fruits_next    = initial_fruits;
          exotic_fruits_next = 7'd0;

          // Trees for today and upcoming days
          nt0_next = t0;
          nt1_next = t1;
          nt2_next = t2;
          et0_next = 7'd0; // start with zero exotic trees unless you want to support input init
          et1_next = 7'd0;
          et2_next = 7'd0;

          state_next = PROCESSING;
        end
      end

      PROCESSING: begin
        // One day per clock cycle

        // 1) Harvest phase
        // Harvest normal and exotic trees in t0
        fruits_next        = fruits        + (nt0        * FRUITS_PER_TREE);
        exotic_fruits_next = exotic_fruits + (et0        * FRUITS_PER_TREE);

        // Shift normal tree counters (t0<-t1, t1<-t2, t2<-0)
        nt0_next = nt1;
        nt1_next = nt2;
        nt2_next = 7'd0;

        // Shift exotic tree counters (same logic)
        et0_next = et1;
        et1_next = et2;
        et2_next = 7'd0;

        // 2) Action phase (same cycle)
        // a) Special exotic purchase rule:
        //    If bling >= 400, attempt to buy ONE exotic fruit and plant it (if days_left >= 3), else sell it immediately.
        if (bling_next >= EXOTIC_COST) begin
          if (days_left_next >= 3) begin
            // Buy and plant: creates an exotic tree that yields in 2 more days (et2)
            bling_next         = bling_next - EXOTIC_COST;
            exotic_fruits_next = exotic_fruits_next; // no immediate change (bought and planted)
            et2_next           = et2_next + 1;       // plant in t2
          end else begin
            // Not enough time to plant; sell immediately
            bling_next = bling_next + (EXOTIC_COST + FRUIT_VALUE);
            // exotic_fruits_next unchanged because we didn't add to inventory
          end
        end

        // b) For all normal and exotic fruits: plant if remaining days (including current day) >= 3, else sell.
        if (days_left_next >= 3) begin
          // Plant as many normal fruits as possible (each becomes nt2)
          nt2_next = nt2_next + fruits_next;
          fruits_next = 7'd0;

          // Plant exotic fruits as well (each becomes et2)
          et2_next = et2_next + exotic_fruits_next;
          exotic_fruits_next = 7'd0;
        end else begin
          // Sell all fruits (convert to Bling)
          bling_next = bling_next + (fruits_next * FRUIT_VALUE);
          bling_next = bling_next + (exotic_fruits_next * FRUIT_VALUE);
          fruits_next        = 7'd0;
          exotic_fruits_next = 7'd0;
        end

        // Decrement day counter
        if (days_left_next > 3'd0) begin
          days_left_next = days_left_next - 1;
        end

        // If all days processed, go to DONE
        if (days_left_next == 3'd0) begin
          state_next = DONE;
        end
      end

      DONE: begin
        // Wait for next start; hold outputs steady
        state_next = start ? PROCESSING : DONE;

        // If restarting, relatch inputs in IDLE next cycle (but state is already PROCESSING here)
        // We keep current working values when in DONE.
      end
    endcase
  end

endmodule
