module digit_sum (
  input        clk,
  input        rst_n,
  input        start,
  input  [15:0] num,
  output reg [5:0] sum,
  output reg   done
);

  // Working register
  reg [15:0] work_reg;

  // State encoding
  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_CALC  = 2'b01,
    S_DONE  = 2'b10
  } state_t;

  state_t state, next_state;

  // Sequential state and data registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= S_IDLE;
      work_reg <= 16'd0;
      sum      <= 6'd0;
      done     <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          if (start) begin
            work_reg <= num;
            sum      <= 6'd0;
            done     <= 1'b0;
          end
        end

        S_CALC: begin
          // Compute mod-10 via repeated subtraction
          // and quotient via (work_reg - digit)/10
          if (work_reg != 16'd0) begin
            reg [15:0] tmp;
            reg [3:0]  digit;

            tmp   = work_reg;
            digit = 4'd0;

            if (tmp >= 16'd10) begin tmp = tmp - 16'd10; digit = digit + 4'd1; end
            if (tmp >= 16'd10) begin tmp = tmp - 16'd10; digit = digit + 4'd1; end
            if (tmp >= 16'd10) begin tmp = tmp - 16'd10; digit = digit + 4'd1; end
            if (tmp >= 16'd10) begin tmp = tmp - 16'd10; digit = digit + 4'd1; end
            if (tmp >= 16'd10) begin tmp = tmp - 16'd10; digit = digit + 4'd1; end
            if (tmp >= 16'd10) begin tmp = tmp - 16'd10; digit = digit + 4'd1; end
            if (tmp >= 16'd10) begin tmp = tmp - 16'd10; digit = digit + 4'd1; end
            if (tmp >= 16'd10) begin tmp = tmp - 16'd10; digit = digit + 4'd1; end
            if (tmp >= 16'd10) begin tmp = tmp - 16'd10; digit = digit + 4'd1; end
            if (tmp >= 16'd10) begin tmp = tmp - 16'd10; digit = digit + 4'd1; end

            sum      <= sum + tmp[3:0];
            work_reg <= digit;

            if (digit == 4'd0)
              done <= 1'b1;
          end else begin
            done <= 1'b1;
          end
        end

        S_DONE: begin
          // Hold done high until next start or reset
          if (start) begin
            work_reg <= num;
            sum      <= 6'd0;
            done     <= 1'b0;
          end
        end

        default: begin
          state <= S_IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_CALC;
      end

      S_CALC: begin
        if (work_reg == 16'd0)
          next_state = S_DONE;
      end

      S_DONE: begin
        if (start)
          next_state = S_CALC;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule