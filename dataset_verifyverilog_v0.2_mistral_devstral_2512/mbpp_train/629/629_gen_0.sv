module filter_even (
  input [7:0] data_in [0:7],
  output [7:0] data_out [0:7],
  output [2:0] count
);

  reg [2:0] cnt = 0;
  integer i;

  always @* begin
    cnt = 0;
    for (i = 0; i < 8; i = i + 1) begin
      if (data_in[i][0] == 0) begin
        data_out[cnt] = data_in[i];
        cnt = cnt + 1;
      end
    end
    count = cnt;
  end

endmodule