module tuple_length_checker (input reg [127:0] tuples, output wire match_flag);
    wire [7:0] tuple0_byte0 = tuples[127:120];
    wire [7:0] tuple0_byte1 = tuples[119:112];
    wire [7:0] tuple0_byte2 = tuples[111:104];
    wire [7:0] tuple0_byte3 = tuples[103:96];
    wire [7:0] tuple1_byte0 = tuples[95:88];
    wire [7:0] tuple1_byte1 = tuples[87:80];
    wire [7:0] tuple1_byte2 = tuples[79:72];
    wire [7:0] tuple1_byte3 = tuples[71:64];
    wire [7:0] tuple2_byte0 = tuples[63:56];
    wire [7:0] tuple2_byte1 = tuples[55:48];
    wire [7:0] tuple2_byte2 = tuples[47:40];
    wire [7:0] tuple2_byte3 = tuples[39:32];
    wire [7:0] tuple3_byte0 = tuples[31:24];
    wire [7:0] tuple3_byte1 = tuples[23:16];
    wire [7:0] tuple3_byte2 = tuples[15:8];
    wire [7:0] tuple3_byte3 = tuples[7:0];
    wire [2:0] len0 = (tuple0_byte0 == 0) ? 3'd0 :
                     (tuple0_byte1 == 0) ? 3'd1 :
                     (tuple0_byte2 == 0) ? 3'd2 :
                     (tuple0_byte3 == 0) ? 3'd3 : 3'd4;
    wire [2:0] len1 = (tuple1_byte0 == 0) ? 3'd0 :
                     (tuple1_byte1 == 0) ? 3'd1 :
                     (tuple1_byte2 == 0) ? 3'd2 :
                     (tuple1_byte3 == 0) ? 3'd3 : 3'd4;
    wire [2:0] len2 = (tuple2_byte0 == 0) ? 3'd0 :
                     (tuple2_byte1 == 0) ? 3'd1 :
                     (tuple2_byte2 == 0) ? 3'd2 :
                     (tuple2_byte3 == 0) ? 3'd3 : 3'd4;
    wire [2:0] len3 = (tuple3_byte0 == 0) ? 3'd0 :
                     (tuple3_byte1 == 0) ? 3'd1 :
                     (tuple3_byte2 == 0) ? 3'd2 :
                     (tuple3_byte3 == 0) ? 3'd3 : 3'd4;
    assign match_flag = (len0 == len1) && (len1 == len2) && (len2 == len3) && (len0 != 0);
endmodule