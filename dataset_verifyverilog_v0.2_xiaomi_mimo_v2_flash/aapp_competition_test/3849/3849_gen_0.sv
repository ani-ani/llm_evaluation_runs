module duel_game(
    input [7:0] card_state,
    input [3:0] k,
    output reg [79:0] result
);

    // Helper to check if a state is uniform (all 0s or all 1s)
    // This corresponds to the state being 00000000 or 11111111
    function automatic logic is_uniform(input [7:0] state);
        begin
            is_uniform = (state == 8'h00) || (state == 8'hFF);
        end
    endfunction

    // Helper to check if second player can win from a given state
    // Returns 1 if there exists a window of size k that can be flipped to make the state uniform
    function automatic logic can_win_next(input [7:0] state, input [3:0] k_in);
        integer i;
        logic [7:0] flipped_state;
        logic found_win;
        begin
            found_win = 0;
            // Iterate through all possible start positions for the window
            // n=8, so valid start indices are 0 to 7-k_in
            for (i = 0; i <= 8 - k_in; i = i + 1) begin
                // Flip bits i to i+k_in-1
                // Create mask: k_in ones shifted to i
                flipped_state = state ^ (( (1 << k_in) - 1 ) << i);
                
                if (is_uniform(flipped_state)) begin
                    found_win = 1;
                    break; // Found at least one winning move
                end
            end
            can_win_next = found_win;
        end
    endfunction

    // Main combinational logic
    always @(*) begin
        // 1. Check if first player can win immediately
        if (can_win_next(card_state, k)) begin
            // ASCII: t=0x74, o=0x6F, k=0x6B, i=0x69, t=0x74, s=0x73, u=0x75, k=0x6B, a=0x61, z=0x7A
            result = {8'h74, 8'h6F, 8'h6B, 8'h69, 8'h74, 8'h73, 8'h75, 8'h6B, 8'h61, 8'h7A};
        end else begin
            // 2. Check if second player can always win (Quailty)
            // We need to verify that for ALL possible moves of player 1, 
            // the second player CAN win from the resulting state.
            // If we find ANY move for player 1 that leaves player 2 unable to win, it's "once again".
            
            logic all_moves_lead_to_loss;
            integer i;
            logic [7:0] p1_state;
            
            all_moves_lead_to_loss = 1; // Assume true until proven otherwise
            
            for (i = 0; i <= 8 - k; i = i + 1) begin
                // Check flipping window starting at i to all 0s
                // Old bits: card_state[i +: k]
                // New bits: 0
                // Result: card_state with those bits cleared
                p1_state = card_state & ~(((1 << k) - 1) << i);
                if (!can_win_next(p1_state, k)) begin
                    all_moves_lead_to_loss = 0;
                end
                
                // Check flipping window starting at i to all 1s
                // New bits: 1
                // Result: card_state with those bits set
                p1_state = card_state | (((1 << k) - 1) << i);
                if (!can_win_next(p1_state, k)) begin
                    all_moves_lead_to_loss = 0;
                end
            end
            
            if (all_moves_lead_to_loss) begin
                // ASCII: q=0x71, u=0x75, a=0x61, i=0x69, l=0x6C, t=0x74, y=0x79, space=0x20, space=0x20, space=0x20
                result = {8'h71, 8'h75, 8'h61, 8'h69, 8'h6C, 8'h74, 8'h79, 8'h20, 8'h20, 8'h20};
            end else begin
                // 3. Otherwise, draw/once again
                // ASCII: o=0x6F, n=0x6E, c=0x63, e=0x65, space=0x20, a=0x61, g=0x67, a=0x61, i=0x69, n=0x6E
                result = {8'h6F, 8'h6E, 8'h63, 8'h65, 8'h20, 8'h61, 8'h67, 8'h61, 8'h69, 8'h6E};
            end
        end
    end

endmodule
