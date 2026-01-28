module StringPatternMatcher(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] text_length,
    input wire [3:0] pattern_length,
    input wire [7:0] text_char [0:63],
    input wire [7:0] pattern_char [0:15],
    output reg [5:0] start_index,
    output reg [5:0] end_index,
    output reg found,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] SEARCHING = 2'd1;
    localparam [1:0] MATCHING  = 2'd2;
    localparam [1:0] COMPLETE  = 2'd3;

    reg [1:0] state, next_state;
    reg [5:0] text_pos;
    reg [3:0] pattern_pos;
    reg [5:0] match_start;
    reg match_found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1024;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SEARCHING;
                end else begin
                    next_state = IDLE;
                end
            end

            SEARCHING: begin
                if (text_pos > (text_length - pattern_length)) begin
                    next_state = COMPLETE;
                end else if (text_char[text_pos] == pattern_char[0]) begin
                    next_state = MATCHING;
                end else begin
                    next_state = SEARCHING;
                end
            end

            MATCHING: begin
                if (pattern_pos == (pattern_length - 1)) begin
                    if (text_char[text_pos + pattern_pos] == pattern_char[pattern_pos]) begin
                        next_state = COMPLETE;
                    end else begin
                        next_state = SEARCHING;
                    end
                end else if (text_char[text_pos + pattern_pos] == pattern_char[pattern_pos]) begin
                    next_state = MATCHING;
                end else begin
                    next_state = SEARCHING;
                end
            end

            COMPLETE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            text_pos <= 6'd0;
            pattern_pos <= 4'd0;
            match_start <= 6'd0;
            match_found <= 1'b0;
            start_index <= 6'd0;
            end_index <= 6'd0;
            found <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            done <= 1'b0;

            case (state)
                IDLE: begin
                    text_pos <= 6'd0;
                    pattern_pos <= 4'd0;
                    match_found <= 1'b0;
                    found <= 1'b0;
                    start_index <= 6'd64;
                    end_index <= 6'd64;
                    cycle_count <= 8'd0;
                end

                SEARCHING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (text_pos > (text_length - pattern_length)) begin
                        match_found <= 1'b0;
                        done <= 1'b1;
                    end else if (text_char[text_pos] == pattern_char[0]) begin
                        match_start <= text_pos;
                        pattern_pos <= 4'd1;
                    end else begin
                        text_pos <= text_pos + 6'd1;
                    end
                end

                MATCHING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (pattern_pos == (pattern_length - 1)) begin
                        if (text_char[text_pos + pattern_pos] == pattern_char[pattern_pos]) begin
                            match_found <= 1'b1;
                            start_index <= match_start;
                            end_index <= match_start + pattern_length;
                            done <= 1'b1;
                        end else begin
                            text_pos <= text_pos + 6'd1;
                            pattern_pos <= 4'd0;
                        end
                    end else if (text_char[text_pos + pattern_pos] == pattern_char[pattern_pos]) begin
                        pattern_pos <= pattern_pos + 4'd1;
                    end else begin
                        text_pos <= text_pos + 6'd1;
                        pattern_pos <= 4'd0;
                    end
                end

                COMPLETE: begin
                    found <= match_found;
                    if (match_found) begin
                        start_index <= match_start;
                        end_index <= match_start + pattern_length;
                    end else begin
                        start_index <= 6'd64;
                        end_index <= 6'd64;
                    end
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    text_pos <= 6'd0;
                    pattern_pos <= 4'd0;
                    match_found <= 1'b0;
                    found <= 1'b0;
                    start_index <= 6'd64;
                    end_index <= 6'd64;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

endmodule