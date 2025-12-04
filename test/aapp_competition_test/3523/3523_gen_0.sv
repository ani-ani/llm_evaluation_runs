module coin_payer(
  input clk,
  input rst_n,
  input start,
  input [7:0] P,
  input [3:0] N1,
  input [3:0] N5,
  input [3:0] N10,
  input [3:0] N25,
  output reg [5:0] coins_used,
  output reg impossible,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE    = 3'b000,
    CALC_25 = 3'b001,
    CALC_10 = 3'b010,
    CALC_5  = 3'b011,
    CALC_1  = 3'b100
  } state_t;

  state_t state, next_state;

  reg [7:0] rem_P;
  reg [5:0] coins_cnt;

  // Combinational next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CALC_25;
      end
      CALC_25: next_state = CALC_10;
      CALC_10: next_state = CALC_5;
      CALC_5:  next_state = CALC_1;
      CALC_1:  next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      rem_P       <= 8'd0;
      coins_cnt   <= 6'd0;
      coins_used  <= 6'd0;
      impossible  <= 1'b0;
      done        <= 1'b0;
    end else begin
      // default outputs each cycle
      done <= 1'b0;

      state <= next_state;

      case (state)
        IDLE: begin
          // Clear outputs while idle
          coins_used <= 6'd0;
          impossible <= 1'b0;
          if (start) begin
            // Initialize for new computation
            rem_P     <= P;
            coins_cnt <= 6'd0;
          end
        end

        CALC_25: begin
          // Use 25c coins
          reg [7:0] max_by_value;
          reg [7:0] use_25;
          max_by_value = rem_P / 8'd25;
          use_25 = (max_by_value < N25) ? max_by_value : N25;
          rem_P <= rem_P - use_25 * 8'd25;
          coins_cnt <= coins_cnt + use_25[5:0];
        end

        CALC_10: begin
          // Use 10c coins
          reg [7:0] max_by_value;
          reg [7:0] use_10;
          max_by_value = rem_P / 8'd10;
          use_10 = (max_by_value < N10) ? max_by_value : N10;
          rem_P <= rem_P - use_10 * 8'd10;
          coins_cnt <= coins_cnt + use_10[5:0];
        end

        CALC_5: begin
          // Use 5c coins
          reg [7:0] max_by_value;
          reg [7:0] use_5;
          max_by_value = rem_P / 8'd5;
          use_5 = (max_by_value < N5) ? max_by_value : N5;
          rem_P <= rem_P - use_5 * 8'd5;
          coins_cnt <= coins_cnt + use_5[5:0];
        end

        CALC_1: begin
          // Use 1c coins
          reg [7:0] max_by_value;
          reg [7:0] use_1;
          max_by_value = rem_P; // since denom is 1
          use_1 = (max_by_value < N1) ? max_by_value : N1;
          rem_P <= rem_P - use_1;
          coins_cnt <= coins_cnt + use_1[5:0];

          // Finalize result on this cycle
          if ((rem_P - use_1) == 8'd0) begin
            coins_used <= coins_cnt + use_1[5:0];
            impossible <= 1'b0;
          end else begin
            coins_used <= 6'd0;
            impossible <= 1'b1;
          end
          done <= 1'b1; // pulse done for this cycle
        end

        default: begin
          // Safety defaults
          coins_used <= coins_used;
          impossible <= impossible;
        end
      endcase
    end
  end

endmodule