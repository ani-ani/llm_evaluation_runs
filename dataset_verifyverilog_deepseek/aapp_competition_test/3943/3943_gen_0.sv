module max_card_score (
  input clk,
  input rst_n,
  input start,
  input [7:0] a,
  input [7:0] b,
  output reg signed [16:0] max_score,
  output reg done
);

  typedef enum reg [1:0] { IDLE, COMPUTE, DONE } state_t;
  reg [1:0] state, next_state;
  reg [4:0] iter;
  reg [4:0] current_i;
  reg signed [16:0] next_max;
  reg start_d;
  reg [7:0] a_plus_2;
  reg special_case;

  // Edge detection for start
  always_ff @(posedge clk or negedge rst_n)
    if (!rst_n) start_d <= 0;
    else start_d <= start;

  wire start_posedge = start && !start_d;

  // Main FSM
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_score <= 0;
      done <= 0;
      iter <= 0;
      current_i <= 2;
      a_plus_2 <= 0;
      special_case <= 0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          if (start_posedge) begin
            special_case <= (a == 0) || (b == 0);
            a_plus_2 <= a + 2;
          end
          max_score <= next_max;
          done <= 0;
        end

        COMPUTE: begin
          iter <= iter + 1;
          current_i <= current_i + 1;
          max_score <= next_max;
        end

        DONE: done <= 1;
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;
    next_max = max_score;

    case (state)
      IDLE: begin
        if (start_posedge) begin
          if (a == 0) begin
            next_max = -($signed({1'b0, b}) * $signed({1'b0, b}));
            next_state = DONE;
          end else if (b == 0) begin
            next_max = $signed({1'b0, a}) * $signed({1'b0, a});
            next_state = DONE;
          end else if (!special_case) begin
            next_state = COMPUTE;
            iter <= 0;
          end
        end
      end

      COMPUTE: begin
        if (iter < 16) begin
          // V1 calculation
          reg [8:0] diff = a_plus_2 - current_i;
          reg signed [16:0] v1 = (diff * diff) + (current_i - 2);

          // Quo/Rem calculation
          reg [16:0] quotient = b / current_i;
          reg [16:0] remainder = b % current_i;

          // V2 calculation
          reg [16:0] quo_plus1 = quotient + 1;
          reg [16:0] term1 = remainder * (quo_plus1 * quo_plus1);
          reg [16:0] term2 = (current_i - remainder) * (quotient * quotient);
          reg signed [16:0] v2 = term1 + term2;

          reg signed [16:0] score = v1 - v2;
          if ((iter == 0) || (score > next_max)) next_max = score;
        end else begin
          next_state = DONE;
        end
      end

      DONE: next_state = IDLE;
    endcase
  end
endmodule