module substring_search #(
    parameter TEXT_LEN = 32,
    parameter PATTERN_LEN = 8,
    parameter CHAR_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [CHAR_WIDTH-1:0] text[0:TEXT_LEN-1],
    input wire [CHAR_WIDTH-1:0] pattern[0:PATTERN_LEN-1],
    input wire [5:0] text_valid_len,
    input wire [3:0] pattern_valid_len,
    output reg found,
    output reg [5:0] match_start,
    output reg [5:0] match_end,
    output reg done
);

localparam [1:0] IDLE = 2'd0;
localparam [1:0] SEARCH = 2'd1;
localparam [1:0] COMPLETE = 2'd2;

reg [1:0] state;
reg [5:0] text_idx;
reg [3:0] pattern_idx;
reg match_in_progress;
reg [5:0] current_match_start;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        found <= 1'b0;
        match_start <= 6'd0;
        match_end <= 6'd0;
        done <= 1'b0;
        text_idx <= 6'd0;
        pattern_idx <= 4'd0;
        match_in_progress <= 1'b0;
        current_match_start <= 6'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start && text_valid_len > 0 && pattern_valid_len > 0) begin
                    state <= SEARCH;
                    text_idx <= 6'd0;
                    pattern_idx <= 4'd0;
                    match_in_progress <= 1'b0;
                    found <= 1'b0;
                end
            end
            
            SEARCH: begin
                if (text_idx < text_valid_len) begin
                    if (text[text_idx] == pattern[pattern_idx]) begin
                        if (!match_in_progress) begin
                            match_in_progress <= 1'b1;
                            current_match_start <= text_idx;
                            pattern_idx <= 4'd1;
                        end else begin
                            pattern_idx <= pattern_idx + 4'd1;
                        end
                        text_idx <= text_idx + 6'd1;
                        if (pattern_idx == pattern_valid_len - 4'd1) begin
                            found <= 1'b1;
                            match_start <= current_match_start;
                            match_end <= text_idx + 6'd1;
                            state <= COMPLETE;
                            done <= 1'b1;
                            match_in_progress <= 1'b0;
                        end
                    end else begin
                        if (match_in_progress && text[text_idx] == pattern[0]) begin
                            current_match_start <= text_idx;
                            pattern_idx <= 4'd1;
                            text_idx <= text_idx + 6'd1;
                        end else begin
                            match_in_progress <= 1'b0;
                            pattern_idx <= 4'd0;
                            text_idx <= text_idx + 6'd1;
                        end
                    end
                end else begin
                    state <= COMPLETE;
                    done <= 1'b1;
                    found <= 1'b0;
                    match_start <= 6'd0;
                    match_end <= 6'd0;
                end
            end
            
            COMPLETE: begin
                if (!start) begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule