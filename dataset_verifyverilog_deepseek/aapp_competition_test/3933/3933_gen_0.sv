module temperature_predictor (
  input clk,
  input rst_n,
  input start,
  input [11:0] temp_0, temp_1, temp_2, temp_3, temp_4, temp_5, temp_6, temp_7,
  input [2:0] n,
  output reg [11:0] prediction,
  output reg done
);

  typedef enum logic [1:0] {IDLE, COMPARE, CALCULATE, DONE} state_t;
  state_t state, next_state;

  reg [11:0] temp_reg [0:7];
  reg [2:0] n_reg;
  reg signed [11:0] common_diff;
  reg is_arithmetic;

  function automatic logic check_ap(input [11:0] tr [0:7], input [2:0] nr);
    logic signed [11:0] cd;
    logic ap = 1'b1;
    int i;
  begin
    if (nr < 2) return 1'b1; // Shouldn't occur, but safe guard
    cd = $signed(tr[1]) - $signed(tr[0]);
    for (i = 2; i < nr; i++) begin
      if ($signed(tr[i]) - $signed(tr[i-1]) != cd) ap = 0;
    end
    return ap;
  end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      prediction <= 0;
      is_arithmetic <= 0;
      common_diff <= 0;
      foreach (temp_reg[i]) temp_reg[i] <= 0;
      n_reg <= 0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            temp_reg[0] <= temp_0;
            temp_reg[1] <= temp_1;
            temp_reg[2] <= temp_2;
            temp_reg[3] <= temp_3;
            temp_reg[4] <= temp_4;
            temp_reg[5] <= temp_5;
            temp_reg[6] <= temp_6;
            temp_reg[7] <= temp_7;
            n_reg <= n;
          end
        end

        COMPARE: begin
          is_arithmetic <= check_ap(temp_reg, n_reg);
          common_diff <= $signed(temp_reg[1]) - $signed(temp_reg[0]);
        end

        CALCULATE: begin
          if (is_arithmetic) prediction <= $signed(temp_reg[n_reg-1]) + common_diff;
          else prediction <= $signed(temp_reg[n_reg-1]);
        end

        DONE: done <= 1;
      endcase
    end
  end

  always_comb begin
    case (state)
      IDLE:    next_state = start ? COMPARE : IDLE;
      COMPARE: next_state = CALCULATE;
      CALCULATE: next_state = DONE;
      DONE:    next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

endmodule