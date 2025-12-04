module remove_odd_chars (
  input [7:0] str_in [0:7],
  output reg [7:0] str_out [0:3],
  output reg [2:0] out_len
);
  always_comb begin
    reg [3:0] input_length;
    if (str_in[7] != 8'd0)      input_length = 4'd8;
    else if (str_in[6] != 8'd0) input_length = 4'd7;
    else if (str_in[5] != 8'd0) input_length = 4'd6;
    else if (str_in[4] != 8'd0) input_length = 4'd5;
    else if (str_in[3] != 8'd0) input_length = 4'd4;
    else if (str_in[2] != 8'd0) input_length = 4'd3;
    else if (str_in[1] != 8'd0) input_length = 4'd2;
    else if (str_in[0] != 8'd0) input_length = 4'd1;
    else                        input_length = 4'd0;
    
    out_len = input_length[3:1];
    
    str_out[0] = str_in[1];
    str_out[1] = str_in[3];
    str_out[2] = str_in[5];
    str_out[3] = str_in[7];
  end
endmodule