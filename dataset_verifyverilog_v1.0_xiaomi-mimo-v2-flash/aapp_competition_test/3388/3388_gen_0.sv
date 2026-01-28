module JuliaStrategy(
    input clk,
    input rst_n,
    input start,
    input [31:0] julia_score,
    input [31:0] other_scores [14:0],
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INIT     = 3'd1;
    localparam [2:0] FIND_MAX = 3'd2;
    localparam [3:0] UPDATE   = 3'd3;
    localparam [2:0] CHECK    = 3'd4;
    localparam [2:0] FINISH   = 3'd5;
    
    // Registers
    reg [2:0] state, next_state;
    reg [31:0] reg_julia;
    reg [31:0] reg_others [14:0];
    reg [7:0] match_count;
    reg [3:0] player_idx;
    reg [31:0] max_score;
    reg [3:0] max_idx;
    reg [31:0] temp_score;
    reg lead_lost;
    
    // Temporary signals for array operations
    reg [31:0] next_julia;
    reg [31:0] next_others [14:0];
    
    integer i;
    
    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            reg_julia <= 32'd0;
            for (i = 0; i < 15; i = i + 1) begin
                reg_others[i] <= 32'd0;
            end
            match_count <= 8'd0;
            player_idx <= 4'd0;
            max_score <= 32'd0;
            max_idx <= 4'd0;
            temp_score <= 32'd0;
            lead_lost <= 1'b0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    match_count <= 8'd0;
                    lead_lost <= 1'b0;
                    player_idx <= 4'd0;
                    max_score <= 32'd0;
                    max_idx <= 4'd0;
                end
                
                INIT: begin
                    reg_julia <= julia_score;
                    for (i = 0; i < 15; i = i + 1) begin
                        reg_others[i] <= other_scores[i];
                    end
                    player_idx <= 4'd0;
                    max_score <= 32'd0;
                    max_idx <= 4'd0;
                end
                
                FIND_MAX: begin
                    if (player_idx < 4'd15) begin
                        if (reg_others[player_idx] > max_score) begin
                            max_score <= reg_others[player_idx];
                            max_idx <= player_idx;
                        end
                        player_idx <= player_idx + 4'd1;
                    end
                end
                
                UPDATE: begin
                    // Worst case: others bet optimally against Julia (majority loses)
                    // Max scorer among others will lose, decreasing their score
                    if (reg_others[max_idx] > 32'd0) begin
                        reg_others[max_idx] <= reg_others[max_idx] - 32'd1;
                    end
                    match_count <= match_count + 8'd1;
                end
                
                CHECK: begin
                    // Check if Julia still in lead (Julia >= all others)
                    lead_lost <= 1'b0;
                    player_idx <= 4'd0;
                    temp_score <= reg_others[4'd0];
                end
                
                FINISH: begin
                    result <= match_count;
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Next State Logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end
            
            INIT: begin
                next_state = FIND_MAX;
            end
            
            FIND_MAX: begin
                if (player_idx >= 4'd15) begin
                    next_state = UPDATE;
                end else begin
                    next_state = FIND_MAX;
                end
            end
            
            UPDATE: begin
                next_state = CHECK;
            end
            
            CHECK: begin
                // Check next player for max
                if (player_idx < 4'd14) begin
                    player_idx = player_idx + 4'd1;
                    if (reg_others[player_idx] > temp_score) begin
                        temp_score = reg_others[player_idx];
                    end
                    next_state = CHECK;
                end else begin
                    // Compare last player if needed
                    if (reg_others[4'd14] > temp_score) begin
                        temp_score = reg_others[4'd14];
                    end
                    
                    if (reg_julia < temp_score) begin
                        lead_lost = 1'b1;
                    end
                    
                    if (lead_lost || match_count >= 8'd255) begin
                        next_state = FINISH;
                    end else begin
                        player_idx = 4'd0;
                        max_score = 32'd0;
                        max_idx = 4'd0;
                        next_state = FIND_MAX;
                    end
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule