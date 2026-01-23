module file_matcher (
    input clk,
    input rst_n,
    input start,
    input [7:0] pattern_char,
    input [7:0] filename_char,
    input pattern_valid,
    input filename_valid,
    input pattern_end,
    input filename_end,
    output reg match,
    output reg done
);

parameter MAX_LEN = 16;

localparam [2:0] IDLE = 3'd0;
localparam [2:0] MATCH = 3'd1;
localparam [2:0] CHECK_STAR = 3'd2;
localparam [2:0] ADVANCE_BOTH = 3'd3;
localparam [2:0] ADVANCE_PATTERN = 3'd4;
localparam [2:0] ADVANCE_FILENAME = 3'd5;
localparam [2:0] BACKTRACK = 3'd6;
localparam [2:0] DONE_STATE = 3'd7;

reg [2:0] state, next_state;
reg [7:0] pattern_reg [0:15];
reg [7:0] filename_reg [0:15];
reg [4:0] pattern_idx;
reg [4:0] filename_idx;
reg [4:0] star_idx;
reg [4:0] star_match_idx;
reg [4:0] pattern_len;
reg [4:0] filename_len;
reg processing;
reg [4:0] i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start && pattern_valid && filename_valid) begin
                next_state = MATCH;
            end
        end
        MATCH: begin
            if (pattern_idx >= pattern_len && filename_idx >= filename_len) begin
                next_state = DONE_STATE;
            end else if (pattern_idx >= pattern_len) begin
                next_state = DONE_STATE;
            end else if (filename_idx >= filename_len) begin
                if (pattern_reg[pattern_idx] == 8'h2A) begin
                    next_state = ADVANCE_PATTERN;
                end else begin
                    next_state = DONE_STATE;
                end
            end else if (pattern_reg[pattern_idx] == 8'h2A) begin
                next_state = CHECK_STAR;
            end else if (pattern_reg[pattern_idx] == filename_reg[filename_idx] || pattern_reg[pattern_idx] == 8'h3F) begin
                next_state = ADVANCE_BOTH;
            end else if (star_idx != 5'h1F) begin
                next_state = BACKTRACK;
            end else begin
                next_state = DONE_STATE;
            end
        end
        CHECK_STAR: begin
            next_state = ADVANCE_PATTERN;
        end
        ADVANCE_BOTH: begin
            next_state = MATCH;
        end
        ADVANCE_PATTERN: begin
            next_state = MATCH;
        end
        ADVANCE_FILENAME: begin
            next_state = MATCH;
        end
        BACKTRACK: begin
            next_state = MATCH;
        end
        DONE_STATE: begin
            if (!start) begin
                next_state = IDLE;
            end
        end
        default: next_state = IDLE;
    endcase
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        pattern_idx <= 5'd0;
        filename_idx <= 5'd0;
        star_idx <= 5'h1F;
        star_match_idx <= 5'd0;
        match <= 1'b0;
        done <= 1'b0;
        processing <= 1'b0;
        pattern_len <= 5'd0;
        filename_len <= 5'd0;
        for (i = 0; i < 16; i = i + 1) begin
            pattern_reg[i] <= 8'd0;
            filename_reg[i] <= 8'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                if (start && pattern_valid && filename_valid) begin
                    pattern_idx <= 5'd0;
                    filename_idx <= 5'd0;
                    star_idx <= 5'h1F;
                    star_match_idx <= 5'd0;
                    match <= 1'b0;
                    done <= 1'b0;
                    processing <= 1'b1;
                    pattern_len <= 5'd0;
                    filename_len <= 5'd0;
                end
            end
            CHECK_STAR: begin
                star_idx <= pattern_idx;
                star_match_idx <= filename_idx;
                pattern_idx <= pattern_idx + 5'd1;
            end
            ADVANCE_BOTH: begin
                pattern_idx <= pattern_idx + 5'd1;
                filename_idx <= filename_idx + 5'd1;
            end
            ADVANCE_PATTERN: begin
                if (pattern_idx < pattern_len) begin
                    pattern_idx <= pattern_idx + 5'd1;
                end
            end
            ADVANCE_FILENAME: begin
                if (filename_idx < filename_len) begin
                    filename_idx <= filename_idx + 5'd1;
                end
            end
            BACKTRACK: begin
                pattern_idx <= star_idx + 5'd1;
                filename_idx <= star_match_idx + 5'd1;
                star_match_idx <= star_match_idx + 5'd1;
            end
            DONE_STATE: begin
                if (pattern_idx >= pattern_len && filename_idx >= filename_len) begin
                    match <= 1'b1;
                end else begin
                    match <= 1'b0;
                end
                done <= 1'b1;
                processing <= 1'b0;
            end
        endcase

        if (pattern_valid && processing) begin
            if (pattern_len < MAX_LEN) begin
                pattern_reg[pattern_len] <= pattern_char;
                pattern_len <= pattern_len + 5'd1;
            end
        end
        if (filename_valid && processing) begin
            if (filename_len < MAX_LEN) begin
                filename_reg[filename_len] <= filename_char;
                filename_len <= filename_len + 5'd1;
            end
        end
    end
end

endmodule