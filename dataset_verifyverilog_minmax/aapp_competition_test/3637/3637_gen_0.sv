module pizza_topping_selector (
  input clk,
  input rst_n,
  input start,
  input [1:0] num_friends,
  input [71:0] friend_wishes,
  output reg [7:0] selected_toppings,
  output reg done
);

  // States
  localparam IDLE     = 2'b00;
  localparam CHECK    = 2'b01;
  localparam COMPLETE = 2'b10;

  reg [1:0] state, next_state;
  reg [7:0] candidate, next_candidate;

  // Candidate verification (combinational)
  reg [7:0] total_wishes_vec;
  reg [7:0] satisfied_wishes_vec;
  wire criterion_met;

  function [1:0] get_wish_type;
    input [17:0] field;
    input [1:0] idx; // 0..3
    integer i;
    begin
      i = idx;
      // Each wish is 4 bits: [3]=type, [2:0]=topping_id
      get_wish_type = field[12 + (3 - i)*4 + 3];
    end
  endfunction

  function [2:0] get_wish_topping;
    input [17:0] field;
    input [1:0] idx; // 0..3
    integer i;
    begin
      i = idx;
      get_wish_topping = field[12 + (3 - i)*4 + 2 : 12 + (3 - i)*4];
    end
  endfunction

  // Sum total and satisfied wishes across all friends (vector-wide adder)
  always @(*) begin
    total_wishes_vec     = 8'h0;
    satisfied_wishes_vec = 8'h0;
    for (int f = 0; f < 4; f = f + 1) begin
      if (f <= num_friends) begin
        reg [17:0] field;
        reg [1:0] tw;
        reg [7:0] sw;
        field = friend_wishes[f*18 + 17 : f*18];
        tw = field[17:16];        // wish_count (0..3)
        sw = 8'h0;
        for (int w = 0; w < 4; w = w + 1) begin
          if (w <= tw) begin      // valid wish if index <= wish_count
            reg [1:0] t;
            reg [2:0] top;
            t = get_wish_type(field, w);
            top = get_wish_topping(field, w);
            if (t == 1'b1) begin
              if (candidate[top] == 1'b1) sw = sw + 1;
            end else begin
              if (candidate[top] == 1'b0) sw = sw + 1;
            end
          end
        end
        total_wishes_vec     = total_wishes_vec + (tw + 1);
        satisfied_wishes_vec = satisfied_wishes_vec + sw;
      end
    end
  end

  // 3 * satisfied > total  <=>  satisfied*3 > total
  assign criterion_met = (satisfied_wishes_vec * 3) > total_wishes_vec;

  // State transition logic
  always @(*) begin
    next_state = state;
    next_candidate = candidate;
    case (state)
      IDLE: begin
        next_candidate = 8'b0000_0000;
        if (start) begin
          next_state = CHECK;
        end
      end
      CHECK: begin
        if (criterion_met) begin
          next_state = COMPLETE;
        end else begin
          next_candidate = candidate + 1;
          if (candidate == 8'b1111_1111) begin
            // Per problem, a solution always exists, so this state should not stick.
            // If reached, it would imply no solution (undefined behavior).
          end
        end
      end
      COMPLETE: begin
        // Hold until reset or new start
        if (start) begin
          next_candidate = 8'b0000_0000;
          next_state = CHECK;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential update (clocked)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= IDLE;
      candidate        <= 8'b0000_0000;
      selected_toppings <= 8'h0;
      done             <= 1'b0;
    end else begin
      state            <= next_state;
      candidate        <= next_candidate;
      if (state == CHECK) begin
        if (criterion_met) begin
          selected_toppings <= candidate;
          done             <= 1'b1;
        end else begin
          done             <= 1'b0;
        end
      end else if (state == IDLE) begin
        selected_toppings <= 8'h0;
        done             <= 1'b0;
      end
      // In COMPLETE, hold outputs; next start will transition to CHECK
    end
  end

endmodule