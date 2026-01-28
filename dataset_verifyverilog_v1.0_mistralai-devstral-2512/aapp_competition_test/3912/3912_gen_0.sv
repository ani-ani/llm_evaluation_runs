module PalindromePartition(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] char_in,
    output reg [255:0] result,
    output reg done,
    output reg [3:0] k_out
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COUNT   = 3'd1;
    localparam [2:0] CHECK   = 3'd2;
    localparam [2:0] BUILD   = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Character counting
    reg [5:0] char_index;
    reg [5:0] char_count [0:61];
    reg [5:0] odd_count;

    // Partition parameters
    reg [3:0] k;
    reg [3:0] L;
    reg [3:0] k_temp;
    reg [3:0] L_temp;

    // Result construction
    reg [7:0] char_temp;
    reg [7:0] char_map [0:61];
    reg [7:0] char_list [0:15];
    reg [7:0] palindrome [0:15];
    reg [7:0] palindrome_temp [0:15];
    reg [7:0] center_chars [0:15];
    reg [3:0] center_index;
    reg [3:0] pal_index;
    reg [3:0] char_pos;
    reg [3:0] half_L;
    reg [3:0] center_pos;
    reg [3:0] build_index;

    // Initialize character map
    integer i;
    initial begin
        char_map[0] = 8'd48;  // '0'
        char_map[1] = 8'd49;  // '1'
        char_map[2] = 8'd50;  // '2'
        char_map[3] = 8'd51;  // '3'
        char_map[4] = 8'd52;  // '4'
        char_map[5] = 8'd53;  // '5'
        char_map[6] = 8'd54;  // '6'
        char_map[7] = 8'd55;  // '7'
        char_map[8] = 8'd56;  // '8'
        char_map[9] = 8'd57;  // '9'
        char_map[10] = 8'd65; // 'A'
        char_map[11] = 8'd66; // 'B'
        char_map[12] = 8'd67; // 'C'
        char_map[13] = 8'd68; // 'D'
        char_map[14] = 8'd69; // 'E'
        char_map[15] = 8'd70; // 'F'
        char_map[16] = 8'd71; // 'G'
        char_map[17] = 8'd72; // 'H'
        char_map[18] = 8'd73; // 'I'
        char_map[19] = 8'd74; // 'J'
        char_map[20] = 8'd75; // 'K'
        char_map[21] = 8'd76; // 'L'
        char_map[22] = 8'd77; // 'M'
        char_map[23] = 8'd78; // 'N'
        char_map[24] = 8'd79; // 'O'
        char_map[25] = 8'd80; // 'P'
        char_map[26] = 8'd81; // 'Q'
        char_map[27] = 8'd82; // 'R'
        char_map[28] = 8'd83; // 'S'
        char_map[29] = 8'd84; // 'T'
        char_map[30] = 8'd85; // 'U'
        char_map[31] = 8'd86; // 'V'
        char_map[32] = 8'd87; // 'W'
        char_map[33] = 8'd88; // 'X'
        char_map[34] = 8'd89; // 'Y'
        char_map[35] = 8'd90; // 'Z'
        char_map[36] = 8'd97; // 'a'
        char_map[37] = 8'd98; // 'b'
        char_map[38] = 8'd99; // 'c'
        char_map[39] = 8'd100; // 'd'
        char_map[40] = 8'd101; // 'e'
        char_map[41] = 8'd102; // 'f'
        char_map[42] = 8'd103; // 'g'
        char_map[43] = 8'd104; // 'h'
        char_map[44] = 8'd105; // 'i'
        char_map[45] = 8'd106; // 'j'
        char_map[46] = 8'd107; // 'k'
        char_map[47] = 8'd108; // 'l'
        char_map[48] = 8'd109; // 'm'
        char_map[49] = 8'd110; // 'n'
        char_map[50] = 8'd111; // 'o'
        char_map[51] = 8'd112; // 'p'
        char_map[52] = 8'd113; // 'q'
        char_map[53] = 8'd114; // 'r'
        char_map[54] = 8'd115; // 's'
        char_map[55] = 8'd116; // 't'
        char_map[56] = 8'd117; // 'u'
        char_map[57] = 8'd118; // 'v'
        char_map[58] = 8'd119; // 'w'
        char_map[59] = 8'd120; // 'x'
        char_map[60] = 8'd121; // 'y'
        char_map[61] = 8'd122; // 'z'
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 256'd0;
            done <= 1'b0;
            k_out <= 4'd0;
            cycle_count <= 8'd0;
            char_index <= 6'd0;
            for (i = 0; i < 62; i = i + 1) begin
                char_count[i] <= 6'd0;
            end
            odd_count <= 6'd0;
            k <= 4'd0;
            L <= 4'd0;
            k_temp <= 4'd0;
            L_temp <= 4'd0;
            char_pos <= 4'd0;
            half_L <= 4'd0;
            center_pos <= 4'd0;
            build_index <= 4'd0;
            pal_index <= 4'd0;
            center_index <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                char_list[i] <= 8'd0;
                palindrome[i] <= 8'd0;
                palindrome_temp[i] <= 8'd0;
                center_chars[i] <= 8'd0;
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
                    next_state = COUNT;
                end
            end
            COUNT: begin
                if (char_index == 6'd15) begin
                    next_state = CHECK;
                end
            end
            CHECK: begin
                if (k_temp == 4'd16) begin
                    next_state = BUILD;
                end
            end
            BUILD: begin
                if (build_index == 4'd15) begin
                    next_state = DONE_STATE;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Character counting
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            char_index <= 6'd0;
        end else if (state == COUNT) begin
            if (char_index < 6'd16) begin
                char_temp = char_in[char_index*8 +: 8];
                for (i = 0; i < 62; i = i + 1) begin
                    if (char_temp == char_map[i]) begin
                        char_count[i] <= char_count[i] + 6'd1;
                    end
                end
                char_index <= char_index + 6'd1;
            end
        end
    end

    // Odd count calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            odd_count <= 6'd0;
        end else if (state == COUNT && char_index == 6'd15) begin
            odd_count = 6'd0;
            for (i = 0; i < 62; i = i + 1) begin
                if (char_count[i][0] == 1'b1) begin
                    odd_count <= odd_count + 6'd1;
                end
            end
        end
    end

    // Partition search
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            k_temp <= 4'd0;
            L_temp <= 4'd0;
        end else if (state == CHECK) begin
            if (k_temp < 4'd16) begin
                L_temp = 4'd16 / (k_temp + 4'd1);
                if ((L_temp * (k_temp + 4'd1)) == 4'd16) begin
                    if (L_temp[0] == 1'b0) begin
                        if (odd_count == 6'd0) begin
                            k <= k_temp + 4'd1;
                            L <= L_temp;
                        end
                    end else begin
                        if (odd_count <= (k_temp + 4'd1) && ((k_temp + 4'd1 - odd_count) % 2 == 0)) begin
                            k <= k_temp + 4'd1;
                            L <= L_temp;
                        end
                    end
                end
                k_temp <= k_temp + 4'd1;
            end
        end
    end

    // Result construction
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            build_index <= 4'd0;
            pal_index <= 4'd0;
            char_pos <= 4'd0;
            half_L <= 4'd0;
            center_pos <= 4'd0;
            center_index <= 4'd0;
        end else if (state == BUILD) begin
            if (build_index < 4'd16) begin
                if (char_pos < L) begin
                    if (char_pos < half_L) begin
                        palindrome_temp[char_pos] = palindrome_temp[L - char_pos - 4'd1];
                    char_pos <= char_pos + 4'd1;
                    if (char_pos == half_L) begin
                        if (L[0] == 1'b1) begin
                            palindrome_temp[half_L] = center_chars[center_index];
                            center_index <= center_index + 4'd1;
                        end
                    end
                end else begin
                    for (i = 0; i < L; i = i + 1) begin
                        palindrome[pal_index*L + i] = palindrome_temp[i];
                    end
                    pal_index <= pal_index + 4'd1;
                    char_pos <= 4'd0;
                    half_L <= 4'd0;
                    center_pos <= 4'd0;
                end
                build_index <= build_index + 4'd1;
            end
        end
    end

    // Pack result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 256'd0;
        end else if (state == BUILD && build_index == 4'd15) begin
            for (i = 0; i < 16; i = i + 1) begin
                result[i*8 +: 8] = palindrome[i];
            end
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // k_out assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            k_out <= 4'd0;
        end else if (state == DONE_STATE) begin
            k_out <= k;
        end
    end

endmodule