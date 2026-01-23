module phone_numbers (
    input [6:0] n,
    input [399:0] digits,
    output reg [3:0] result
);
    // Count number of '8's in first n digits (4-bit each)
    reg [6:0] count_8;
    integer i;
    
    // Combinational logic for counting
    always @(*) begin
        count_8 = 7'd0;
        // Check each digit position based on n
        if (n >= 7'd1 && digits[3:0] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd2 && digits[7:4] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd3 && digits[11:8] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd4 && digits[15:12] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd5 && digits[19:16] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd6 && digits[23:20] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd7 && digits[27:24] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd8 && digits[31:28] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd9 && digits[35:32] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd10 && digits[39:36] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd11 && digits[43:40] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd12 && digits[47:44] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd13 && digits[51:48] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd14 && digits[55:52] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd15 && digits[59:56] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd16 && digits[63:60] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd17 && digits[67:64] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd18 && digits[71:68] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd19 && digits[75:72] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd20 && digits[79:76] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd21 && digits[83:80] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd22 && digits[87:84] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd23 && digits[91:88] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd24 && digits[95:92] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd25 && digits[99:96] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd26 && digits[103:100] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd27 && digits[107:104] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd28 && digits[111:108] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd29 && digits[115:112] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd30 && digits[119:116] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd31 && digits[123:120] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd32 && digits[127:124] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd33 && digits[131:128] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd34 && digits[135:132] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd35 && digits[139:136] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd36 && digits[143:140] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd37 && digits[147:144] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd38 && digits[151:148] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd39 && digits[155:152] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd40 && digits[159:156] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd41 && digits[163:160] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd42 && digits[167:164] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd43 && digits[171:168] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd44 && digits[175:172] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd45 && digits[179:176] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd46 && digits[183:180] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd47 && digits[187:184] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd48 && digits[191:188] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd49 && digits[195:192] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd50 && digits[199:196] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd51 && digits[203:200] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd52 && digits[207:204] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd53 && digits[211:208] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd54 && digits[215:212] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd55 && digits[219:216] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd56 && digits[223:220] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd57 && digits[227:224] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd58 && digits[231:228] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd59 && digits[235:232] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd60 && digits[239:236] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd61 && digits[243:240] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd62 && digits[247:244] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd63 && digits[251:248] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd64 && digits[255:252] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd65 && digits[259:256] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd66 && digits[263:260] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd67 && digits[267:264] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd68 && digits[271:268] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd69 && digits[275:272] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd70 && digits[279:276] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd71 && digits[283:280] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd72 && digits[287:284] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd73 && digits[291:288] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd74 && digits[295:292] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd75 && digits[299:296] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd76 && digits[303:300] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd77 && digits[307:304] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd78 && digits[311:308] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd79 && digits[315:312] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd80 && digits[319:316] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd81 && digits[323:320] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd82 && digits[327:324] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd83 && digits[331:328] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd84 && digits[335:332] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd85 && digits[339:336] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd86 && digits[343:340] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd87 && digits[347:344] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd88 && digits[351:348] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd89 && digits[355:352] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd90 && digits[359:356] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd91 && digits[363:360] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd92 && digits[367:364] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd93 && digits[371:368] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd94 && digits[375:372] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd95 && digits[379:376] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd96 && digits[383:380] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd97 && digits[387:384] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd98 && digits[391:388] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd99 && digits[395:392] == 4'd8) count_8 = count_8 + 7'd1;
        if (n >= 7'd100 && digits[399:396] == 4'd8) count_8 = count_8 + 7'd1;
    end
    
    // Combinational lookup for k = n // 11
    reg [6:0] k;
    always @(*) begin
        case (n)
            7'd0, 7'd1, 7'd2, 7'd3, 7'd4, 7'd5, 7'd6, 7'd7, 7'd8, 7'd9, 7'd10: k = 7'd0;
            7'd11, 7'd12, 7'd13, 7'd14, 7'd15, 7'd16, 7'd17, 7'd18, 7'd19, 7'd20, 7'd21: k = 7'd1;
            7'd22, 7'd23, 7'd24, 7'd25, 7'd26, 7'd27, 7'd28, 7'd29, 7'd30, 7'd31, 7'd32: k = 7'd2;
            7'd33, 7'd34, 7'd35, 7'd36, 7'd37, 7'd38, 7'd39, 7'd40, 7'd41, 7'd42, 7'd43: k = 7'd3;
            7'd44, 7'd45, 7'd46, 7'd47, 7'd48, 7'd49, 7'd50, 7'd51, 7'd52, 7'd53, 7'd54: k = 7'd4;
            7'd55, 7'd56, 7'd57, 7'd58, 7'd59, 7'd60, 7'd61, 7'd62, 7'd63, 7'd64, 7'd65: k = 7'd5;
            7'd66, 7'd67, 7'd68, 7'd69, 7'd70, 7'd71, 7'd72, 7'd73, 7'd74, 7'd75, 7'd76: k = 7'd6;
            7'd77, 7'd78, 7'd79, 7'd80, 7'd81, 7'd82, 7'd83, 7'd84, 7'd85, 7'd86, 7'd87: k = 7'd7;
            7'd88, 7'd89, 7'd90, 7'd91, 7'd92, 7'd93, 7'd94, 7'd95, 7'd96, 7'd97, 7'd98: k = 7'd8;
            7'd99, 7'd100: k = 7'd9;
            default: k = 7'd0;
        endcase
    end
    
    // Output min(count_8, k)
    always @(*) begin
        if (count_8 < k) begin
            result = count_8[3:0];
        end else begin
            result = k[3:0];
        end
    end
    
endmodule