module tuple_length_checker (
  input reg [127:0] tuples,
  output match_flag
);
  
  wire [31:0] tuple0 = tuples[127:96];
  wire [31:0] tuple1 = tuples[95:64];
  wire [31:0] tuple2 = tuples[63:32];
  wire [31:0] tuple3 = tuples[31:0];
  
  wire [2:0] len0, len1, len2, len3;
  
  assign len0 = (tuple0[31:24] == 8'b0) ? 3'd0 :
                (tuple0[23:16] == 8'b0) ? 3'd1 :
                (tuple0[15:8] == 8'b0) ? 3'd2 :
                (tuple0[7:0] == 8'b0) ? 3'd3 : 3'd4;
  
  assign len1 = (tuple1[31:24] == 8'b0) ? 3'd0 :
                (tuple1[23:16] == 8'b0) ? 3'd1 :
                (tuple1[15:8] == 8'b0) ? 3'd2 :
                (tuple1[7:0] == 8'b0) ? 3'd3 : 3'd4;
  
  assign len2 = (tuple2[31:24] == 8'b0) ? 3'd0 :
                (tuple2[23:16] == 8'b0) ? 3'd1 :
                (tuple2[15:8] == 8'b0) ? 3'd2 :
                (tuple2[7:0] == 8'b0) ? 3'd3 : 3'd4;
  
  assign len3 = (tuple3[31:24] == 8'b0) ? 3'd0 :
                (tuple3[23:16] == 8'b0) ? 3'd1 :
                (tuple3[15:8] == 8'b0) ? 3'd2 :
                (tuple3[7:0] == 8'b0) ? 3'd3 : 3'd4;
  
  wire lengths_equal = (len0 == len1) && (len0 == len2) && (len0 == len3);
  assign match_flag = lengths_equal && (len0 != 0);

endmodule