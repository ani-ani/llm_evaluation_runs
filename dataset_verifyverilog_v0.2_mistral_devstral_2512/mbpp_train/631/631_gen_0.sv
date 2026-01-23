module replace_spaces (
  input [127:0] data_in,
  input [3:0] length,
  output reg [127:0] data_out,
  output reg [3:0] out_length
);

  integer i;
  always @* begin
    out_length = length;
    for (i = 0; i < 16; i = i + 1) begin
      if (i < length) begin
        case (data_in[8*i + 7 : 8*i])
          8'h20: data_out[8*i + 7 : 8*i] = 8'h5F;
          8'h5F: data_out[8*i + 7 : 8*i] = 8'h20;
          default: data_out[8*i + 7 : 8*i] = data_in[8*i + 7 : 8*i];
        endcase
      end else begin
        data_out[8*i + 7 : 8*i] = data_in[8*i + 7 : 8*i];
      end
    end
  end

endmodule