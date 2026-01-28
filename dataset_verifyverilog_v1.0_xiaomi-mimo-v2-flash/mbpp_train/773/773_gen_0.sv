module pattern_search (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] text [0:15],
    input wire [7:0] pattern [0:15],
    input wire [3:0] text_len,
    input wire [3:0] pattern_len,
    output reg done,
    output reg valid,
    output reg [7:0] match_substring [0:15],
    output reg [3:0] start_idx,
    output reg [4:0] end_idx,
    output reg no_valid
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_LEN = 3'd1;
    localparam [2:0] LOAD_DATA = 3'd2;
    localparam [2:0] COMPARE = 3'd3;
    localparam [2:0] MATCH_FOUND = 3'd4;
    localparam [2:0] NO_MATCH = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    // Internal registers
    reg [2:0] state;
    reg [7:0] text_reg [0:15];
    reg [7:0] pattern_reg [0:15];
    reg [3:0] text_len_reg;
    reg [3:0] pattern_len_reg;
    reg [3:0] i;  // Outer loop: text position
    reg [3:0] j;  // Inner loop: pattern position
    reg [3:0] match_pos;  // Store match start position
    reg [7:0] temp_substring [0:15];
    reg [3:0] temp_start;
    reg [4:0] temp_end;
    reg match_flag;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            no_valid <= 1'b0;
            start_idx <= 4'd0;
            end_idx <= 5'd0;
            i <= 4'd0;
            j <= 4'd0;
            match_pos <= 4'd0;
            match_flag <= 1'b0;
            cycle_count <= 8'd0;
            text_len_reg <= 4'd0;
            pattern_len_reg <= 4'd0;
            for (k = 0; k < 16; k = k + 1) begin
                text_reg[k] <= 8'd0;
                pattern_reg[k] <= 8'd0;
                match_substring[k] <= 8'd0;
                temp_substring[k] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    no_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK_LEN;
                        text_len_reg <= text_len;
                        pattern_len_reg <= pattern_len;
                    end
                end

                CHECK_LEN: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Check if pattern is empty or longer than text
                    if (pattern_len_reg == 4'd0 || pattern_len_reg > text_len_reg) begin
                        state <= NO_MATCH;
                    end else begin
                        state <= LOAD_DATA;
                        i <= 4'd0;
                    end
                end

                LOAD_DATA: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Load text and pattern into registers
                    for (k = 0; k < 16; k = k + 1) begin
                        text_reg[k] <= text[k];
                        pattern_reg[k] <= pattern[k];
                    end
                    state <= COMPARE;
                    i <= 4'd0;
                    j <= 4'd0;
                    match_flag <= 1'b0;
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Outer loop: check each possible starting position
                    if (i <= (text_len_reg - pattern_len_reg)) begin
                        // Inner loop: compare pattern against text at position i
                        if (j < pattern_len_reg) begin
                            if (text_reg[i + j] == pattern_reg[j]) begin
                                // Match at this position, continue
                                j <= j + 4'd1;
                            end else begin
                                // Mismatch, move to next text position
                                j <= 4'd0;
                                i <= i + 4'd1;
                            end
                        end else begin
                            // All pattern characters matched
                            match_flag <= 1'b1;
                            match_pos <= i;
                            state <= MATCH_FOUND;
                        end
                    end else begin
                        // Reached end of text without finding match
                        state <= NO_MATCH;
                    end
                end

                MATCH_FOUND: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Build the matched substring
                    for (k = 0; k < 16; k = k + 1) begin
                        if (k < pattern_len_reg) begin
                            temp_substring[k] <= pattern_reg[k];
                        end else begin
                            temp_substring[k] <= 8'd0;
                        end
                    end
                    temp_start <= match_pos;
                    temp_end <= match_pos + pattern_len_reg;
                    state <= DONE_STATE;
                    valid <= 1'b1;
                    no_valid <= 1'b0;
                end

                NO_MATCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    valid <= 1'b0;
                    no_valid <= 1'b1;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    // Output the results
                    for (k = 0; k < 16; k = k + 1) begin
                        match_substring[k] <= temp_substring[k];
                    end
                    start_idx <= temp_start;
                    end_idx <= temp_end;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 1'b0;
                    no_valid <= 1'b0;
                end
            endcase
        end
    end
endmodule