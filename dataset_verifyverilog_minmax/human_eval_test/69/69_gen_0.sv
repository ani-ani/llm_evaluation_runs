module frequency_max(
   input clk,
   input rst_n,
   input start,
   input [3:0] data [0:7],
   output reg [4:0] result,
   output reg done
);

  typedef enum logic [1:0] {IDLE, COUNT, COMPARE, DONE} state_t;
  state_t state;

  reg [3:0] freq [0:15];
  reg [3:0] index;

  always_ff @(posedge clk) begin
     if (!rst_n) begin
        state <= IDLE;
        result <= 0;
        done <= 0;
        index <= 0;
        for (int i=0; i<16; i++) begin
           freq[i] <= 0;
        end
     end
     else begin
        case (state)
          IDLE: begin
             result <= 0;
             done <= 0;
             index <= 0;
             if (start) begin
                state <= COUNT;
                for (int i=0; i<16; i++) begin
                   freq[i] <= 0;
                end
             end
          end
          COUNT: begin
             if (index < 8) begin
                if (data[index] != 0) begin
                   freq[data[index]] <= freq[data[index]] + 1;
                end
                index <= index + 1;
             end
             else begin
                state <= COMPARE;
             end
          end
          COMPARE: begin
             done <= 1;
             if (freq[15] >= 15) begin
                result <= 5'b01111;
             end
             else if (freq[14] >= 14) begin
                result <= 5'b01110;
             end
             else if (freq[13] >= 13) begin
                result <= 5'b01101;
             end
             else if (freq[12] >= 12) begin
                result <= 5'b01100;
             end
             else if (freq[11] >= 11) begin
                result <= 5'b01011;
             end
             else if (freq[10] >= 10) begin
                result <= 5'b01010;
             end
             else if (freq[9] >= 9) begin
                result <= 5'b01001;
             end
             else if (freq[8] >= 8) begin
                result <= 5'b01000;
             end
             else if (freq[7] >= 7) begin
                result <= 5'b00111;
             end
             else if (freq[6] >= 6) begin
                result <= 5'b00110;
             end
             else if (freq[5] >= 5) begin
                result <= 5'b00101;
             end
             else if (freq[4] >= 4) begin
                result <= 5'b00100;
             end
             else if (freq[3] >= 3) begin
                result <= 5'b00011;
             end
             else if (freq[2] >= 2) begin
                result <= 5'b00010;
             end
             else if (freq[1] >= 1) begin
                result <= 5'b00001;
             end
             else begin
                result <= 5'b11111;
             end
             state <= DONE;
          end
          DONE: begin
             state <= IDLE;
          end
        endcase
     end
  end

endmodule