module substring_matcher(
    input clk,
    input rst_n,
    input start,
    input [7:0] main_str [0:7],
    input [7:0] sub_str [0:7],
    input [3:0] main_len,
    input [3:0] sub_len,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state;
    reg [3:0] pos_counter;           // Position in main string (0 to main_len - sub_len)
    reg [3:0] char_counter;          // Character position in substring comparison
    reg match_found;                 // Flag for current position match
    reg [3:0] count_reg;             // Accumulated match count
    reg [3:0] max_pos;               // Maximum position to check (main_len - sub_len)
    
    // Temporary registers for comparison
    reg comp_result;
    reg [3:0] loop_i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            pos_counter <= 4'd0;
            char_counter <= 4'd0;
            match_found <= 1'b0;
            count_reg <= 4'd0;
            max_pos <= 4'd0;
            comp_result <= 1'b0;
            loop_i <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    pos_counter <= 4'd0;
                    char_counter <= 4'd0;
                    count_reg <= 4'd0;
                    match_found <= 1'b0;
                    
                    if (start) begin
                        // Calculate max position: main_len - sub_len
                        max_pos <= main_len - sub_len;
                        state <= PROCESSING;
                    end
                end
                
                PROCESSING: begin
                    // Compare current position (pos_counter) in main string with substring
                    // Use a loop to compare all characters
                    
                    // First, check if we need to compare or already have result
                    if (char_counter == 4'd0) begin
                        // Start comparing at this position
                        comp_result <= 1'b1; // Assume match initially
                        loop_i <= 4'd0;
                    end
                    
                    // Character comparison logic
                    if (char_counter < sub_len && loop_i < sub_len) begin
                        if (comp_result && (main_str[pos_counter + loop_i] == sub_str[loop_i])) begin
                            // Characters match, continue
                            loop_i <= loop_i + 4'd1;
                            if (loop_i + 4'd1 >= sub_len) begin
                                // All characters matched
                                match_found <= 1'b1;
                                char_counter <= sub_len;
                            end
                        end else begin
                            // Characters don't match
                            comp_result <= 1'b0;
                            match_found <= 1'b0;
                            char_counter <= sub_len; // Skip to next position
                        end
                    end
                    
                    // Check if comparison for this position is complete
                    if (char_counter >= sub_len) begin
                        // Position comparison complete
                        if (match_found) begin
                            count_reg <= count_reg + 4'd1;
                        end
                        
                        // Move to next position or finish
                        if (pos_counter < max_pos) begin
                            pos_counter <= pos_counter + 4'd1;
                            char_counter <= 4'd0;
                            match_found <= 1'b0;
                        end else begin
                            // All positions checked
                            state <= DONE;
                        end
                    end
                end
                
                DONE: begin
                    result <= count_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule