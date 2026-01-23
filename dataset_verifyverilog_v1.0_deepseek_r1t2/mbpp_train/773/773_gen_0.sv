module substring_search #(
    parameter TEXT_LEN = 32,
    parameter PATTERN_LEN = 8,
    parameter CHAR_WIDTH = 8
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [CHAR_WIDTH-1:0] text [0:TEXT_LEN-1],
    input wire [CHAR_WIDTH-1:0] pattern [0:PATTERN_LEN-1],
    input wire [5:0] text_valid_len,
    input wire [3:0] pattern_valid_len,
    output reg found,
    output reg [5:0] match_start,
    output reg [5:0] match_end,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] SEARCH   = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [5:0] text_idx;
    reg [3:0] pattern_idx;
    reg [7:0] cycle_count;
    reg match_in_progress;
    reg [5:0] current_start;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            found <= 1'b0;
            match_start <= 6'd0;
            match_end <= 6'd0;
            done <= 1'b0;
            text_idx <= 6'd0;
            pattern_idx <= 4'd0;
            cycle_count <= 8'd0;
            match_in_progress <= 1'b0;
            current_start <= 6'd0;
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SEARCH;
                        text_idx <= 6'd0;
                        pattern_idx <= 4'd0;
                        match_in_progress <= 1'b0;
                        current_start <= 6'd0;
                    end
                end
                
                SEARCH: begin
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= COMPLETE;
                        done <= 1'b1;
                    end
                    else if (text_idx >= text_valid_len) begin
                        state <= COMPLETE;
                        done <= 1'b1;
                    end
                    else if (pattern_valid_len == 4'd0) begin
                        state <= COMPLETE;
                        done <= 1'b1;
                        found <= 1'b0;
                    end
                    else if (text[text_idx] == pattern[pattern_idx]) begin
                        if (match_in_progress) begin
                            if (pattern_idx == pattern_valid_len - 4'd1) begin
                                found <= 1'b1;
                                match_start <= current_start;
                                match_end <= text_idx;
                                state <= COMPLETE;
                                done <= 1'b1;
                            end
                            else begin
                                pattern_idx <= pattern_idx + 4'd1;
                                text_idx <= text_idx + 6'd1;
                            end
                        end
                        else begin
                            match_in_progress <= 1'b1;
                            current_start <= text_idx;
                            pattern_idx <= 4'd1;
                            text_idx <= text_idx + 6'd1;
                        end
                    end
                    else begin
                        if (match_in_progress) begin
                            text_idx <= current_start + 6'd1;
                            pattern_idx <= 4'd0;
                            match_in_progress <= 1'b0;
                        end
                        else begin
                            text_idx <= text_idx + 6'd1;
                        end
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule