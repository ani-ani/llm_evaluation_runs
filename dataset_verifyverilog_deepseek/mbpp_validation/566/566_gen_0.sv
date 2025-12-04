module digit_sum (
  input clk,
  input rst_n,
  input start,
  input [15:0] num,
  output reg [5:0] sum,
  output reg done
);

  enum {IDLE, BUSY, DONE} state;
  reg [15:0] working_reg;
  reg [2:0] counter;

  function automatic [19:0] div_mod10(input [15:0] num);
    integer i;
    reg [15:0] quotient;
    reg [3:0] remainder;
    reg [15:0] temp;
    reg [15:0] divisor;
    begin
      quotient = 0;
      temp = num;
      for (i=15; i>=0; i=i-1) begin
        divisor = 10 << i;
        if (temp >= divisor) begin
          temp = temp - divisor;
          quotient = quotient + (1 << i);
        end
      end
      remainder = temp[3:0];
      div_mod10 = {quotient, remainder};
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sum <= 0;
      done <= 0;
      working_reg <= 0;
      counter <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            working_reg <= num;
            sum <= 0;
            counter <= 0;
            state <= BUSY;
          end
        end

        BUSY: begin
          automatic logic [19:0] divmod_result = div_mod10(working_reg);
          automatic logic [15:0] next_working = divmod_result[19:4];
          automatic logic [3:0] digit = divmod_result[3:0];

          sum <= sum + digit;
          working_reg <= next_working;
          counter <= counter + 1;
          
          if (next_working == 0 || counter == 4)
            state <= DONE;
          
          done <= (counter == 4);
        end

        DONE: begin
          done <= 1;
          if (start)
            state <= IDLE;
        end
      endcase
    end
  end
endmodule