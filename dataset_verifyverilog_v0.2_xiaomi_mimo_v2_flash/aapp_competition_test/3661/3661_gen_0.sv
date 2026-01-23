module lawsuit_assignment (
    input clk,
    input rst_n,
    input start,
    input [3:0] lawsuit_index,
    input [2:0] individual_idx,
    input [2:0] corporation_idx,
    output reg [2:0] winner_type,
    output reg [2:0] winner_id,
    output reg done,
    output reg [3:0] max_wins
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam UPDATE = 2'b10;
    localparam DONE_STATE = 2'b11;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] lawsuits_processed;
    reg [3:0] total_lawsuits;
    
    // Win counters for 8 individuals and 8 corporations
    // Using 4-bit counters (max 15 wins)
    reg [3:0] individuals_wins [0:7];
    reg [3:0] corporations_wins [0:7];
    
    // Temporary storage for current lawsuit data
    reg [2:0] curr_indv_idx;
    reg [2:0] curr_corr_idx;
    
    // Intermediate comparison results
    wire [3:0] indv_wins;
    wire [3:0] corp_wins;
    wire indv_less_or_equal;
    
    assign indv_wins = individuals_wins[curr_indv_idx];
    assign corp_wins = corporations_wins[curr_corr_idx];
    assign indv_less_or_equal = (indv_wins <= corp_wins);

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            
            PROCESSING: begin
                // Capture current lawsuit data and move to update
                next_state = UPDATE;
            end
            
            UPDATE: begin
                // Update counters and check if done
                if (lawsuits_processed + 1 == total_lawsuits)
                    next_state = DONE_STATE;
                else
                    next_state = PROCESSING;
            end
            
            DONE_STATE: begin
                // Stay in done state until reset
                next_state = DONE_STATE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential state and data processing
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            lawsuits_processed <= 4'b0;
            total_lawsuits <= 4'b0;
            done <= 1'b0;
            max_wins <= 4'b0;
            winner_type <= 3'b0;
            winner_id <= 3'b0;
            curr_indv_idx <= 3'b0;
            curr_corr_idx <= 3'b0;
            
            // Reset win counters
            for (i = 0; i < 8; i = i + 1) begin
                individuals_wins[i] <= 4'b0;
                corporations_wins[i] <= 4'b0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        total_lawsuits <= lawsuit_index;
                        lawsuits_processed <= 4'b0;
                        done <= 1'b0;
                        max_wins <= 4'b0;
                    end
                end
                
                PROCESSING: begin
                    // Store current lawsuit indices for processing
                    curr_indv_idx <= individual_idx;
                    curr_corr_idx <= corporation_idx;
                end
                
                UPDATE: begin
                    lawsuits_processed <= lawsuits_processed + 1'b1;
                    
                    // Greedy assignment: assign to party with fewer wins
                    if (indv_less_or_equal) begin
                        // Individual wins
                        winner_type <= 3'b0; // INDV
                        winner_id <= curr_indv_idx + 1'b1; // 1-indexed
                        individuals_wins[curr_indv_idx] <= indv_wins + 1'b1;
                        
                        // Update max_wins
                        if (indv_wins + 1'b1 > max_wins)
                            max_wins <= indv_wins + 1'b1;
                    end else begin
                        // Corporation wins
                        winner_type <= 3'b1; // CORP
                        winner_id <= curr_corr_idx + 1'b1; // 1-indexed
                        corporations_wins[curr_corr_idx] <= corp_wins + 1'b1;
                        
                        // Update max_wins
                        if (corp_wins + 1'b1 > max_wins)
                            max_wins <= corp_wins + 1'b1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule}