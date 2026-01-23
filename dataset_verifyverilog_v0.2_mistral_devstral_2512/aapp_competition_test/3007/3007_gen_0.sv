module max_bling_calculator (
  input clk,
  input rst_n,
  input start,
  input [7:0] d_in,
  input [7:0] b_in,
  input [7:0] f_in,
  input [7:0] t0_in,
  input [7:0] t1_in,
  input [7:0] t2_in,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SIMULATE_DAY,
    CALCULATE,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [7:0] days_left;
  reg [15:0] current_bling;
  reg [7:0] current_fruits;
  reg [7:0] t0, t1, t2;
  reg [7:0] day_counter;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
      day_counter <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = SIMULATE_DAY;
      end
      SIMULATE_DAY: begin
        if (day_counter == d_in - 1) next_state = CALCULATE;
        else next_state = SIMULATE_DAY;
      end
      CALCULATE: begin
        next_state = DONE;
      end
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      days_left <= 0;
      current_bling <= 0;
      current_fruits <= 0;
      t0 <= 0;
      t1 <= 0;
      t2 <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            days_left <= d_in;
            current_bling <= b_in;
            current_fruits <= f_in;
            t0 <= t0_in;
            t1 <= t1_in;
            t2 <= t2_in;
            day_counter <= 0;
          end
        end
        SIMULATE_DAY: begin
          // Harvest trees yielding today
          current_fruits <= current_fruits + (t0 * 3);

          // Action: Plant all normal fruits if days_left >= 3
          if (days_left >= 3) begin
            t2 <= t2 + current_fruits;
            current_fruits <= 0;
          end

          // Action: Buy exotic if Bling >= 400 AND days_left >= 3
          if (current_bling >= 400 && days_left >= 3) begin
            current_bling <= current_bling - 400;
            // Plant exotic immediately (add to t2)
            t2 <= t2 + 1;
          end

          // Action: Sell remaining fruits if days_left < 3
          if (days_left < 3) begin
            current_bling <= current_bling + (current_fruits * 100);
            current_fruits <= 0;
          end

          // Update trees: Shift t2->t1->t0
          t0 <= t1;
          t1 <= t2;
          t2 <= 0;

          // Decrement day counter
          days_left <= days_left - 1;
          day_counter <= day_counter + 1;
        end
        CALCULATE: begin
          // Sell all remaining fruits
          current_bling <= current_bling + (current_fruits * 100);
          result <= current_bling;
          done <= 1;
        end
        DONE: begin
          done <= 0;
        end
      endcase
    end
  end

endmodule