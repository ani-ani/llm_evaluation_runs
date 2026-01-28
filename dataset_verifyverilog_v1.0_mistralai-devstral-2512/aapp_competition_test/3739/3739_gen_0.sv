module GoldbachChecker(
    input clk,
    input rst_n,
    input start,
    input input_valid,
    input [7:0] char_in,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] WAIT_FOR_NUM = 3'd1;
    localparam [2:0] IN_NUM = 3'd2;
    localparam [2:0] CHECK_EOF = 3'd3;
    localparam [2:0] VALIDATE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // Parsing registers
    reg [31:0] int_n, int_p, int_q;
    reg [31:0] current_num;
    reg [3:0] num_count;
    reg [3:0] digit_count;
    reg [31:0] prime_p, prime_q;

    // Prime check registers
    reg [31:0] divisor_p, divisor_q;
    reg [15:0] prime_index;
    reg p_is_prime, q_is_prime;
    reg p_prime_done, q_prime_done;

    // Small prime LUT (first 168 primes up to 1000)
    reg [31:0] prime_lut [0:167];
    integer i;

    // Initialize prime LUT
    initial begin
        prime_lut[0] = 32'd2;
        prime_lut[1] = 32'd3;
        prime_lut[2] = 32'd5;
        prime_lut[3] = 32'd7;
        prime_lut[4] = 32'd11;
        prime_lut[5] = 32'd13;
        prime_lut[6] = 32'd17;
        prime_lut[7] = 32'd19;
        prime_lut[8] = 32'd23;
        prime_lut[9] = 32'd29;
        prime_lut[10] = 32'd31;
        prime_lut[11] = 32'd37;
        prime_lut[12] = 32'd41;
        prime_lut[13] = 32'd43;
        prime_lut[14] = 32'd47;
        prime_lut[15] = 32'd53;
        prime_lut[16] = 32'd59;
        prime_lut[17] = 32'd61;
        prime_lut[18] = 32'd67;
        prime_lut[19] = 32'd71;
        prime_lut[20] = 32'd73;
        prime_lut[21] = 32'd79;
        prime_lut[22] = 32'd83;
        prime_lut[23] = 32'd89;
        prime_lut[24] = 32'd97;
        prime_lut[25] = 32'd101;
        prime_lut[26] = 32'd103;
        prime_lut[27] = 32'd107;
        prime_lut[28] = 32'd109;
        prime_lut[29] = 32'd113;
        prime_lut[30] = 32'd127;
        prime_lut[31] = 32'd131;
        prime_lut[32] = 32'd137;
        prime_lut[33] = 32'd139;
        prime_lut[34] = 32'd149;
        prime_lut[35] = 32'd151;
        prime_lut[36] = 32'd157;
        prime_lut[37] = 32'd163;
        prime_lut[38] = 32'd167;
        prime_lut[39] = 32'd173;
        prime_lut[40] = 32'd179;
        prime_lut[41] = 32'd181;
        prime_lut[42] = 32'd191;
        prime_lut[43] = 32'd193;
        prime_lut[44] = 32'd197;
        prime_lut[45] = 32'd199;
        prime_lut[46] = 32'd211;
        prime_lut[47] = 32'd223;
        prime_lut[48] = 32'd227;
        prime_lut[49] = 32'd229;
        prime_lut[50] = 32'd233;
        prime_lut[51] = 32'd239;
        prime_lut[52] = 32'd241;
        prime_lut[53] = 32'd251;
        prime_lut[54] = 32'd257;
        prime_lut[55] = 32'd263;
        prime_lut[56] = 32'd269;
        prime_lut[57] = 32'd271;
        prime_lut[58] = 32'd277;
        prime_lut[59] = 32'd281;
        prime_lut[60] = 32'd283;
        prime_lut[61] = 32'd293;
        prime_lut[62] = 32'd307;
        prime_lut[63] = 32'd311;
        prime_lut[64] = 32'd313;
        prime_lut[65] = 32'd317;
        prime_lut[66] = 32'd331;
        prime_lut[67] = 32'd337;
        prime_lut[68] = 32'd347;
        prime_lut[69] = 32'd349;
        prime_lut[70] = 32'd353;
        prime_lut[71] = 32'd359;
        prime_lut[72] = 32'd367;
        prime_lut[73] = 32'd373;
        prime_lut[74] = 32'd379;
        prime_lut[75] = 32'd383;
        prime_lut[76] = 32'd389;
        prime_lut[77] = 32'd397;
        prime_lut[78] = 32'd401;
        prime_lut[79] = 32'd409;
        prime_lut[80] = 32'd419;
        prime_lut[81] = 32'd421;
        prime_lut[82] = 32'd431;
        prime_lut[83] = 32'd433;
        prime_lut[84] = 32'd439;
        prime_lut[85] = 32'd443;
        prime_lut[86] = 32'd449;
        prime_lut[87] = 32'd457;
        prime_lut[88] = 32'd461;
        prime_lut[89] = 32'd463;
        prime_lut[90] = 32'd467;
        prime_lut[91] = 32'd479;
        prime_lut[92] = 32'd487;
        prime_lut[93] = 32'd491;
        prime_lut[94] = 32'd499;
        prime_lut[95] = 32'd503;
        prime_lut[96] = 32'd509;
        prime_lut[97] = 32'd521;
        prime_lut[98] = 32'd523;
        prime_lut[99] = 32'd541;
        prime_lut[100] = 32'd547;
        prime_lut[101] = 32'd557;
        prime_lut[102] = 32'd563;
        prime_lut[103] = 32'd569;
        prime_lut[104] = 32'd571;
        prime_lut[105] = 32'd577;
        prime_lut[106] = 32'd587;
        prime_lut[107] = 32'd593;
        prime_lut[108] = 32'd599;
        prime_lut[109] = 32'd601;
        prime_lut[110] = 32'd607;
        prime_lut[111] = 32'd613;
        prime_lut[112] = 32'd617;
        prime_lut[113] = 32'd619;
        prime_lut[114] = 32'd631;
        prime_lut[115] = 32'd641;
        prime_lut[116] = 32'd643;
        prime_lut[117] = 32'd647;
        prime_lut[118] = 32'd653;
        prime_lut[119] = 32'd659;
        prime_lut[120] = 32'd661;
        prime_lut[121] = 32'd673;
        prime_lut[122] = 32'd677;
        prime_lut[123] = 32'd683;
        prime_lut[124] = 32'd691;
        prime_lut[125] = 32'd701;
        prime_lut[126] = 32'd709;
        prime_lut[127] = 32'd719;
        prime_lut[128] = 32'd727;
        prime_lut[129] = 32'd733;
        prime_lut[130] = 32'd739;
        prime_lut[131] = 32'd743;
        prime_lut[132] = 32'd751;
        prime_lut[133] = 32'd757;
        prime_lut[134] = 32'd761;
        prime_lut[135] = 32'd769;
        prime_lut[136] = 32'd773;
        prime_lut[137] = 32'd787;
        prime_lut[138] = 32'd797;
        prime_lut[139] = 32'd809;
        prime_lut[140] = 32'd811;
        prime_lut[141] = 32'd821;
        prime_lut[142] = 32'd823;
        prime_lut[143] = 32'd827;
        prime_lut[144] = 32'd829;
        prime_lut[145] = 32'd839;
        prime_lut[146] = 32'd853;
        prime_lut[147] = 32'd857;
        prime_lut[148] = 32'd859;
        prime_lut[149] = 32'd863;
        prime_lut[150] = 32'd877;
        prime_lut[151] = 32'd881;
        prime_lut[152] = 32'd883;
        prime_lut[153] = 32'd887;
        prime_lut[154] = 32'd907;
        prime_lut[155] = 32'd911;
        prime_lut[156] = 32'd919;
        prime_lut[157] = 32'd929;
        prime_lut[158] = 32'd937;
        prime_lut[159] = 32'd941;
        prime_lut[160] = 32'd947;
        prime_lut[161] = 32'd953;
        prime_lut[162] = 32'd967;
        prime_lut[163] = 32'd971;
        prime_lut[164] = 32'd977;
        prime_lut[165] = 32'd983;
        prime_lut[166] = 32'd991;
        prime_lut[167] = 32'd997;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            int_n <= 32'd0;
            int_p <= 32'd0;
            int_q <= 32'd0;
            current_num <= 32'd0;
            num_count <= 4'd0;
            digit_count <= 4'd0;
            prime_p <= 32'd0;
            prime_q <= 32'd0;
            divisor_p <= 32'd0;
            divisor_q <= 32'd0;
            prime_index <= 16'd0;
            p_is_prime <= 1'b0;
            q_is_prime <= 1'b0;
            p_prime_done <= 1'b0;
            q_prime_done <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
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
                    next_state = WAIT_FOR_NUM;
                    num_count = 4'd0;
                    digit_count = 4'd0;
                    current_num = 32'd0;
                    result = 1'b0;
                    done = 1'b0;
                end
            end
            WAIT_FOR_NUM: begin
                if (input_valid) begin
                    if (char_in == 8'd10 || char_in == 8'd32 || char_in == 8'd9) begin
                        // Stay in WAIT_FOR_NUM
                    end else if (char_in >= 8'd48 && char_in <= 8'd57) begin
                        if (char_in == 8'd48 && digit_count == 4'd0) begin
                            // Leading zero - invalid
                            next_state = CHECK_EOF;
                        end else begin
                            next_state = IN_NUM;
                            digit_count = 4'd1;
                            current_num = char_in - 8'd48;
                        end
                    end else begin
                        // Invalid character
                        next_state = CHECK_EOF;
                    end
                end
            end
            IN_NUM: begin
                if (input_valid) begin
                    if (char_in >= 8'd48 && char_in <= 8'd57) begin
                        digit_count = digit_count + 4'd1;
                        if (digit_count <= 4'd10) begin
                            current_num = current_num * 10 + (char_in - 8'd48);
                            if (current_num > 32'd1000000000) begin
                                // Overflow - invalid
                                next_state = CHECK_EOF;
                            end
                        end else begin
                            // Too many digits - invalid
                            next_state = CHECK_EOF;
                        end
                    end else if (char_in == 8'd10 || char_in == 8'd32 || char_in == 8'd9) begin
                        // End of number
                        num_count = num_count + 4'd1;
                        case (num_count)
                            4'd1: int_n = current_num;
                            4'd2: int_p = current_num;
                            4'd3: int_q = current_num;
                            default: begin end
                        endcase
                        digit_count = 4'd0;
                        current_num = 32'd0;
                        if (num_count == 4'd3) begin
                            next_state = CHECK_EOF;
                        end else begin
                            next_state = WAIT_FOR_NUM;
                        end
                    end else begin
                        // Invalid character
                        next_state = CHECK_EOF;
                    end
                end
            end
            CHECK_EOF: begin
                if (!input_valid) begin
                    if (num_count == 4'd3) begin
                        next_state = VALIDATE;
                    end else begin
                        next_state = DONE_STATE;
                        result = 1'b0;
                    end
                end
            end
            VALIDATE: begin
                if (!p_prime_done) begin
                    // Prime check for P
                    if (prime_index < 16'd168) begin
                        divisor_p = prime_lut[prime_index];
                        if (divisor_p * divisor_p > int_p) begin
                            p_is_prime = 1'b1;
                            p_prime_done = 1'b1;
                            prime_index = 16'd0;
                        end else if (int_p % divisor_p == 32'd0) begin
                            p_is_prime = 1'b0;
                            p_prime_done = 1'b1;
                            prime_index = 16'd0;
                        end else begin
                            prime_index = prime_index + 16'd1;
                        end
                    end else begin
                        p_is_prime = 1'b1;
                        p_prime_done = 1'b1;
                        prime_index = 16'd0;
                    end
                end else if (!q_prime_done) begin
                    // Prime check for Q
                    if (prime_index < 16'd168) begin
                        divisor_q = prime_lut[prime_index];
                        if (divisor_q * divisor_q > int_q) begin
                            q_is_prime = 1'b1;
                            q_prime_done = 1'b1;
                            prime_index = 16'd0;
                        end else if (int_q % divisor_q == 32'd0) begin
                            q_is_prime = 1'b0;
                            q_prime_done = 1'b1;
                            prime_index = 16'd0;
                        end else begin
                            prime_index = prime_index + 16'd1;
                        end
                    end else begin
                        q_is_prime = 1'b1;
                        q_prime_done = 1'b1;
                        prime_index = 16'd0;
                    end
                end else begin
                    // Final validation
                    if (int_n > 32'd3 && int_n[0] == 1'b0 && int_p > 32'd1 && int_q > 32'd1 && 
                        (int_p + int_q) == int_n && p_is_prime && q_is_prime) begin
                        result = 1'b1;
                    end else begin
                        result = 1'b0;
                    end
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
                done = 1'b1;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule