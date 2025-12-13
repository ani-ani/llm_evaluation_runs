module pizza_topping_selector(
  input clk,
  input rst_n,
  input start,
  input [1:0] num_friends,
  input [71:0] friend_wishes,
  output reg [7:0] selected_toppings,
  output reg done
);

  // State encoding
  localparam IDLE     = 2'b00;
  localparam CHECK    = 2'b01;
  localparam COMPLETE = 2'b10;

  reg [1:0] state, next_state;
  reg [7:0] candidate, next_candidate;

  // Combinational result for current candidate
  reg        candidate_ok;

  // Friend/wish processing variables
  integer f;
  integer w;

  reg [1:0] wish_count_f;           // encoded (0..3), actual wishes = +1
  reg [2:0] total_wishes_f;         // up to 4
  reg [2:0] satisfied_wishes_f;     // up to 4

  reg [17:0] friend_field;          // 18-bit slice per friend
  reg [3:0]  wish_nibble;           // 4-bit wish {type[3], topping_id[2:0]}
  reg        wish_type;
  reg [2:0]  wish_topping;

  // Combinational check for current candidate against all friends
  always @* begin
    candidate_ok = 1'b1;

    // Iterate over friends 0 .. num_friends (inclusive), total = num_friends + 1
    for (f = 0; f < 4; f = f + 1) begin
      if (f <= num_friends) begin
        // Extract 18-bit field for friend f
        // friend 0: bits [17:0]
        // friend 1: bits [35:18]
        // friend 2: bits [53:36]
        // friend 3: bits [71:54]
        friend_field = friend_wishes[18*f +: 18];

        // Top 2 bits: wish_count (encoded, 0..3) => actual wishes = wish_count + 1
        wish_count_f     = friend_field[17:16];
        total_wishes_f   = {1'b0, wish_count_f} + 3'd1;
        satisfied_wishes_f = 3'd0;

        // For each wish index 0..3 inside this friend
        for (w = 0; w < 4; w = w + 1) begin
          if (w < total_wishes_f) begin
            // Each wish is 4 bits: wish0: [15:12], wish1: [11:8], wish2: [7:4], wish3: [3:0]
            wish_nibble  = friend_field[4*w +: 4];
            wish_type    = wish_nibble[3];
            wish_topping = wish_nibble[2:0];

            // Check satisfaction based on candidate bits
            if (wish_type) begin
              // type = 1: wants topping enabled
              if (candidate[wish_topping]) begin
                satisfied_wishes_f = satisfied_wishes_f + 3'd1;
              end
            end else begin
              // type = 0: wants topping disabled
              if (!candidate[wish_topping]) begin
                satisfied_wishes_f = satisfied_wishes_f + 3'd1;
              end
            end
          end
        end

        // Check majority condition: 3 * satisfied_wishes > total_wishes
        // Implement using inequality without multiplication overflow issues:
        // 3*s > t  => (s*3) > t; s,t <=4 so fit in small range
        if ((satisfied_wishes_f * 3) <= total_wishes_f) begin
          candidate_ok = 1'b0;
        end
      end
    end
  end

  // Next-state and candidate counter logic
  always @* begin
    next_state     = state;
    next_candidate = candidate;

    case (state)
      IDLE: begin
        if (start) begin
          next_candidate = 8'b0000_0000;
          next_state     = CHECK;
        end
      end

      CHECK: begin
        if (candidate_ok) begin
          // Found a valid candidate; move to COMPLETE
          next_state = COMPLETE;
        end else begin
          // Try next candidate; maximum 256 cycles
          next_candidate = candidate + 8'd1;
          // Per problem, assume a solution exists before wrap; no explicit wrap handling
          next_state = CHECK;
        end
      end

      COMPLETE: begin
        // Hold solution until next start pulse observed in IDLE after reset
        next_state     = COMPLETE;
        next_candidate = candidate;
      end

      default: begin
        next_state     = IDLE;
        next_candidate = 8'd0;
      end
    endcase
  end

  // Sequential state and outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state             <= IDLE;
      candidate         <= 8'd0;
      selected_toppings <= 8'd0;
      done              <= 1'b0;
    end else begin
      state     <= next_state;
      candidate <= next_candidate;

      case (next_state)
        IDLE: begin
          done              <= 1'b0;
          selected_toppings <= 8'd0;
        end

        CHECK: begin
          // Outputs remain invalid until candidate_ok and transition to COMPLETE
          done <= 1'b0;
        end

        COMPLETE: begin
          // Latch the found candidate as the selected toppings
          done              <= 1'b1;
          selected_toppings <= candidate;
        end

        default: begin
          done              <= 1'b0;
          selected_toppings <= 8'd0;
        end
      endcase
    end
  end

endmodule