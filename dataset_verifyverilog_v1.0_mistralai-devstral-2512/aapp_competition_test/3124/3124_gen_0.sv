module CircularGameSolver(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [7:0] arr [0:7],
    output reg [7:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] PARSE = 2'd1;
    localparam [1:0] GAME  = 2'd2;
    localparam [1:0] DONE  = 2'd3;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // Game state
    reg [7:0] current_mask;
    reg [2:0] current_turn;
    reg [7:0] ivana_odds;
    reg [7:0] maria_odds;
    reg [7:0] winning_moves;
    
    // DP table (256 states)
    reg [7:0] dp_table [0:255];
    
    // Temporary registers
    reg [7:0] temp_mask;
    reg [7:0] temp_odds;
    reg [7:0] temp_result;
    reg [7:0] temp_count;
    reg [7:0] temp_value;
    reg [7:0] temp_index;
    reg [7:0] temp_adj1;
    reg [7:0] temp_adj2;
    reg [7:0] temp_bit;
    reg [7:0] temp_i;
    reg [7:0] temp_j;
    reg [7:0] temp_k;
    
    // Parse state
    reg [7:0] parsed_n;
    reg [7:0] parsed_arr [0:7];
    
    // Game evaluation
    reg [7:0] game_result;
    reg [7:0] game_state;
    reg [7:0] game_mask;
    reg [7:0] game_turn;
    reg [7:0] game_ivana;
    reg [7:0] game_maria;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all registers
            current_mask <= 8'd0;
            current_turn <= 3'd0;
            ivana_odds <= 8'd0;
            maria_odds <= 8'd0;
            winning_moves <= 8'd0;
            
            // Initialize DP table
            for (temp_i = 0; temp_i < 8'd256; temp_i = temp_i + 8'd1) begin
                dp_table[temp_i] <= 8'd0;
            end
            
            // Initialize temporary registers
            temp_mask <= 8'd0;
            temp_odds <= 8'd0;
            temp_result <= 8'd0;
            temp_count <= 8'd0;
            temp_value <= 8'd0;
            temp_index <= 8'd0;
            temp_adj1 <= 8'd0;
            temp_adj2 <= 8'd0;
            temp_bit <= 8'd0;
            temp_i <= 8'd0;
            temp_j <= 8'd0;
            temp_k <= 8'd0;
            
            // Initialize game state
            game_result <= 8'd0;
            game_state <= 8'd0;
            game_mask <= 8'd0;
            game_turn <= 8'd0;
            game_ivana <= 8'd0;
            game_maria <= 8'd0;
            
            // Initialize parsed state
            parsed_n <= 8'd0;
            for (temp_i = 0; temp_i < 8'd8; temp_i = temp_i + 8'd1) begin
                parsed_arr[temp_i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PARSE;
                    end
                end
                
                PARSE: begin
                    // Parse n and array
                    parsed_n <= n;
                    for (temp_i = 0; temp_i < 8'd8; temp_i = temp_i + 8'd1) begin
                        parsed_arr[temp_i] <= arr[temp_i];
                    end
                    
                    // Initialize for game evaluation
                    winning_moves <= 8'd0;
                    state <= GAME;
                end
                
                GAME: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if all first moves evaluated
                    if (temp_index == parsed_n) begin
                        result <= winning_moves;
                        state <= DONE;
                    end else begin
                        // Evaluate current first move
                        game_mask <= 8'd0;
                        game_turn <= 3'd0;
                        game_ivana <= 8'd0;
                        game_maria <= 8'd0;
                        
                        // Set current move as taken
                        temp_bit <= 1 << temp_index;
                        game_mask <= temp_bit;
                        
                        // Check if number is odd
                        if (parsed_arr[temp_index][0]) begin
                            game_ivana <= 8'd1;
                        end
                        
                        // Run minimax
                        game_result <= minimax(game_mask, 3'd1, game_ivana, game_maria);
                        
                        // Check if Ivana wins
                        if (game_result > 8'd128) begin
                            winning_moves <= winning_moves + 8'd1;
                        end
                        
                        // Move to next first move
                        temp_index <= temp_index + 8'd1;
                    end
                    
                    // Safety check for cycle count
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Minimax function (implemented as combinational logic)
    function [7:0] minimax;
        input [7:0] mask;
        input [2:0] turn;
        input [7:0] ivana;
        input [7:0] maria;
        
        reg [7:0] best_value;
        reg [7:0] current_value;
        reg [7:0] temp_mask;
        reg [7:0] temp_bit;
        reg [7:0] temp_adj1;
        reg [7:0] temp_adj2;
        reg [7:0] temp_i;
        reg [7:0] temp_j;
        reg [7:0] temp_k;
        reg [7:0] temp_ivana;
        reg [7:0] temp_maria;
        reg [7:0] temp_turn;
        
        begin
            // Check if game is over
            if (mask == ((1 << parsed_n) - 1)) begin
                if (ivana > maria) begin
                    minimax = 8'd255; // Ivana wins
                end else if (ivana < maria) begin
                    minimax = 8'd0; // Maria wins
                end else begin
                    minimax = 8'd128; // Draw
                end
                return;
            end
            
            // Initialize best value
            if (turn == 3'd0) begin
                best_value = 8'd0; // Maximizing player (Ivana)
            end else begin
                best_value = 8'd255; // Minimizing player (Maria)
            end
            
            // Try all possible moves
            for (temp_i = 0; temp_i < 8'd8; temp_i = temp_i + 8'd1) begin
                temp_bit = 1 << temp_i;
                
                // Check if move is valid (not taken and adjacent to taken)
                if ((mask & temp_bit) == 0) begin
                    // Check adjacency
                    temp_adj1 = (temp_i - 1) % parsed_n;
                    temp_adj2 = (temp_i + 1) % parsed_n;
                    
                    if ((mask & (1 << temp_adj1)) || (mask & (1 << temp_adj2)) || (mask == 8'd0)) begin
                        // Make the move
                        temp_mask = mask | temp_bit;
                        temp_ivana = ivana;
                        temp_maria = maria;
                        
                        // Update odd counts
                        if (parsed_arr[temp_i][0]) begin
                            if (turn == 3'd0) begin
                                temp_ivana = ivana + 8'd1;
                            end else begin
                                temp_maria = maria + 8'd1;
                            end
                        end
                        
                        // Recursive call
                        temp_turn = turn ^ 3'd1;
                        current_value = minimax(temp_mask, temp_turn, temp_ivana, temp_maria);
                        
                        // Update best value
                        if (turn == 3'd0) begin
                            if (current_value > best_value) begin
                                best_value = current_value;
                            end
                        end else begin
                            if (current_value < best_value) begin
                                best_value = current_value;
                            end
                        end
                    end
                end
            end
            
            minimax = best_value;
        end
    endfunction
    
endmodule