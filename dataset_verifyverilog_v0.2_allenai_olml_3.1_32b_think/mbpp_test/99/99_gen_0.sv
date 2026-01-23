module decimal_to_binary (
   input clk,
   input rst_n,
   input start,
   input [15:0] decimal_in,
   output reg [79:0] binary_str,
   output reg [3:0] length,
   output reg done
);

reg [1:0] state; 
reg [3:0] msb_pos;
reg [3:0] check_bit;
reg msb_found;
reg [79:0] binary_str_reg;
reg [3:0] length_reg;
reg done_reg;

assign binary_str = binary_str_reg;
assign length = length_reg;
assign done = done_reg;

always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= 2'd0;
      msb_pos <= 4'd15;
      check_bit <= 4'd15;
      msb_found <=0;
      binary_str_reg <=80'h0;
      length_reg <=4'd0;
      done_reg <=0;
   end else begin
      case (state)
         2'd0: begin
            if (start) begin
               state <= 2'd1;
               msb_pos <=4'd15;
               check_bit <=4'd15;
               msb_found <=0;
            end else begin
               state <= 2'd0;
            end
         end
         2'd1: begin
            if (!msb_found) begin
               if (check_bit >=0) begin
                  if (decimal_in[check_bit]) begin
                     msb_pos <= check_bit;
                     msb_found <=1;
                  end else begin
                     check_bit <= check_bit -1;
                  end
               end else begin
                  msb_found <=1;
               end
            end else begin
               if (msb_pos ==4'd15) begin
                  length_reg <=4'd1;
                  binary_str_reg <=80'h30303030303030303030303030303030;
                  state <= 2'd2;
               end else begin
                  length_reg <= msb_pos +1;
                  if (0 < length_reg) begin
                     binary_str_reg[7:0] = 48 + decimal_in[msb_pos];
                  end else begin
                     binary_str_reg[7:0] =48;
                  end
                  if (1 < length_reg) begin
                     binary_str_reg[15:8] =48 + decimal_in[msb_pos -1];
                  end else begin
                     binary_str_reg[15:8] =48;
                  end
                  if (2 < length_reg) begin
                     binary_str_reg[23:16] =48 + decimal_in[msb_pos -2];
                  end else begin
                     binary_str_reg[23:16] =48;
                  end
                  if (3 < length_reg) begin
                     binary_str_reg[31:24] =48 + decimal_in[msb_pos -3];
                  end else begin
                     binary_str_reg[31:24] =48;
                  end
                  if (4 < length_reg) begin
                     binary_str_reg[39:32] =48 + decimal_in[msb_pos -4];
                  end else begin
                     binary_str_reg[39:32] =48;
                  end
                  if (5 < length_reg) begin
                     binary_str_reg[47:40] =48 + decimal_in[msb_pos -5];
                  end else begin
                     binary_str_reg[47:40] =48;
                  end
                  if (6 < length_reg) begin
                     binary_str_reg[55:48] =48 + decimal_in[msb_pos -6];
                  end else begin
                     binary_str_reg[55:48] =48;
                  end
                  if (7 < length_reg) begin
                     binary_str_reg[63:56] =48 + decimal_in[msb_pos -7];
                  end else begin
                     binary_str_reg[63:56] =48;
                  end
                  if (8 < length_reg) begin
                     binary_str_reg[71:64] =48 + decimal_in[msb_pos -8];
                  end else begin
                     binary_str_reg[71:64] =48;
                  end
                  if (9 < length_reg) begin
                     binary_str_reg[79:72] =48 + decimal_in[msb_pos -9];
                  end else begin
                     binary_str_reg[79:72] =48;
                  end
                  state <= 2'd2;
               end
            end
         end
         2'd2: begin
            done_reg <=1;
            state <= 2'd2;
         end
      endcase
   end
endmodule