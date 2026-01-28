module StickerMessageProcessor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire msg_valid,
    input wire [7:0] msg_data,
    input wire sticker_valid,
    input wire [63:0] sticker_data,
    output reg [31:0] result_cost,
    output reg result_valid,
    output reg impossible,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] LOAD_MSG = 4'd1;
    localparam [3:0] LOAD_STICKER = 4'd2;
    localparam [3:0] BUILD_COST = 4'd3;
    localparam [3:0] DP_PASS1 = 4'd4;
    localparam [3:0] DP_PASS2 = 4'd5;
    localparam [3:0] EXTRACT_MIN = 4'd6;
    localparam [3:0] DONE_STATE = 4'd7;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] msg_ram [0:7];
    reg [63:0] sticker_ram [0:15];
    reg [31:0] cost_lut [0:7] [0:2];
    reg [15:0] sticker_count;
    reg [7:0] msg_index;
    reg [3:0] sticker_index;
    reg [3:0] pos_index;
    reg [1:0] layer_index;
    reg [31:0] min_cost;
    reg [31:0] temp_cost;
    reg [31:0] transition_cost;
    reg [31:0] current_price;
    reg [5:0] current_start;
    reg [5:0] current_end;
    reg [31:0] current_chars;
    reg [7:0] i, j, k;
    reg [31:0] temp_min;
    reg [31:0] temp_val;
    reg [31:0] temp_val2;
    reg [31:0] temp_val3;
    reg [31:0] temp_val4;
    reg [31:0] temp_val5;
    reg [31:0] temp_val6;
    reg [31:0] temp_val7;
    reg [31:0] temp_val8;
    reg [31:0] temp_val9;
    reg [31:0] temp_val10;
    reg [31:0] temp_val11;
    reg [31:0] temp_val12;
    reg [31:0] temp_val13;
    reg [31:0] temp_val14;
    reg [31:0] temp_val15;
    reg [31:0] temp_val16;
    reg [31:0] temp_val17;
    reg [31:0] temp_val18;
    reg [31:0] temp_val19;
    reg [31:0] temp_val20;
    reg [31:0] temp_val21;
    reg [31:0] temp_val22;
    reg [31:0] temp_val23;
    reg [31:0] temp_val24;
    reg [31:0] temp_val25;
    reg [31:0] temp_val26;
    reg [31:0] temp_val27;
    reg [31:0] temp_val28;
    reg [31:0] temp_val29;
    reg [31:0] temp_val30;
    reg [31:0] temp_val31;
    reg [31:0] temp_val32;
    reg [31:0] temp_val33;
    reg [31:0] temp_val34;
    reg [31:0] temp_val35;
    reg [31:0] temp_val36;
    reg [31:0] temp_val37;
    reg [31:0] temp_val38;
    reg [31:0] temp_val39;
    reg [31:0] temp_val40;
    reg [31:0] temp_val41;
    reg [31:0] temp_val42;
    reg [31:0] temp_val43;
    reg [31:0] temp_val44;
    reg [31:0] temp_val45;
    reg [31:0] temp_val46;
    reg [31:0] temp_val47;
    reg [31:0] temp_val48;
    reg [31:0] temp_val49;
    reg [31:0] temp_val50;
    reg [31:0] temp_val51;
    reg [31:0] temp_val52;
    reg [31:0] temp_val53;
    reg [31:0] temp_val54;
    reg [31:0] temp_val55;
    reg [31:0] temp_val56;
    reg [31:0] temp_val57;
    reg [31:0] temp_val58;
    reg [31:0] temp_val59;
    reg [31:0] temp_val60;
    reg [31:0] temp_val61;
    reg [31:0] temp_val62;
    reg [31:0] temp_val63;
    reg [31:0] temp_val64;
    reg [31:0] temp_val65;
    reg [31:0] temp_val66;
    reg [31:0] temp_val67;
    reg [31:0] temp_val68;
    reg [31:0] temp_val69;
    reg [31:0] temp_val70;
    reg [31:0] temp_val71;
    reg [31:0] temp_val72;
    reg [31:0] temp_val73;
    reg [31:0] temp_val74;
    reg [31:0] temp_val75;
    reg [31:0] temp_val76;
    reg [31:0] temp_val77;
    reg [31:0] temp_val78;
    reg [31:0] temp_val79;
    reg [31:0] temp_val80;
    reg [31:0] temp_val81;
    reg [31:0] temp_val82;
    reg [31:0] temp_val83;
    reg [31:0] temp_val84;
    reg [31:0] temp_val85;
    reg [31:0] temp_val86;
    reg [31:0] temp_val87;
    reg [31:0] temp_val88;
    reg [31:0] temp_val89;
    reg [31:0] temp_val90;
    reg [31:0] temp_val91;
    reg [31:0] temp_val92;
    reg [31:0] temp_val93;
    reg [31:0] temp_val94;
    reg [31:0] temp_val95;
    reg [31:0] temp_val96;
    reg [31:0] temp_val97;
    reg [31:0] temp_val98;
    reg [31:0] temp_val99;
    reg [31:0] temp_val100;
    reg [31:0] temp_val101;
    reg [31:0] temp_val102;
    reg [31:0] temp_val103;
    reg [31:0] temp_val104;
    reg [31:0] temp_val105;
    reg [31:0] temp_val106;
    reg [31:0] temp_val107;
    reg [31:0] temp_val108;
    reg [31:0] temp_val109;
    reg [31:0] temp_val110;
    reg [31:0] temp_val111;
    reg [31:0] temp_val112;
    reg [31:0] temp_val113;
    reg [31:0] temp_val114;
    reg [31:0] temp_val115;
    reg [31:0] temp_val116;
    reg [31:0] temp_val117;
    reg [31:0] temp_val118;
    reg [31:0] temp_val119;
    reg [31:0] temp_val120;
    reg [31:0] temp_val121;
    reg [31:0] temp_val122;
    reg [31:0] temp_val123;
    reg [31:0] temp_val124;
    reg [31:0] temp_val125;
    reg [31:0] temp_val126;
    reg [31:0] temp_val127;
    reg [31:0] temp_val128;
    reg [31:0] temp_val129;
    reg [31:0] temp_val130;
    reg [31:0] temp_val131;
    reg [31:0] temp_val132;
    reg [31:0] temp_val133;
    reg [31:0] temp_val134;
    reg [31:0] temp_val135;
    reg [31:0] temp_val136;
    reg [31:0] temp_val137;
    reg [31:0] temp_val138;
    reg [31:0] temp_val139;
    reg [31:0] temp_val140;
    reg [31:0] temp_val141;
    reg [31:0] temp_val142;
    reg [31:0] temp_val143;
    reg [31:0] temp_val144;
    reg [31:0] temp_val145;
    reg [31:0] temp_val146;
    reg [31:0] temp_val147;
    reg [31:0] temp_val148;
    reg [31:0] temp_val149;
    reg [31:0] temp_val150;
    reg [31:0] temp_val151;
    reg [31:0] temp_val152;
    reg [31:0] temp_val153;
    reg [31:0] temp_val154;
    reg [31:0] temp_val155;
    reg [31:0] temp_val156;
    reg [31:0] temp_val157;
    reg [31:0] temp_val158;
    reg [31:0] temp_val159;
    reg [31:0] temp_val160;
    reg [31:0] temp_val161;
    reg [31:0] temp_val162;
    reg [31:0] temp_val163;
    reg [31:0] temp_val164;
    reg [31:0] temp_val165;
    reg [31:0] temp_val166;
    reg [31:0] temp_val167;
    reg [31:0] temp_val168;
    reg [31:0] temp_val169;
    reg [31:0] temp_val170;
    reg [31:0] temp_val171;
    reg [31:0] temp_val172;
    reg [31:0] temp_val173;
    reg [31:0] temp_val174;
    reg [31:0] temp_val175;
    reg [31:0] temp_val176;
    reg [31:0] temp_val177;
    reg [31:0] temp_val178;
    reg [31:0] temp_val179;
    reg [31:0] temp_val180;
    reg [31:0] temp_val181;
    reg [31:0] temp_val182;
    reg [31:0] temp_val183;
    reg [31:0] temp_val184;
    reg [31:0] temp_val185;
    reg [31:0] temp_val186;
    reg [31:0] temp_val187;
    reg [31:0] temp_val188;
    reg [31:0] temp_val189;
    reg [31:0] temp_val190;
    reg [31:0] temp_val191;
    reg [31:0] temp_val192;
    reg [31:0] temp_val193;
    reg [31:0] temp_val194;
    reg [31:0] temp_val195;
    reg [31:0] temp_val196;
    reg [31:0] temp_val197;
    reg [31:0] temp_val198;
    reg [31:0] temp_val199;
    reg [31:0] temp_val200;
    reg [31:0] temp_val201;
    reg [31:0] temp_val202;
    reg [31:0] temp_val203;
    reg [31:0] temp_val204;
    reg [31:0] temp_val205;
    reg [31:0] temp_val206;
    reg [31:0] temp_val207;
    reg [31:0] temp_val208;
    reg [31:0] temp_val209;
    reg [31:0] temp_val210;
    reg [31:0] temp_val211;
    reg [31:0] temp_val212;
    reg [31:0] temp_val213;
    reg [31:0] temp_val214;
    reg [31:0] temp_val215;
    reg [31:0] temp_val216;
    reg [31:0] temp_val217;
    reg [31:0] temp_val218;
    reg [31:0] temp_val219;
    reg [31:0] temp_val220;
    reg [31:0] temp_val221;
    reg [31:0] temp_val222;
    reg [31:0] temp_val223;
    reg [31:0] temp_val224;
    reg [31:0] temp_val225;
    reg [31:0] temp_val226;
    reg [31:0] temp_val227;
    reg [31:0] temp_val228;
    reg [31:0] temp_val229;
    reg [31:0] temp_val230;
    reg [31:0] temp_val231;
    reg [31:0] temp_val232;
    reg [31:0] temp_val233;
    reg [31:0] temp_val234;
    reg [31:0] temp_val235;
    reg [31:0] temp_val236;
    reg [31:0] temp_val237;
    reg [31:0] temp_val238;
    reg [31:0] temp_val239;
    reg [31:0] temp_val240;
    reg [31:0] temp_val241;
    reg [31:0] temp_val242;
    reg [31:0] temp_val243;
    reg [31:0] temp_val244;
    reg [31:0] temp_val245;
    reg [31:0] temp_val246;
    reg [31:0] temp_val247;
    reg [31:0] temp_val248;
    reg [31:0] temp_val249;
    reg [31:0] temp_val250;
    reg [31:0] temp_val251;
    reg [31:0] temp_val252;
    reg [31:0] temp_val253;
    reg [31:0] temp_val254;
    reg [31:0] temp_val255;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_cost <= 32'd0;
            result_valid <= 1'b0;
            impossible <= 1'b0;
            done <= 1'b0;
            msg_index <= 8'd0;
            sticker_index <= 4'd0;
            sticker_count <= 16'd0;
            pos_index <= 3'd0;
            layer_index <= 2'd0;
            min_cost <= 32'd0;
            temp_cost <= 32'd0;
            transition_cost <= 32'd0;
            current_price <= 32'd0;
            current_start <= 6'd0;
            current_end <= 6'd0;
            current_chars <= 32'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            temp_min <= 32'd0;
            temp_val <= 32'd0;
            temp_val2 <= 32'd0;
            temp_val3 <= 32'd0;
            temp_val4 <= 32'd0;
            temp_val5 <= 32'd0;
            temp_val6 <= 32'd0;
            temp_val7 <= 32'd0;
            temp_val8 <= 32'd0;
            temp_val9 <= 32'd0;
            temp_val10 <= 32'd0;
            temp_val11 <= 32'd0;
            temp_val12 <= 32'd0;
            temp_val13 <= 32'd0;
            temp_val14 <= 32'd0;
            temp_val15 <= 32'd0;
            temp_val16 <= 32'd0;
            temp_val17 <= 32'd0;
            temp_val18 <= 32'd0;
            temp_val19 <= 32'd0;
            temp_val20 <= 32'd0;
            temp_val21 <= 32'd0;
            temp_val22 <= 32'd0;
            temp_val23 <= 32'd0;
            temp_val24 <= 32'd0;
            temp_val25 <= 32'd0;
            temp_val26 <= 32'd0;
            temp_val27 <= 32'd0;
            temp_val28 <= 32'd0;
            temp_val29 <= 32'd0;
            temp_val30 <= 32'd0;
            temp_val31 <= 32'd0;
            temp_val32 <= 32'd0;
            temp_val33 <= 32'd0;
            temp_val34 <= 32'd0;
            temp_val35 <= 32'd0;
            temp_val36 <= 32'd0;
            temp_val37 <= 32'd0;
            temp_val38 <= 32'd0;
            temp_val39 <= 32'd0;
            temp_val40 <= 32'd0;
            temp_val41 <= 32'd0;
            temp_val42 <= 32'd0;
            temp_val43 <= 32'd0;
            temp_val44 <= 32'd0;
            temp_val45 <= 32'd0;
            temp_val46 <= 32'd0;
            temp_val47 <= 32'd0;
            temp_val48 <= 32'd0;
            temp_val49 <= 32'd0;
            temp_val50 <= 32'd0;
            temp_val51 <= 32'd0;
            temp_val52 <= 32'd0;
            temp_val53 <= 32'd0;
            temp_val54 <= 32'd0;
            temp_val55 <= 32'd0;
            temp_val56 <= 32'd0;
            temp_val57 <= 32'd0;
            temp_val58 <= 32'd0;
            temp_val59 <= 32'd0;
            temp_val60 <= 32'd0;
            temp_val61 <= 32'd0;
            temp_val62 <= 32'd0;
            temp_val63 <= 32'd0;
            temp_val64 <= 32'd0;
            temp_val65 <= 32'd0;
            temp_val66 <= 32'd0;
            temp_val67 <= 32'd0;
            temp_val68 <= 32'd0;
            temp_val69 <= 32'd0;
            temp_val70 <= 32'd0;
            temp_val71 <= 32'd0;
            temp_val72 <= 32'd0;
            temp_val73 <= 32'd0;
            temp_val74 <= 32'd0;
            temp_val75 <= 32'd0;
            temp_val76 <= 32'd0;
            temp_val77 <= 32'd0;
            temp_val78 <= 32'd0;
            temp_val79 <= 32'd0;
            temp_val80 <= 32'd0;
            temp_val81 <= 32'd0;
            temp_val82 <= 32'd0;
            temp_val83 <= 32'd0;
            temp_val84 <= 32'd0;
            temp_val85 <= 32'd0;
            temp_val86 <= 32'd0;
            temp_val87 <= 32'd0;
            temp_val88 <= 32'd0;
            temp_val89 <= 32'd0;
            temp_val90 <= 32'd0;
            temp_val91 <= 32'd0;
            temp_val92 <= 32'd0;
            temp_val93 <= 32'd0;
            temp_val94 <= 32'd0;
            temp_val95 <= 32'd0;
            temp_val96 <= 32'd0;
            temp_val97 <= 32'd0;
            temp_val98 <= 32'd0;
            temp_val99 <= 32'd0;
            temp_val100 <= 32'd0;
            temp_val101 <= 32'd0;
            temp_val102 <= 32'd0;
            temp_val103 <= 32'd0;
            temp_val104 <= 32'd0;
            temp_val105 <= 32'd0;
            temp_val106 <= 32'd0;
            temp_val107 <= 32'd0;
            temp_val108 <= 32'd0;
            temp_val109 <= 32'd0;
            temp_val110 <= 32'd0;
            temp_val111 <= 32'd0;
            temp_val112 <= 32'd0;
            temp_val113 <= 32'd0;
            temp_val114 <= 32'd0;
            temp_val115 <= 32'd0;
            temp_val116 <= 32'd0;
            temp_val117 <= 32'd0;
            temp_val118 <= 32'd0;
            temp_val119 <= 32'd0;
            temp_val120 <= 32'd0;
            temp_val121 <= 32'd0;
            temp_val122 <= 32'd0;
            temp_val123 <= 32'd0;
            temp_val124 <= 32'd0;
            temp_val125 <= 32'd0;
            temp_val126 <= 32'd0;
            temp_val127 <= 32'd0;
            temp_val128 <= 32'd0;
            temp_val129 <= 32'd0;
            temp_val130 <= 32'd0;
            temp_val131 <= 32'd0;
            temp_val132 <= 32'd0;
            temp_val133 <= 32'd0;
            temp_val134 <= 32'd0;
            temp_val135 <= 32'd0;
            temp_val136 <= 32'd0;
            temp_val137 <= 32'd0;
            temp_val138 <= 32'd0;
            temp_val139 <= 32'd0;
            temp_val140 <= 32'd0;
            temp_val141 <= 32'd0;
            temp_val142 <= 32'd0;
            temp_val143 <= 32'd0;
            temp_val144 <= 32'd0;
            temp_val145 <= 32'd0;
            temp_val146 <= 32'd0;
            temp_val147 <= 32'd0;
            temp_val148 <= 32'd0;
            temp_val149 <= 32'd0;
            temp_val150 <= 32'd0;
            temp_val151 <= 32'd0;
            temp_val152 <= 32'd0;
            temp_val153 <= 32'd0;
            temp_val154 <= 32'd0;
            temp_val155 <= 32'd0;
            temp_val156 <= 32'd0;
            temp_val157 <= 32'd0;
            temp_val158 <= 32'd0;
            temp_val159 <= 32'd0;
            temp_val160 <= 32'd0;
            temp_val161 <= 32'd0;
            temp_val162 <= 32'd0;
            temp_val163 <= 32'd0;
            temp_val164 <= 32'd0;
            temp_val165 <= 32'd0;
            temp_val166 <= 32'd0;
            temp_val167 <= 32'd0;
            temp_val168 <= 32'd0;
            temp_val169 <= 32'd0;
            temp_val170 <= 32'd0;
            temp_val171 <= 32'd0;
            temp_val172 <= 32'd0;
            temp_val173 <= 32'd0;
            temp_val174 <= 32'd0;
            temp_val175 <= 32'd0;
            temp_val176 <= 32'd0;
            temp_val177 <= 32'd0;
            temp_val178 <= 32'd0;
            temp_val179 <= 32'd0;
            temp_val180 <= 32'd0;
            temp_val181 <= 32'd0;
            temp_val182 <= 32'd0;
            temp_val183 <= 32'd0;
            temp_val184 <= 32'd0;
            temp_val185 <= 32'd0;
            temp_val186 <= 32'd0;
            temp_val187 <= 32'd0;
            temp_val188 <= 32'd0;
            temp_val189 <= 32'd0;
            temp_val190 <= 32'd0;
            temp_val191 <= 32'd0;
            temp_val192 <= 32'd0;
            temp_val193 <= 32'd0;
            temp_val194 <= 32'd0;
            temp_val195 <= 32'd0;
            temp_val196 <= 32'd0;
            temp_val197 <= 32'd0;
            temp_val198 <= 32'd0;
            temp_val199 <= 32'd0;
            temp_val200 <= 32'd0;
            temp_val201 <= 32'd0;
            temp_val202 <= 32'd0;
            temp_val203 <= 32'd0;
            temp_val204 <= 32'd0;
            temp_val205 <= 32'd0;
            temp_val206 <= 32'd0;
            temp_val207 <= 32'd0;
            temp_val208 <= 32'd0;
            temp_val209 <= 32'd0;
            temp_val210 <= 32'd0;
            temp_val211 <= 32'd0;
            temp_val212 <= 32'd0;
            temp_val213 <= 32'd0;
            temp_val214 <= 32'd0;
            temp_val215 <= 32'd0;
            temp_val216 <= 32'd0;
            temp_val217 <= 32'd0;
            temp_val218 <= 32'd0;
            temp_val219 <= 32'd0;
            temp_val220 <= 32'd0;
            temp_val221 <= 32'd0;
            temp_val222 <= 32'd0;
            temp_val223 <= 32'd0;
            temp_val224 <= 32'd0;
            temp_val225 <= 32'd0;
            temp_val226 <= 32'd0;
            temp_val227 <= 32'd0;
            temp_val228 <= 32'd0;
            temp_val229 <= 32'd0;
            temp_val230 <= 32'd0;
            temp_val231 <= 32'd0;
            temp_val232 <= 32'd0;
            temp_val233 <= 32'd0;
            temp_val234 <= 32'd0;
            temp_val235 <= 32'd0;
            temp_val236 <= 32'd0;
            temp_val237 <= 32'd0;
            temp_val238 <= 32'd0;
            temp_val239 <= 32'd0;
            temp_val240 <= 32'd0;
            temp_val241 <= 32'd0;
            temp_val242 <= 32'd0;
            temp_val243 <= 32'd0;
            temp_val244 <= 32'd0;
            temp_val245 <= 32'd0;
            temp_val246 <= 32'd0;
            temp_val247 <= 32'd0;
            temp_val248 <= 32'd0;
            temp_val249 <= 32'd0;
            temp_val250 <= 32'd0;
            temp_val251 <= 32'd0;
            temp_val252 <= 32'd0;
            temp_val253 <= 32'd0;
            temp_val254 <= 32'd0;
            temp_val255 <= 32'd0;
            for (i = 0; i < 8; i = i + 1) begin
                msg_ram[i] <= 8'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                sticker_ram[i] <= 64'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                for (j = 0; j < 3; j = j + 1) begin
                    cost_lut[i][j] <= 32'd0;
                end
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_MSG;
                end
            end
            LOAD_MSG: begin
                if (msg_index == 8'd7 && msg_valid) begin
                    next_state = LOAD_STICKER;
                end
            end
            LOAD_STICKER: begin
                if (sticker_index == 4'd15 || (sticker_count == 16'd0 && !sticker_valid)) begin
                    next_state = BUILD_COST;
                end
            end
            BUILD_COST: begin
                if (pos_index == 3'd7 && layer_index == 2'd2) begin
                    next_state = DP_PASS1;
                end
            end
            DP_PASS1: begin
                if (pos_index == 3'd7 && layer_index == 2'd2) begin
                    next_state = DP_PASS2;
                end
            end
            DP_PASS2: begin
                if (pos_index == 3'd7 && layer_index == 2'd2) begin
                    next_state = EXTRACT_MIN;
                end
            end
            EXTRACT_MIN: begin
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Message loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            msg_index <= 8'd0;
        end else if (state == LOAD_MSG && msg_valid) begin
            msg_ram[msg_index] <= msg_data;
            msg_index <= msg_index + 8'd1;
        end
    end

    // Sticker loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sticker_index <= 4'd0;
            sticker_count <= 16'd0;
        end else if (state == LOAD_STICKER && sticker_valid) begin
            sticker_ram[sticker_index] <= sticker_data;
            sticker_index <= sticker_index + 4'd1;
            sticker_count <= sticker_count + 16'd1;
        end
    end

    // Cost matrix building
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_index <= 3'd0;
            layer_index <= 2'd0;
        end else if (state == BUILD_COST) begin
            // Initialize cost matrix
            if (pos_index == 3'd0 && layer_index == 2'd0) begin
                cost_lut[0][0] <= 32'd0;
                cost_lut[0][1] <= 32'd0;
                cost_lut[0][2] <= 32'd0;
            end
            // Compute costs for each position and layer
            if (pos_index < 3'd7) begin
                if (layer_index < 2'd2) begin
                    // Compute transition cost
                    transition_cost <= 32'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (sticker_ram[i] != 64'd0) begin
                            current_start <= sticker_ram[i][63:58];
                            current_end <= sticker_ram[i][57:52];
                            current_price <= {16'd0, sticker_ram[i][51:36]};
                            current_chars <= sticker_ram[i][35:4];
                            if (current_start == pos_index && current_end <= 8'd7) begin
                                // Check if sticker matches message
                                temp_val <= 1'b1;
                                for (j = 0; j < 6; j = j + 1) begin
                                    if (current_chars[j*8 +: 8] != msg_ram[current_start + j]) begin
                                        temp_val <= 1'b0;
                                    end
                                end
                                if (temp_val) begin
                                    transition_cost <= transition_cost + current_price;
                                end
                            end
                        end
                    end
                    // Update cost matrix
                    if (pos_index == 3'd0) begin
                        cost_lut[pos_index + 1'd1][layer_index] <= transition_cost;
                    end else begin
                        temp_min <= 32'd0;
                        for (k = 0; k < 3; k = k + 1) begin
                            if (cost_lut[pos_index][k] + transition_cost < temp_min) begin
                                temp_min <= cost_lut[pos_index][k] + transition_cost;
                            end
                        end
                        cost_lut[pos_index + 1'd1][layer_index] <= temp_min;
                    end
                    layer_index <= layer_index + 2'd1;
                end else begin
                    layer_index <= 2'd0;
                    pos_index <= pos_index + 3'd1;
                end
            end else begin
                pos_index <= 3'd0;
                layer_index <= 2'd0;
            end
        end
    end

    // DP Pass 1 (Layer 0)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_index <= 3'd0;
            layer_index <= 2'd0;
        end else if (state == DP_PASS1) begin
            if (pos_index < 3'd7) begin
                if (layer_index < 2'd1) begin
                    // Compute transition cost for layer 0
                    transition_cost <= 32'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (sticker_ram[i] != 64'd0) begin
                            current_start <= sticker_ram[i][63:58];
                            current_end <= sticker_ram[i][57:52];
                            current_price <= {16'd0, sticker_ram[i][51:36]};
                            current_chars <= sticker_ram[i][35:4];
                            if (current_start == pos_index && current_end <= 8'd7) begin
                                // Check if sticker matches message
                                temp_val <= 1'b1;
                                for (j = 0; j < 6; j = j + 1) begin
                                    if (current_chars[j*8 +: 8] != msg_ram[current_start + j]) begin
                                        temp_val <= 1'b0;
                                    end
                                end
                                if (temp_val) begin
                                    transition_cost <= transition_cost + current_price;
                                end
                            end
                        end
                    end
                    // Update cost matrix for layer 0
                    if (pos_index == 3'd0) begin
                        cost_lut[pos_index + 1'd1][0] <= transition_cost;
                    end else begin
                        temp_min <= 32'd0;
                        for (k = 0; k < 3; k = k + 1) begin
                            if (cost_lut[pos_index][k] + transition_cost < temp_min) begin
                                temp_min <= cost_lut[pos_index][k] + transition_cost;
                            end
                        end
                        cost_lut[pos_index + 1'd1][0] <= temp_min;
                    end
                    layer_index <= layer_index + 2'd1;
                end else begin
                    layer_index <= 2'd0;
                    pos_index <= pos_index + 3'd1;
                end
            end else begin
                pos_index <= 3'd0;
                layer_index <= 2'd0;
            end
        end
    end

    // DP Pass 2 (Layer 1 with overlap check)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_index <= 3'd0;
            layer_index <= 2'd0;
        end else if (state == DP_PASS2) begin
            if (pos_index < 3'd7) begin
                if (layer_index < 2'd2) begin
                    // Compute transition cost for layer 1
                    transition_cost <= 32'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (sticker_ram[i] != 64'd0) begin
                            current_start <= sticker_ram[i][63:58];
                            current_end <= sticker_ram[i][57:52];
                            current_price <= {16'd0, sticker_ram[i][51:36]};
                            current_chars <= sticker_ram[i][35:4];
                            if (current_start == pos_index && current_end <= 8'd7) begin
                                // Check if sticker matches message
                                temp_val <= 1'b1;
                                for (j = 0; j < 6; j = j + 1) begin
                                    if (current_chars[j*8 +: 8] != msg_ram[current_start + j]) begin
                                        temp_val <= 1'b0;
                                    end
                                end
                                if (temp_val) begin
                                    transition_cost <= transition_cost + current_price;
                                end
                            end
                        end
                    end
                    // Update cost matrix for layer 1
                    if (pos_index == 3'd0) begin
                        cost_lut[pos_index + 1'd1][1] <= transition_cost;
                    end else begin
                        temp_min <= 32'd0;
                        for (k = 0; k < 3; k = k + 1) begin
                            if (cost_lut[pos_index][k] + transition_cost < temp_min) begin
                                temp_min <= cost_lut[pos_index][k] + transition_cost;
                            end
                        end
                        cost_lut[pos_index + 1'd1][1] <= temp_min;
                    end
                    layer_index <= layer_index + 2'd1;
                end else begin
                    layer_index <= 2'd0;
                    pos_index <= pos_index + 3'd1;
                end
            end else begin
                pos_index <= 3'd0;
                layer_index <= 2'd0;
            end
        end
    end

    // Extract minimum cost
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_cost <= 32'd0;
        end else if (state == EXTRACT_MIN) begin
            min_cost <= cost_lut[7][0];
            if (cost_lut[7][1] < min_cost) begin
                min_cost <= cost_lut[7][1];
            end
            if (cost_lut[7][2] < min_cost) begin
                min_cost <= cost_lut[7][2];
            end
            if (min_cost == 32'd0) begin
                impossible <= 1'b1;
            end else begin
                impossible <= 1'b0;
            end
            result_cost <= min_cost;
            result_valid <= 1'b1;
            done <= 1'b1;
        end else begin
            result_valid <= 1'b0;
            done <= 1'b0;
        end
    end

endmodule