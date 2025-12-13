module array_range_sum(
  input  [127:0] array_data,
  input  [3:0]   start_idx,
  input  [3:0]   end_idx,
  output [11:0]  range_sum
);

  // Unpack 16 x 8-bit elements from array_data
  wire [7:0] elem [0:15];

  assign elem[15] = array_data[127:120];
  assign elem[14] = array_data[119:112];
  assign elem[13] = array_data[111:104];
  assign elem[12] = array_data[103:96];
  assign elem[11] = array_data[95:88];
  assign elem[10] = array_data[87:80];
  assign elem[9]  = array_data[79:72];
  assign elem[8]  = array_data[71:64];
  assign elem[7]  = array_data[63:56];
  assign elem[6]  = array_data[55:48];
  assign elem[5]  = array_data[47:40];
  assign elem[4]  = array_data[39:32];
  assign elem[3]  = array_data[31:24];
  assign elem[2]  = array_data[23:16];
  assign elem[1]  = array_data[15:8];
  assign elem[0]  = array_data[7:0];

  // Combinational range sum
  reg [11:0] sum;
  integer i;

  always @* begin
    if (start_idx > end_idx) begin
      sum = 12'd0;
    end else begin
      sum = 12'd0;
      for (i = 0; i < 16; i = i + 1) begin
        if ((i >= start_idx) && (i <= end_idx)) begin
          sum = sum + elem[i];
        end
      end
    end
  end

  assign range_sum = sum;

endmodule