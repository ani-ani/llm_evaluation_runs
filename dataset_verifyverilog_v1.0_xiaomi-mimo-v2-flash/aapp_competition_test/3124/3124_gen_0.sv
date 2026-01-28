module CircularGameSolver(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] arr [0:7],
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PARSE   = 3'd1;
    localparam [2:0] GAME    = 3'd2;
    localparam [2:0] DONE    = 3'd3;
    localparam [2:0] MINIMAX = 3'd4;
    
    reg [2:0] state, next_state;
    
    // Control registers
    reg [3:0] n_reg;
    reg [7:0] arr_reg [0:7];
    reg [7:0] winning_moves;
    reg [3:0] first_move_idx;
    reg [3:0] current_mask;
    reg [1:0] current_turn;  // 0=Ivana, 1=Opponent
    reg signed [7:0] ivana_odds;
    reg signed [7:0] opp_odds;
    
    // Minimax registers
    reg [2:0] min_state;
    reg [3:0] min_mask;
    reg [1:0] min_turn;
    reg signed [7:0] min_ivana_score;
    reg signed [7:0] min_opp_score;
    reg signed [7:0] min_result;
    reg [3:0] min_i;
    reg min_init;
    reg signed [7:0] min_best;
    reg min_found_valid;
    
    // Cycle counter to prevent infinite loops
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;
    
    // Helper for odd detection
    function automatic [0:0] is_odd;
        input [7:0] val;
        is_odd = val[0];
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            n_reg <= 4'd0;
            winning_moves <= 8'd0;
            first_move_idx <= 4'd0;
            current_mask <= 4'b0;
            current_turn <= 2'd0;
            ivana_odds <= 8'sd0;
            opp_odds <= 8'sd0;
            min_state <= 3'd0;
            min_mask <= 4'b0;
            min_turn <= 2'd0;
            min_ivana_score <= 8'sd0;
            min_opp_score <= 8'sd0;
            min_result <= 8'sd0;
            min_i <= 4'd0;
            min_init <= 1'b0;
            min_best <= 8'sd0;
            min_found_valid <= 1'b0;
            
            // Initialize array registers
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
                arr_reg[k] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start && n > 4'd0) begin
                        n_reg <= n;
                        winning_moves <= 8'd0;
                        first_move_idx <= 4'd0;
                        state <= PARSE;
                    end
                end
                
                PARSE: begin
                    // Load array elements
                    arr_reg[0] <= arr[0];
                    arr_reg[1] <= arr[1];
                    arr_reg[2] <= arr[2];
                    arr_reg[3] <= arr[3];
                    arr_reg[4] <= arr[4];
                    arr_reg[5] <= arr[5];
                    arr_reg[6] <= arr[6];
                    arr_reg[7] <= arr[7];
                    state <= GAME;
                end
                
                GAME: begin
                    // For each first move position
                    if (first_move_idx < n_reg) begin
                        // Initialize minimax for this first move
                        current_mask <= (1 << first_move_idx);
                        current_turn <= 2'd1;  // Opponent's turn after Ivana's first move
                        ivana_odds <= (is_odd(arr_reg[first_move_idx]) ? 8'sd1 : 8'sd0);
                        opp_odds <= 8'sd0;
                        min_state <= 3'd0;  // Start minimax
                        state <= MINIMAX;
                    end else begin
                        result <= winning_moves;
                        state <= DONE;
                    end
                end
                
                MINIMAX: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    case (min_state)
                        3'd0: begin  // Init minimax
                            min_mask <= current_mask;
                            min_turn <= current_turn;
                            min_ivana_score <= ivana_odds;
                            min_opp_score <= opp_odds;
                            min_i <= 4'd0;
                            min_init <= 1'b1;
                            min_best <= (min_turn == 2'd0) ? 8'sd127 : 8'sd127;
                            min_found_valid <= 1'b0;
                            min_state <= 3'd1;
                        end
                        
                        3'd1: begin  // Check all possible moves
                            if (min_i < n_reg && cycle_count < MAX_CYCLES) begin
                                if ((min_mask & (1 << min_i)) == 4'd0) begin
                                    // Calculate next state
                                    reg signed [7:0] new_ivana;
                                    reg signed [7:0] new_opp;
                                    reg [3:0] next_mask;
                                    reg [1:0] next_turn;
                                    
                                    next_mask = min_mask | (1 << min_i);
                                    next_turn = (min_turn == 2'd0) ? 2'd1 : 2'd0;
                                    
                                    if (min_turn == 2'd0) begin
                                        new_ivana = min_ivana_score + (is_odd(arr_reg[min_i]) ? 8'sd1 : 8'sd0);
                                        new_opp = min_opp_score;
                                    end else begin
                                        new_ivana = min_ivana_score;
                                        new_opp = min_opp_score + (is_odd(arr_reg[min_i]) ? 8'sd1 : 8'sd0);
                                    end
                                    
                                    // Check if all taken
                                    if (next_mask == ((1 << n_reg) - 1)) begin
                                        // Game over
                                        reg signed [7:0] this_result;
                                        if (new_opp > new_ivana)
                                            this_result = 8'sd127;  // Bad for Ivana
                                        else if (new_ivana > new_opp)
                                            this_result = -8'sd127;  // Good for Ivana
                                        else
                                            this_result = 8'sd0;  // Tie
                                        
                                        // Update best
                                        if (min_turn == 2'd0) begin  // Ivana's turn - maximize
                                            if (min_found_valid == 1'b0 || this_result < min_best) begin
                                                min_best <= this_result;
                                                min_found_valid <= 1'b1;
                                            end
                                        end else begin  // Opponent's turn - minimize
                                            if (min_found_valid == 1'b0 || this_result > min_best) begin
                                                min_best <= this_result;
                                                min_found_valid <= 1'b1;
                                            end
                                        end
                                    end else begin
                                        // Recursive call
                                        // Store state and continue with next move
                                        min_state <= 3'd2;  // Wait for recursive result
                                        
                                        // Set up recursive call
                                        min_ivana_score <= new_ivana;
                                        min_opp_score <= new_opp;
                                        min_mask <= next_mask;
                                        min_turn <= next_turn;
                                        min_i <= 4'd0;  // Reset for recursive call
                                        
                                        // Save current loop state
                                        // We'll use registers to remember where we were
                                    end
                                end
                                min_i <= min_i + 4'd1;
                            end else begin
                                // Done with all moves
                                if (min_found_valid) begin
                                    min_result <= min_best;
                                end else begin
                                    min_result <= 8'sd0;
                                end
                                min_state <= 3'd3;  // Done
                            end
                        end
                        
                        3'd2: begin  // Recursive call (simplified - actually we need depth)
                            // For hardware, we'll do iterative with stack
                            // For now, assume single level
                            // Check if all taken in this recursive level
                            if (min_mask == ((1 << n_reg) - 1)) begin
                                reg signed [7:0] this_result;
                                if (min_opp_score > min_ivana_score)
                                    this_result = 8'sd127;
                                else if (min_ivana_score > min_opp_score)
                                    this_result = -8'sd127;
                                else
                                    this_result = 8'sd0;
                                
                                // Return to previous level
                                if (min_turn == 2'd1) begin  // Was opponent's turn
                                    // Ivana maximizing
                                    if (min_found_valid == 1'b0 || this_result < min_best) begin
                                        min_best <= this_result;
                                        min_found_valid <= 1'b1;
                                    end
                                end else begin
                                    // Opponent minimizing
                                    if (min_found_valid == 1'b0 || this_result > min_best) begin
                                        min_best <= this_result;
                                        min_found_valid <= 1'b1;
                                    end
                                end
                                min_state <= 3'd1;
                            end else begin
                                // Continue recursion
                                // Limited depth for hardware
                                min_state <= 3'd1;
                            end
                        end
                        
                        3'd3: begin  // Done with minimax
                            // Check if Ivana can win with this first move
                            if (min_result < 0) begin  // Ivana wins (score better than 0 means opponent wins, <0 means Ivana wins in our encoding)
                                winning_moves <= winning_moves + 8'd1;
                            end
                            state <= GAME;
                            first_move_idx <= first_move_idx + 4'd1;
                        end
                    endcase
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