module monstermind_score_calculator (
  input clk,
  input rst_n,
  input start,
  input [3:0] t,
  input [1:0] n,   // 2-bit, so n can be 0,1,2,3
  input [4:0] wcnt0,
  input [4:0] wcnt1,
  input [4:0] wcnt2,
  input [4:0] wcnt3,
  output reg [31:0] expected_score,
  output reg done
);

parameter IDLE=2'b00, CALC_UNIQUE=2'b01, COMPUTE=2'b10, DONE=2'b11;

reg [1:0] state;
reg [3:0] s_current;
reg [5:0] best_value;
reg [3:0] best_s;
reg [2:0] best_count;
reg [4:0] wcnt_reg [3:0];

// Combinational block for count and current_value
reg [2:0] count;
reg [5:0] current_value;
always @(*) begin
  if (state == CALC_UNIQUE) begin
    count = 3'b0;
    if (n >= 1 && wcnt_reg[0] <= s_current) count = count + 1;
    if (n >= 2 && wcnt_reg[1] <= s_current) count = count + 1;
    if (n >= 3 && wcnt_reg[2] <= s_current) count = count + 1;
    current_value = count * (t - s_current);
  end
  else begin
    count = 3'b0;
    current_value = 6'b0;
  end
end

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    expected_score <= 32'b0;
    done <= 1'b0;
    s_current <= 4'b0;
    best_value <= 6'b0;
    best_s <= 4'b0;
    best_count <= 3'b0;
    wcnt_reg[0] <= 5'b0;
    wcnt_reg[1] <= 5'b0;
    wcnt_reg[2] <= 5'b0;
    wcnt_reg[3] <= 5'b0;
  end
  else begin
    case (state)
      IDLE: begin
        if (start) begin
          wcnt_reg[0] <= wcnt0;
          wcnt_reg[1] <= wcnt1;
          wcnt_reg[2] <= wcnt2;
          wcnt_reg[3] <= wcnt3;
          s_current <= 4'b1;
          best_value <= 6'b0;
          best_s <= 4'b0;
          best_count <= 3'b0;
          done <= 1'b0;
          state <= CALC_UNIQUE;
        end
        else begin
          state <= IDLE;
        end
      end

      CALC_UNIQUE: begin
        if (current_value > best_value) begin
          best_value <= current_value;
          best_s <= s_current;
          best_count <= count;
        end

        s_current <= s_current + 1;

        if (s_current > t) begin
          state <= COMPUTE;
        end
        else begin
          state <= CALC_UNIQUE;
        end
      end

      COMPUTE: begin
        reg [31:0] temp;
        temp = {best_value, 16'b0};   // best_value * 65536
        case (n)
          2'b00: expected_score <= temp;          // n=0
          2'b01: expected_score <= temp;          // n=1
          2'b10: expected_score <= temp >> 1;     // n=2
          2'b11: expected_score <= temp / 3;      // n=3
        endcase
        done <= 1'b1;
        state <= DONE;
      end

      DONE: begin
        if (start == 0) begin
          state <= IDLE;
        end
        else begin
          state <= DONE;
        end
      end
    endcase
  end
end

endmodule