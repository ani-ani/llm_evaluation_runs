module concatenate (
  input [4:0][7:0] strings,
  input [2:0] count,
  output reg [39:0] result,
  output reg [2:0] length
);

  always @* begin
    case (count)
      3'd0: begin
        result = 40'b0;
        length = 3'd0;
      end
      3'd1: begin
        result = {strings[0], 32'b0};
        length = 3'd1;
      end
      3'd2: begin
        result = {strings[0], strings[1], 24'b0};
        length = 3'd2;
      end
      3'd3: begin
        result = {strings[0], strings[1], strings[2], 16'b0};
        length = 3'd3;
      end
      3'd4: begin
        result = {strings[0], strings[1], strings[2], strings[3], 8'b0};
        length = 3'd4;
      end
      3'd5: begin
        result = {strings[0], strings[1], strings[2], strings[3], strings[4]};
        length = 3'd5;
      end
      default: begin
        result = 40'b0;
        length = 3'd0;
      end
    endcase
  end

endmodule