module NephrenGame (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    input wire [63:0] k,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] LATCH_INPUT    = 4'd1;
    localparam [3:0] CHECK_K        = 4'd2;
    localparam [3:0] DECODE_F0      = 4'd3;
    localparam [3:0] CHECK_PREFIX   = 4'd4;
    localparam [3:0] DECODE_PREFIX  = 4'd5;
    localparam [3:0] CHECK_LEFT     = 4'd6;
    localparam [3:0] SET_LEFT       = 4'd7;
    localparam [3:0] CHECK_MIDDLE   = 4'd8;
    localparam [3:0] DECODE_MIDDLE  = 4'd9;
    localparam [3:0] CHECK_RIGHT    = 4'd10;
    localparam [3:0] SET_RIGHT      = 4'd11;
    localparam [3:0] CHECK_SUFFIX   = 4'd12;
    localparam [3:0] DECODE_SUFFIX  = 4'd13;
    localparam [3:0] OUTPUT_RESULT  = 4'd14;
    localparam [3:0] FINISH         = 4'd15;

    // Constants
    localparam [63:0] L0 = 75;
    localparam [63:0] PREFIX_LEN = 34;
    localparam [63:0] MIDDLE_LEN = 32;
    localparam [63:0] SUFFIX_LEN = 2;
    localparam [63:0] MAX_K = 64'd1000000000000000000;
    localparam [3:0] MAX_DEPTH = 15;
    localparam [15:0] CYCLE_LIMIT = 16'd1000;

    // Internal registers
    reg [3:0] state, next_state;
    reg [15:0] curr_n, next_curr_n;
    reg [63:0] curr_k, next_curr_k;
    reg [63:0] l_table [0:15];
    reg [15:0] cycle_count, next_cycle_count;
    reg start_delayed, next_start_delayed;

    // Internal wires
    wire [63:0] curr_l;
    wire [63:0] left_bound;
    wire [63:0] right_bound;
    wire [63:0] prefix_bound;
    wire [63:0] middle_bound;
    wire [63:0] suffix_bound;
    wire [15:0] next_n_sub;
    wire [63:0] next_k_sub;

    // String storage (ROMs)
    reg [7:0] f0_string [0:74];
    reg [7:0] prefix_string [0:33];
    reg [7:0] middle_string [0:31];
    reg [7:0] suffix_string [0:1];

    // Initialize string arrays (functionally equivalent to LUTs)
    initial begin
        // f_0: "What are you doing at the end of the world? Are you busy? Will you save us?"
        f0_string[0] = 8'd87; // W
        f0_string[1] = 8'd104; // h
        f0_string[2] = 8'd97; // a
        f0_string[3] = 8'd116; // t
        f0_string[4] = 8'd32; // 
        f0_string[5] = 8'd97; // a
        f0_string[6] = 8'd114; // r
        f0_string[7] = 8'd101; // e
        f0_string[8] = 8'd32; // 
        f0_string[9] = 8'd121; // y
        f0_string[10] = 8'd111; // o
        f0_string[11] = 8'd117; // u
        f0_string[12] = 8'd32; // 
        f0_string[13] = 8'd100; // d
        f0_string[14] = 8'd111; // o
        f0_string[15] = 8'd105; // i
        f0_string[16] = 8'd110; // n
        f0_string[17] = 8'd103; // g
        f0_string[18] = 8'd32; // 
        f0_string[19] = 8'd97; // a
        f0_string[20] = 8'd116; // t
        f0_string[21] = 8'd32; // 
        f0_string[22] = 8'd116; // t
        f0_string[23] = 8'd104; // h
        f0_string[24] = 8'd101; // e
        f0_string[25] = 8'd32; // 
        f0_string[26] = 8'd101; // e
        f0_string[27] = 8'd110; // n
        f0_string[28] = 8'd100; // d
        f0_string[29] = 8'd32; // 
        f0_string[30] = 8'd111; // o
        f0_string[31] = 8'd102; // f
        f0_string[32] = 8'd32; // 
        f0_string[33] = 8'd116; // t
        f0_string[34] = 8'd104; // h
        f0_string[35] = 8'd101; // e
        f0_string[36] = 8'd32; // 
        f0_string[37] = 8'd119; // w
        f0_string[38] = 8'd111; // o
        f0_string[39] = 8'd114; // r
        f0_string[40] = 8'd108; // l
        f0_string[41] = 8'd100; // d
        f0_string[42] = 8'd63; // ?
        f0_string[43] = 8'd32; // 
        f0_string[44] = 8'd65; // A
        f0_string[45] = 8'd114; // r
        f0_string[46] = 8'd101; // e
        f0_string[47] = 8'd32; // 
        f0_string[48] = 8'd121; // y
        f0_string[49] = 8'd111; // o
        f0_string[50] = 8'd117; // u
        f0_string[51] = 8'd32; // 
        f0_string[52] = 8'd98; // b
        f0_string[53] = 8'd117; // u
        f0_string[54] = 8'd115; // s
        f0_string[55] = 8'd121; // y
        f0_string[56] = 8'd63; // ?
        f0_string[57] = 8'd32; // 
        f0_string[58] = 8'd87; // W
        f0_string[59] = 8'd105; // i
        f0_string[60] = 8'd108; // l
        f0_string[61] = 8'd108; // l
        f0_string[62] = 8'd32; // 
        f0_string[63] = 8'd121; // y
        f0_string[64] = 8'd111; // o
        f0_string[65] = 8'd117; // u
        f0_string[66] = 8'd32; // 
        f0_string[67] = 8'd115; // s
        f0_string[68] = 8'd97; // a
        f0_string[69] = 8'd118; // v
        f0_string[70] = 8'd101; // e
        f0_string[71] = 8'd32; // 
        f0_string[72] = 8'd117; // u
        f0_string[73] = 8'd115; // s
        f0_string[74] = 8'd63; // ?

        // Prefix: "What are you doing while sending \""
        prefix_string[0] = 8'd87; // W
        prefix_string[1] = 8'd104; // h
        prefix_string[2] = 8'd97; // a
        prefix_string[3] = 8'd116; // t
        prefix_string[4] = 8'd32; // 
        prefix_string[5] = 8'd97; // a
        prefix_string[6] = 8'd114; // r
        prefix_string[7] = 8'd101; // e
        prefix_string[8] = 8'd32; // 
        prefix_string[9] = 8'd121; // y
        prefix_string[10] = 8'd111; // o
        prefix_string[11] = 8'd117; // u
        prefix_string[12] = 8'd32; // 
        prefix_string[13] = 8'd100; // d
        prefix_string[14] = 8'd111; // o
        prefix_string[15] = 8'd105; // i
        prefix_string[16] = 8'd110; // n
        prefix_string[17] = 8'd103; // g
        prefix_string[18] = 8'd32; // 
        prefix_string[19] = 8'd119; // w
        prefix_string[20] = 8'd104; // h
        prefix_string[21] = 8'd105; // i
        prefix_string[22] = 8'd108; // l
        prefix_string[23] = 8'd101; // e
        prefix_string[24] = 8'd32; // 
        prefix_string[25] = 8'd115; // s
        prefix_string[26] = 8'd101; // e
        prefix_string[27] = 8'd110; // n
        prefix_string[28] = 8'd100; // d
        prefix_string[29] = 8'd105; // i
        prefix_string[30] = 8'd110; // n
        prefix_string[31] = 8'd103; // g
        prefix_string[32] = 8'd32; // 
        prefix_string[33] = 8'd34; // "

        // Middle: "\"? Are you busy? Will you send \""
        middle_string[0] = 8'd34; // "
        middle_string[1] = 8'd63; // ?
        middle_string[2] = 8'd32; // 
        middle_string[3] = 8'd65; // A
        middle_string[4] = 8'd114; // r
        middle_string[5] = 8'd101; // e
        middle_string[6] = 8'd32; // 
        middle_string[7] = 8'd121; // y
        middle_string[8] = 8'd111; // o
        middle_string[9] = 8'd117; // u
        middle_string[10] = 8'd32; // 
        middle_string[11] = 8'd98; // b
        middle_string[12] = 8'd117; // u
        middle_string[13] = 8'd115; // s
        middle_string[14] = 8'd121; // y
        middle_string[15] = 8'd63; // ?
        middle_string[16] = 8'd32; // 
        middle_string[17] = 8'd87; // W
        middle_string[18] = 8'd105; // i
        middle_string[19] = 8'd108; // l
        middle_string[20] = 8'd108; // l
        middle_string[21] = 8'd32; // 
        middle_string[22] = 8'd121; // y
        middle_string[23] = 8'd111; // o
        middle_string[24] = 8'd117; // u
        middle_string[25] = 8'd32; // 
        middle_string[26] = 8'd115; // s
        middle_string[27] = 8'd101; // e
        middle_string[28] = 8'd110; // n
        middle_string[29] = 8'd100; // d
        middle_string[30] = 8'd32; // 
        middle_string[31] = 8'd34; // "

        // Suffix: "\"?"
        suffix_string[0] = 8'd34; // "
        suffix_string[1] = 8'd63; // ?
    end

    // Length Table initialization (pre-computed for n=0 to 15)
    // For n>15, we treat as saturated in logic
    initial begin
        l_table[0] = 75;
        l_table[1] = 218;
        l_table[2] = 504;
        l_table[3] = 1076;
        l_table[4] = 2220;
        l_table[5] = 4508;
        l_table[6] = 9084;
        l_table[7] = 18236;
        l_table[8] = 36540;
        l_table[9] = 73148;
        l_table[10] = 146364;
        l_table[11] = 292796;
        l_table[12] = 585660;
        l_table[13] = 1171388;
        l_table[14] = 2342852;
        l_table[15] = 4685780;
    end

    // Combinational logic for length and bounds
    assign curr_l = (curr_n > 15) ? 64'd4611686018427387904 : l_table[curr_n];
    assign prefix_bound = PREFIX_LEN;
    assign left_bound = PREFIX_LEN + curr_l;
    assign middle_bound = left_bound + MIDDLE_LEN;
    assign right_bound = middle_bound + curr_l;
    assign suffix_bound = right_bound + SUFFIX_LEN;
    assign next_n_sub = (curr_n > 0) ? curr_n - 1 : 0;
    assign next_k_sub = curr_k - PREFIX_LEN;

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            curr_n <= 16'd0;
            curr_k <= 64'd0;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            start_delayed <= 1'b0;
        end else begin
            state <= next_state;
            curr_n <= next_curr_n;
            curr_k <= next_curr_k;
            done <= (next_state == FINISH) ? 1'b1 : 1'b0;
            cycle_count <= next_cycle_count;
            start_delayed <= start;
            if (next_state == OUTPUT_RESULT) begin
                // Mux for result
                case (state)
                    DECODE_F0: result <= (curr_k > 75) ? 8'd46 : f0_string[curr_k - 1];
                    DECODE_PREFIX: result <= (curr_k > 34) ? 8'd46 : prefix_string[curr_k - 1];
                    DECODE_MIDDLE: result <= (curr_k > 32) ? 8'd46 : middle_string[curr_k - 1];
                    DECODE_SUFFIX: result <= (curr_k > 2) ? 8'd46 : suffix_string[curr_k - 1];
                    default: result <= 8'd46;
                endcase
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_curr_n = curr_n;
        next_curr_k = curr_k;
        next_cycle_count = cycle_count;

        case (state)
            IDLE: begin
                next_cycle_count = 16'd0;
                if (start && !start_delayed) begin
                    next_state = LATCH_INPUT;
                end
            end

            LATCH_INPUT: begin
                next_curr_n = n;
                next_curr_k = k;
                next_state = CHECK_K;
            end

            CHECK_K: begin
                if (curr_k == 0 || curr_k > curr_l) begin
                    next_state = OUTPUT_RESULT; // Will output '.'
                end else if (curr_n == 0) begin
                    next_state = DECODE_F0;
                end else begin
                    next_state = CHECK_PREFIX;
                end
            end

            DECODE_F0: begin
                next_state = OUTPUT_RESULT;
            end

            CHECK_PREFIX: begin
                if (curr_k <= PREFIX_LEN) begin
                    next_state = DECODE_PREFIX;
                end else begin
                    next_state = CHECK_LEFT;
                end
            end

            DECODE_PREFIX: begin
                next_state = OUTPUT_RESULT;
            end

            CHECK_LEFT: begin
                if (curr_k <= left_bound) begin
                    next_state = SET_LEFT;
                end else begin
                    next_state = CHECK_MIDDLE;
                end
            end

            SET_LEFT: begin
                next_curr_k = curr_k - PREFIX_LEN;
                next_curr_n = next_n_sub;
                next_cycle_count = cycle_count + 1;
                if (next_cycle_count >= CYCLE_LIMIT) begin
                    next_state = OUTPUT_RESULT;
                end else begin
                    next_state = CHECK_K;
                end
            end

            CHECK_MIDDLE: begin
                if (curr_k <= middle_bound) begin
                    next_state = DECODE_MIDDLE;
                end else begin
                    next_state = CHECK_RIGHT;
                end
            end

            DECODE_MIDDLE: begin
                next_state = OUTPUT_RESULT;
            end

            CHECK_RIGHT: begin
                if (curr_k <= right_bound) begin
                    next_state = SET_RIGHT;
                end else begin
                    next_state = CHECK_SUFFIX;
                end
            end

            SET_RIGHT: begin
                next_curr_k = curr_k - left_bound;
                next_curr_n = next_n_sub;
                next_cycle_count = cycle_count + 1;
                if (next_cycle_count >= CYCLE_LIMIT) begin
                    next_state = OUTPUT_RESULT;
                end else begin
                    next_state = CHECK_K;
                end
            end

            CHECK_SUFFIX: begin
                if (curr_k <= suffix_bound) begin
                    next_state = DECODE_SUFFIX;
                end else begin
                    next_state = OUTPUT_RESULT;
                end
            end

            DECODE_SUFFIX: begin
                next_state = OUTPUT_RESULT;
            end

            OUTPUT_RESULT: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule