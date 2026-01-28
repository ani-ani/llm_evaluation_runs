module pattern_finder(
    input clk,
    input rst_n,
    input start,
    input [7:0] text [0:15],
    input [7:0] pattern [0:15],
    input [3:0] text_len,
    input [3:0] pattern_len,
    output reg done,
    output reg valid,
    output reg [7:0] match_substring [0:15],
    output reg [3:0] start_idx,
    output reg [3:0] end_idx,
    output reg no_valid
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] MATCH = 3'd3;
    localparam [2:0] NO_MATCH = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] i_reg, j_reg;
    reg [7:0] text_reg [0:15];
    reg [7:0] pattern_reg [0:15];
    reg [3:0] text_len_reg, pattern_len_reg;
    reg match_found;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd255;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            match_found <= 1'b0;
            done <= 1'b0;
            valid <= 1'b0;
            no_valid <= 1'b0;
            start_idx <= 4'd0;
            end_idx <= 4'd0;
            cycle_count <= 4'd0;
            
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                match_substring[k] <= 8'd0;
                text_reg[k] <= 8'd0;
                pattern_reg[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            if (state == LOAD) begin
                integer k;
                for (k = 0; k < 16; k = k + 1) begin
                    text_reg[k] <= text[k];
                    pattern_reg[k] <= pattern[k];
                end
                text_len_reg <= text_len;
                pattern_len_reg <= pattern_len;
                i_reg <= 4'd0;
                j_reg <= 4'd0;
                match_found <= 1'b0;
                cycle_count <= 4'd0;
            end else if (state == COMPARE) begin
                cycle_count <= cycle_count + 4'd1;
                
                if (j_reg == pattern_len_reg - 4'd1) begin
                    // Completed inner loop
                    if (match_found) begin
                        next_state <= MATCH;
                    end else begin
                        i_reg <= i_reg + 4'd1;
                        j_reg <= 4'd0;
                        
                        if (i_reg > text_len_reg - pattern_len_reg) begin
                            next_state <= NO_MATCH;
                        end
                    end
                end else begin
                    j_reg <= j_reg + 4'd1;
                end
            end
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end
            
            LOAD: begin
                if (pattern_len_reg == 4'd0 || text_len_reg < pattern_len_reg) begin
                    next_state = NO_MATCH;
                end else begin
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                if (text_reg[i_reg + j_reg] == pattern_reg[j_reg]) begin
                    match_found = 1'b1;
                end else begin
                    match_found = 1'b0;
                end
                
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = NO_MATCH;
                end else begin
                    next_state = COMPARE;
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

    // Output logic
    always @(*) begin
        done = 1'b0;
        valid = 1'b0;
        no_valid = 1'b0;
        start_idx = 4'd0;
        end_idx = 4'd0;
        
        integer k;
        for (k = 0; k < 16; k = k + 1) begin
            match_substring[k] = 8'd0;
        end
        
        if (state == MATCH) begin
            done = 1'b1;
            valid = 1'b1;
            start_idx = i_reg;
            end_idx = i_reg + pattern_len_reg;
            
            for (k = 0; k < 16; k = k + 1) begin
                if (k < pattern_len_reg) begin
                    match_substring[k] = pattern_reg[k];
                end else begin
                    match_substring[k] = 8'd0;
                end
            end
        end else if (state == NO_MATCH) begin
            done = 1'b1;
            no_valid = 1'b1;
        end
    end

endmodule