module duel_game (
    input [7:0] card_state,
    input [3:0] k,
    output reg [10*8-1:0] result
);

    reg [7:0] new_state;
    integer i, j;
    reg can_win_immediately;
    reg all_second_wins;

    always @(*) begin
        can_win_immediately = 1'b0;
        all_second_wins = 1'b1;

        // Check if first player can win immediately
        for (i = 0; i <= 8 - k; i = i + 1) begin
            // Try flipping to 0
            new_state = card_state ^ (((1 << k) - 1) << i);
            if (new_state == 8'b0) begin
                can_win_immediately = 1'b1;
            end
            // Try flipping to 1
            new_state = card_state ^ (((1 << k) - 1) << i);
            if (new_state == 8'b11111111) begin
                can_win_immediately = 1'b1;
            end
        end

        if (can_win_immediately) begin
            result = {8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0};
            result[7:0] = 8'h74; // 't'
            result[15:8] = 8'h6F; // 'o'
            result[23:16] = 8'h6B; // 'k'
            result[31:24] = 8'h69; // 'i'
            result[39:32] = 8'h74; // 't'
            result[47:40] = 8'h73; // 's'
            result[55:48] = 8'h75; // 'u'
            result[63:56] = 8'h6B; // 'k'
            result[71:64] = 8'h61; // 'a'
            result[79:72] = 8'h7A; // 'z'
        end else begin
            // Check all possible first player moves
            for (i = 0; i <= 8 - k; i = i + 1) begin
                // Flip to 0
                new_state = card_state ^ (((1 << k) - 1) << i);
                if (!can_second_win(new_state, k)) begin
                    all_second_wins = 1'b0;
                end
                // Flip to 1
                new_state = card_state ^ (((1 << k) - 1) << i);
                if (!can_second_win(new_state, k)) begin
                    all_second_wins = 1'b0;
                end
            end

            if (all_second_wins) begin
                result = {8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0};
                result[7:0] = 8'h71; // 'q'
                result[15:8] = 8'h75; // 'u'
                result[23:16] = 8'h61; // 'a'
                result[31:24] = 8'h69; // 'i'
                result[39:32] = 8'h6C; // 'l'
                result[47:40] = 8'h74; // 't'
                result[55:48] = 8'h79; // 'y'
            end else begin
                result = {8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0, 8'b0};
                result[7:0] = 8'h6F; // 'o'
                result[15:8] = 8'h6E; // 'n'
                result[23:16] = 8'h63; // 'c'
                result[31:24] = 8'h65; // 'e'
                result[39:32] = 8'h20; // ' '
                result[47:40] = 8'h61; // 'a'
                result[55:48] = 8'h67; // 'g'
                result[63:56] = 8'h61; // 'a'
                result[71:64] = 8'h69; // 'i'
                result[79:72] = 8'h6E; // 'n'
            end
        end
    end

    function automatic reg can_second_win(input [7:0] state, input [3:0] k_val);
        integer i;
        reg [7:0] temp_state;
        for (i = 0; i <= 8 - k_val; i = i + 1) begin
            // Try flipping to 0
            temp_state = state ^ (((1 << k_val) - 1) << i);
            if (temp_state == 8'b0) begin
                return 1'b1;
            end
            // Try flipping to 1
            temp_state = state ^ (((1 << k_val) - 1) << i);
            if (temp_state == 8'b11111111) begin
                return 1'b1;
            end
        end
        return 1'b0;
    endfunction

endmodule