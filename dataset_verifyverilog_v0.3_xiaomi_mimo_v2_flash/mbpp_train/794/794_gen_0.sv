module StringPatternMatcher(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire char_valid,
    input wire str_end,
    output reg match,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] SEARCH_A   = 3'd1;
    localparam [2:0] SEARCH_B   = 3'd2;
    localparam [2:0] MATCH      = 3'd3;
    localparam [2:0] NO_MATCH   = 3'd4;
    
    reg [2:0] state, next_state;
    reg found_a;
    reg [7:0] char_reg;
    reg char_valid_reg;
    reg str_end_reg;
    reg start_reg;
    
    // ASCII constants
    localparam [7:0] ASCII_A = 8'h61;
    localparam [7:0] ASCII_B = 8'h62;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            found_a <= 1'b0;
            char_reg <= 8'd0;
            char_valid_reg <= 1'b0;
            str_end_reg <= 1'b0;
            start_reg <= 1'b0;
            match <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            char_reg <= char_in;
            char_valid_reg <= char_valid;
            str_end_reg <= str_end;
            start_reg <= start;
            
            // Default outputs
            match <= match;
            done <= done;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        found_a <= 1'b0;
                        match <= 1'b0;
                        done <= 1'b0;
                    end
                end
                
                SEARCH_A: begin
                    if (char_valid_reg) begin
                        if (char_reg == ASCII_A) begin
                            found_a <= 1'b1;
                        end
                    end
                end
                
                SEARCH_B: begin
                    if (char_valid_reg) begin
                        if (char_reg == ASCII_B) begin
                            // Found 'b', check if it's the end
                            if (str_end_reg) begin
                                match <= 1'b1;
                            end
                        end
                    end
                end
                
                MATCH: begin
                    done <= 1'b1;
                end
                
                NO_MATCH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SEARCH_A;
                end
            end
            
            SEARCH_A: begin
                if (char_valid_reg) begin
                    if (char_reg == ASCII_A) begin
                        next_state = SEARCH_B;
                    end
                end
                if (str_end_reg) begin
                    next_state = NO_MATCH;
                end
            end
            
            SEARCH_B: begin
                if (char_valid_reg) begin
                    if (char_reg == ASCII_B) begin
                        if (str_end_reg) begin
                            next_state = MATCH;
                        end
                    end else if (char_reg != ASCII_B) begin
                        if (str_end_reg) begin
                            next_state = NO_MATCH;
                        end
                    end
                end
                if (str_end_reg) begin
                    next_state = NO_MATCH;
                end
            end
            
            MATCH: begin
                next_state = IDLE;
            end
            
            NO_MATCH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule