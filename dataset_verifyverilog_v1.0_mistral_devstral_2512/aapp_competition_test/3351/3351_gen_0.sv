module yahtzee(
    input clk,
    input rst_n,
    input start,
    input [194:0] rolls,
    output reg [15:0] total_score,
    output reg done
);

    // State declarations
    localparam [4:0] IDLE      = 5'd0;
    localparam [4:0] ROUND_0   = 5'd1;  // 1's
    localparam [4:0] ROUND_1   = 5'd2;  // 2's
    localparam [4:0] ROUND_2   = 5'd3;  // 3's
    localparam [4:0] ROUND_3   = 5'd4;  // 4's
    localparam [4:0] ROUND_4   = 5'd5;  // 5's
    localparam [4:0] ROUND_5   = 5'd6;  // 6's
    localparam [4:0] ROUND_6   = 5'd7;  // 3-of-a-Kind
    localparam [4:0] ROUND_7   = 5'd8;  // 4-of-a-Kind
    localparam [4:0] ROUND_8   = 5'd9;  // Full House
    localparam [4:0] ROUND_9   = 5'd10; // Small Straight
    localparam [4:0] ROUND_10  = 5'd11; // Long Straight
    localparam [4:0] ROUND_11  = 5'd12; // Chance
    localparam [4:0] ROUND_12  = 5'd13; // Yahtzee
    localparam [4:0] DONE      = 5'd14;

    reg [4:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Current round dice
    reg [2:0] dice [0:4];
    reg [3:0] round_index;

    // Bubble sort for straight detection
    reg [2:0] sorted_dice [0:4];

    // Scoring functions
    function [7:0] score_upper;
        input [2:0] d [0:4];
        input [3:0] target;
        integer i;
        reg [7:0] count;
        begin
            count = 8'd0;
            for (i = 0; i < 5; i = i + 1) begin
                if (d[i] == target)
                    count = count + 8'd1;
            end
            score_upper = count * (target + 3'd1);
        end
    endfunction

    function [7:0] score_n_of_a_kind;
        input [2:0] d [0:4];
        input [1:0] n;
        integer i, j;
        reg [7:0] max_count;
        reg [2:0] value;
        begin
            max_count = 8'd0;
            for (i = 1; i <= 6; i = i + 1) begin
                value = 3'd0;
                for (j = 0; j < 5; j = j + 1) begin
                    if (d[j] == i)
                        value = value + 3'd1;
                end
                if (value >= n && value > max_count)
                    max_count = value;
            end
            if (max_count >= n)
                score_n_of_a_kind = d[0] + d[1] + d[2] + d[3] + d[4];
            else
                score_n_of_a_kind = 8'd0;
        end
    endfunction

    function [7:0] score_full_house;
        input [2:0] d [0:4];
        integer i;
        reg [2:0] counts [1:6];
        reg has_two, has_three;
        begin
            for (i = 1; i <= 6; i = i + 1)
                counts[i] = 3'd0;
            for (i = 0; i < 5; i = i + 1)
                counts[d[i]] = counts[d[i]] + 3'd1;

            has_two = 1'b0;
            has_three = 1'b0;
            for (i = 1; i <= 6; i = i + 1) begin
                if (counts[i] == 3'd2)
                    has_two = 1'b1;
                if (counts[i] == 3'd3)
                    has_three = 1'b1;
            end

            if (has_two && has_three)
                score_full_house = 8'd25;
            else
                score_full_house = 8'd0;
        end
    endfunction

    function [7:0] score_straight;
        input [2:0] s [0:4];
        integer i;
        reg is_small, is_large;
        begin
            is_small = 1'b1;
            for (i = 0; i < 4; i = i + 1) begin
                if (s[i+1] != s[i] + 3'd1)
                    is_small = 1'b0;
            end

            is_large = 1'b1;
            for (i = 0; i < 4; i = i + 1) begin
                if (s[i+1] != s[i] + 3'd1)
                    is_large = 1'b0;
            end

            if (is_large)
                score_straight = 8'd40;
            else if (is_small)
                score_straight = 8'd30;
            else
                score_straight = 8'd0;
        end
    endfunction

    function [7:0] score_chance;
        input [2:0] d [0:4];
        begin
            score_chance = d[0] + d[1] + d[2] + d[3] + d[4];
        end
    endfunction

    function [7:0] score_yahtzee;
        input [2:0] d [0:4];
        integer i;
        reg all_same;
        begin
            all_same = 1'b1;
            for (i = 1; i < 5; i = i + 1) begin
                if (d[i] != d[0])
                    all_same = 1'b0;
            end
            if (all_same)
                score_yahtzee = 8'd50;
            else
                score_yahtzee = 8'd0;
        end
    endfunction

    // Bubble sort for straight detection
    always @(*) begin
        integer i, j;
        reg [2:0] temp;
        for (i = 0; i < 5; i = i + 1)
            sorted_dice[i] = dice[i];
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4 - i; j = j + 1) begin
                if (sorted_dice[j] > sorted_dice[j+1]) begin
                    temp = sorted_dice[j];
                    sorted_dice[j] = sorted_dice[j+1];
                    sorted_dice[j+1] = temp;
                end
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total_score <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            round_index <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    round_index <= 4'd0;
                    if (start) begin
                        state <= ROUND_0;
                    end
                end

                ROUND_0: begin
                    // Load dice for round 0 (1's)
                    dice[0] <= rolls[2:0];
                    dice[1] <= rolls[5:3];
                    dice[2] <= rolls[8:6];
                    dice[3] <= rolls[11:9];
                    dice[4] <= rolls[14:12];
                    total_score <= total_score + score_upper(dice, 3'd1);
                    state <= ROUND_1;
                end

                ROUND_1: begin
                    // Load dice for round 1 (2's)
                    dice[0] <= rolls[17:15];
                    dice[1] <= rolls[20:18];
                    dice[2] <= rolls[23:21];
                    dice[3] <= rolls[26:24];
                    dice[4] <= rolls[29:27];
                    total_score <= total_score + score_upper(dice, 3'd2);
                    state <= ROUND_2;
                end

                ROUND_2: begin
                    // Load dice for round 2 (3's)
                    dice[0] <= rolls[32:30];
                    dice[1] <= rolls[35:33];
                    dice[2] <= rolls[38:36];
                    dice[3] <= rolls[41:39];
                    dice[4] <= rolls[44:42];
                    total_score <= total_score + score_upper(dice, 3'd3);
                    state <= ROUND_3;
                end

                ROUND_3: begin
                    // Load dice for round 3 (4's)
                    dice[0] <= rolls[47:45];
                    dice[1] <= rolls[50:48];
                    dice[2] <= rolls[53:51];
                    dice[3] <= rolls[56:54];
                    dice[4] <= rolls[59:57];
                    total_score <= total_score + score_upper(dice, 3'd4);
                    state <= ROUND_4;
                end

                ROUND_4: begin
                    // Load dice for round 4 (5's)
                    dice[0] <= rolls[62:60];
                    dice[1] <= rolls[65:63];
                    dice[2] <= rolls[68:66];
                    dice[3] <= rolls[71:69];
                    dice[4] <= rolls[74:72];
                    total_score <= total_score + score_upper(dice, 3'd5);
                    state <= ROUND_5;
                end

                ROUND_5: begin
                    // Load dice for round 5 (6's)
                    dice[0] <= rolls[77:75];
                    dice[1] <= rolls[80:78];
                    dice[2] <= rolls[83:81];
                    dice[3] <= rolls[86:84];
                    dice[4] <= rolls[89:87];
                    total_score <= total_score + score_upper(dice, 3'd6);
                    state <= ROUND_6;
                end

                ROUND_6: begin
                    // Load dice for round 6 (3-of-a-Kind)
                    dice[0] <= rolls[92:90];
                    dice[1] <= rolls[95:93];
                    dice[2] <= rolls[98:96];
                    dice[3] <= rolls[101:99];
                    dice[4] <= rolls[104:102];
                    total_score <= total_score + score_n_of_a_kind(dice, 2'd3);
                    state <= ROUND_7;
                end

                ROUND_7: begin
                    // Load dice for round 7 (4-of-a-Kind)
                    dice[0] <= rolls[107:105];
                    dice[1] <= rolls[110:108];
                    dice[2] <= rolls[113:111];
                    dice[3] <= rolls[116:114];
                    dice[4] <= rolls[119:117];
                    total_score <= total_score + score_n_of_a_kind(dice, 2'd4);
                    state <= ROUND_8;
                end

                ROUND_8: begin
                    // Load dice for round 8 (Full House)
                    dice[0] <= rolls[122:120];
                    dice[1] <= rolls[125:123];
                    dice[2] <= rolls[128:126];
                    dice[3] <= rolls[131:129];
                    dice[4] <= rolls[134:132];
                    total_score <= total_score + score_full_house(dice);
                    state <= ROUND_9;
                end

                ROUND_9: begin
                    // Load dice for round 9 (Small Straight)
                    dice[0] <= rolls[137:135];
                    dice[1] <= rolls[140:138];
                    dice[2] <= rolls[143:141];
                    dice[3] <= rolls[146:144];
                    dice[4] <= rolls[149:147];
                    total_score <= total_score + score_straight(sorted_dice);
                    state <= ROUND_10;
                end

                ROUND_10: begin
                    // Load dice for round 10 (Long Straight)
                    dice[0] <= rolls[152:150];
                    dice[1] <= rolls[155:153];
                    dice[2] <= rolls[158:156];
                    dice[3] <= rolls[161:159];
                    dice[4] <= rolls[164:162];
                    total_score <= total_score + score_straight(sorted_dice);
                    state <= ROUND_11;
                end

                ROUND_11: begin
                    // Load dice for round 11 (Chance)
                    dice[0] <= rolls[167:165];
                    dice[1] <= rolls[170:168];
                    dice[2] <= rolls[173:171];
                    dice[3] <= rolls[176:174];
                    dice[4] <= rolls[179:177];
                    total_score <= total_score + score_chance(dice);
                    state <= ROUND_12;
                end

                ROUND_12: begin
                    // Load dice for round 12 (Yahtzee)
                    dice[0] <= rolls[182:180];
                    dice[1] <= rolls[185:183];
                    dice[2] <= rolls[188:186];
                    dice[3] <= rolls[191:189];
                    dice[4] <= rolls[194:192];
                    total_score <= total_score + score_yahtzee(dice);
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule