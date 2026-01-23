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

// Registers
reg [3:0] L[LUT_SIZE][LUT_SIZE];
reg [CHAR_WIDTH-1:0] chars[LUT_SIZE];
reg [3:0] result_reg;
reg [1:0] state; // 0:IDLE, 1:PROCESSING, 2:WAIT, 3:DONE
reg compute_flag;
reg [7:0] counter;

// Assign result to result_reg
assign result = result_reg;

always @(posedge clk) begin
   if (!rst_n) begin
      // Reset all registers
      state <= 2'd0;
      result_reg <= 4'd0;
      done <= 1'b0;
      compute_flag <= 1'b0;
      counter <= 8'd0;
      // Initialize L to 0
      L[0][0] <= 4'd0; L[0][1] <=4'd0; L[0][2] <=4'd0; L[0][3] <=4'd0; L[0][4] <=4'd0; L[0][5] <=4'd0; L[0][6] <=4'd0; L[0][7] <=4'd0;
      L[1][0] <=4'd0; L[1][1] <=4'd0; L[1][2] <=4'd0; L[1][3] <=4'd0; L[1][4] <=4'd0; L[1][5] <=4'd0; L[1][6] <=4'd0; L[1][7] <=4'd0;
      L[2][0] <=4'd0; L[2][1] <=4'd0; L[2][2] <=4'd0; L[2][3] <=4'd0; L[2][4] <=4'd0; L[2][5] <=4'd0; L[2][6] <=4'd0; L[2][7] <=4'd0;
      L[3][0] <=4'd0; L[3][1] <=4'd0; L[3][2] <=4'd0; L[3][3] <=4'd0; L[3][4] <=4'd0; L[3][5] <=4'd0; L[3][6] <=4'd0; L[3][7] <=4'd0;
      L[4][0] <=4'd0; L[4][1] <=4'd0; L[4][2] <=4'd0; L[4][3] <=4'd0; L[4][4] <=4'd0; L[4][5] <=4'd0; L[4][6] <=4'd0; L[4][7] <=4'd0;
      L[5][0] <=4'd0; L[5][1] <=4'd0; L[5][2] <=4'd0; L[5][3] <=4'd0; L[5][4] <=4'd0; L[5][5] <=4'd0; L[5][6] <=4'd0; L[5][7] <=4'd0;
      L[6][0] <=4'd0; L[6][1] <=4'd0; L[6][2] <=4'd0; L[6][3] <=4'd0; L[6][4] <=4'd0; L[6][5] <=4'd0; L[6][6] <=4'd0; L[6][7] <=4'd0;
      L[7][0] <=4'd0; L[7][1] <=4'd0; L[7][2] <=4'd0; L[7][3] <=4'd0; L[7][4] <=4'd0; L[7][5] <=4'd0; L[7][6] <=4'd0; L[7][7] <=4'd0;

      // Initialize chars to 0
      chars[0] <= 8'd0; chars[1] <=8'd0; chars[2] <=8'd0; chars[3] <=8'd0;
      chars[4] <=8'd0; chars[5] <=8'd0; chars[6] <=8'd0; chars[7] <=8'd0;
   end else begin
      if (state == 2'd0) begin // IDLE
         if (start) begin
            // Sample characters
            chars[0] <= char_0;
            chars[1] <= char_1;
            chars[2] <= char_2;
            chars[3] <= char_3;
            chars[4] <= char_4;
            chars[5] <= char_5;
            chars[6] <= char_6;
            chars[7] <= char_7;
            state <= 2'd1; // PROCESSING
            compute_flag <= 1'b1; // Trigger computation next cycle
         end
      end else if (state == 2'd1) begin // PROCESSING
         if (compute_flag) begin
            // Compute L table here with unrolled assignments
            // Diagonal elements
            L[0][0] <= 4'd1; L[1][1] <=4'd1; L[2][2] <=4'd1; L[3][3] <=4'd1;
            L[4][4] <=4'd1; L[5][5] <=4'd1; L[6][6] <=4'd1; L[7][7] <=4'd1;

            // cl=2
            if (chars[0] == chars[1]) L[0][1] <= 2; else L[0][1] <=1;
            if (chars[1] == chars[2]) L[1][2] <= 2; else L[1][2] <=1;
            if (chars[2] == chars[3]) L[2][3] <= 2; else L[2][3] <=1;
            if (chars[3] == chars[4]) L[3][4] <= 2; else L[3][4] <=1;
            if (chars[4] == chars[5]) L[4][5] <= 2; else L[4][5] <=1;
            if (chars[5] == chars[6]) L[5][6] <= 2; else L[5][6] <=1;
            if (chars[6] == chars[7]) L[6][7] <= 2; else L[6][7] <=1;

            // cl=3
            if (chars[0] == chars[2]) L[0][2] <= L[1][1] + 2; else L[0][2] <= (L[0][1] > L[1][2]) ? L[0][1] : L[1][2];
            if (chars[1] == chars[3]) L[1][3] <= L[2][2] + 2; else L[1][3] <= (L[1][2] > L[2][3]) ? L[1][2] : L[2][3];
            if (chars[2] == chars[4]) L[2][4] <= L[3][3] + 2; else L[2][4] <= (L[2][3] > L[3][4]) ? L[2][3] : L[3][4];
            if (chars[3] == chars[5]) L[3][5] <= L[4][4] + 2; else L[3][5] <= (L[3][4] > L[4][5]) ? L[3][4] : L[4][5];
            if (chars[4] == chars[6]) L[4][6] <= L[5][5] + 2; else L[4][6] <= (L[4][5] > L[5][6]) ? L[4][5] : L[5][6];
            if (chars[5] == chars[7]) L[5][7] <= L[6][6] + 2; else L[5][7] <= (L[5][6] > L[6][7]) ? L[5][6] : L[6][7];

            // cl=4
            if (chars[0] == chars[3]) L[0][3] <= L[1][2] + 2; else L[0][3] <= (L[0][2] > L[1][3]) ? L[0][2] : L[1][3];
            if (chars[1] == chars[4]) L[1][4] <= L[2][3] + 2; else L[1][4] <= (L[1][3] > L[2][4]) ? L[1][3] : L[2][4];
            if (chars[2] == chars[5]) L[2][5] <= L[3][4] + 2; else L[2][5] <= (L[2][4] > L[3][5]) ? L[2][4] : L[3][5];
            if (chars[3] == chars[6]) L[3][6] <= L[4][5] + 2; else L[3][6] <= (L[3][5] > L[4][6]) ? L[3][5] : L[4][6];
            if (chars[4] == chars[7]) L[4][7] <= L[5][6] + 2; else L[4][7] <= (L[4][6] > L[5][7]) ? L[4][6] : L[5][7];

            // cl=5
            if (chars[0] == chars[4]) L[0][4] <= L[1][3] + 2; else L[0][4] <= (L[0][3] > L[1][4]) ? L[0][3] : L[1][4];
            if (chars[1] == chars[5]) L[1][5] <= L[2][4] + 2; else L[1][5] <= (L[1][4] > L[2][5]) ? L[1][4] : L[2][5];
            if (chars[2] == chars[6]) L[2][6] <= L[3][5] + 2; else L[2][6] <= (L[2][5] > L[3][6]) ? L[2][5] : L[3][6];
            if (chars[3] == chars[7]) L[3][7] <= L[4][6] + 2; else L[3][7] <= (L[3][6] > L[4][7]) ? L[3][6] : L[4][7];

            // cl=6
            if (chars[0] == chars[5]) L[0][5] <= L[1][4] + 2; else L[0][5] <= (L[0][4] > L[1][5]) ? L[0][4] : L[1][5];
            if (chars[1] == chars[6]) L[1][6] <= L[2][5] + 2; else L[1][6] <= (L[1][5] > L[2][6]) ? L[1][5] : L[2][6];
            if (chars[2] == chars[7]) L[2][7] <= L[3][6] + 2; else L[2][7] <= (L[2][6] > L[3][7]) ? L[2][6] : L[3][7];

            // cl=7
            if (chars[0] == chars[6]) L[0][6] <= L[1][5] + 2; else L[0][6] <= (L[0][5] > L[1][6]) ? L[0][5] : L[1][6];
            if (chars[1] == chars[7]) L[1][7] <= L[2][6] + 2; else L[1][7] <= (L[1][6] > L[2][7]) ? L[1][6] : L[2][7];

            // cl=8
            if (chars[0] == chars[7]) L[0][7] <= L[1][6] + 2; else L[0][7] <= (L[0][6] > L[1][7]) ? L[0][6] : L[1][7];

            // Move to WAIT state and set counter
            state <= 2'd2; // WAIT
            counter <= 8'd128;
            compute_flag <= 1'b0;
            // Assign result_reg
            result_reg <= L[0][7];
         end
      end else if (state == 2'd2) begin // WAIT
         if (counter > 0) begin
            counter <= counter - 1;
         end else begin
            state <= 2'd3; // DONE
            done <= 1'b1;
         end
      end else begin // DONE
         // Stay in DONE
      end
   end
end

// End of module