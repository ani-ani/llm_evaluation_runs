module lps (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_0, char_1, char_2, char_3, char_4, char_5, char_6, char_7,
  output reg [3:0] result,
  output reg done
);

  parameter CHAR_WIDTH = 8;
  parameter LUT_SIZE = 8;
  parameter IDLE = 2'b00;
  parameter PROCESSING = 2'b01;
  parameter DONE = 2'b10;

  reg [1:0] state;
  reg [3:0] cl;
  reg [3:0] i;
  reg [3:0] j;
  reg [3:0] L [0:LUT_SIZE-1][0:LUT_SIZE-1];
  reg [7:0] chars [0:LUT_SIZE-1];
  reg [3:0] counter;

  assign chars[0] = char_0;
  assign chars[1] = char_1;
  assign chars[2] = char_2;
  assign chars[3] = char_3;
  assign chars[4] = char_4;
  assign chars[5] = char_5;
  assign chars[6] = char_6;
  assign chars[7] = char_7;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cl <= 0;
      i <= 0;
      j <= 0;
      counter <= 0;
      done <= 0;
      result <= 0;
      for (int x = 0; x < LUT_SIZE; x = x + 1) begin
        for (int y = 0; y < LUT_SIZE; y = y + 1) begin
          L[x][y] <= 0;
        end
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            cl <= 1;
            i <= 0;
            j <= 0;
            counter <= 0;
            done <= 0;
            for (int x = 0; x < LUT_SIZE; x = x + 1) begin
              L[x][x] <= 1;
            end
          end
        end
        PROCESSING: begin
          if (counter < 127) begin
            if (cl == 1) begin
              if (i < LUT_SIZE) begin
                L[i][i] <= 1;
                i <= i + 1;
              end else begin
                cl <= 2;
                i <= 0;
              end
            end else begin
              j <= i + cl - 1;
              if (chars[i] == chars[j]) begin
                if (cl == 2) begin
                  L[i][j] <= 2;
                end else begin
                  L[i][j] <= L[i+1][j-1] + 2;
                end
              end else begin
                if (L[i][j-1] > L[i+1][j]) begin
                  L[i][j] <= L[i][j-1];
                end else begin
                  L[i][j] <= L[i+1][j];
                end
              end
              i <= i + 1;
              if (i == LUT_SIZE - cl + 1) begin
                i <= 0;
                cl <= cl + 1;
              end
            end
            counter <= counter + 1;
          end else begin
            state <= DONE;
            result <= L[0][7];
            done <= 1;
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule