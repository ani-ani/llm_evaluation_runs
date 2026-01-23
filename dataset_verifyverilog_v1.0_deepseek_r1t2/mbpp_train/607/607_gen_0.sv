module string_matcher(
    input clk,
    input rst_n,
    input start,
    input [5:0] text_length,
    input [3:0] pattern_length,
    input [7:0] text_char [0:63],
    input [7:0] pattern_char [0:15],
    output reg [5:0] start_index,
    output reg [5:0] end_index,
    output reg found,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] SEARCHING = 2'd1;
    localparam [1:0] MATCHING  = 2'd2;
    localparam [1:0] COMPLETE   = 2'd3;

    reg [1:0] state;
    reg [5:0] pos;
    reg [3:0] i;
    reg [5:0] text_len_reg;
    reg [3:0] pat_len_reg;
    reg [5:0] max_pos;
    reg found_flag;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            start_index <= 6'd0;
            end_index <= 6'd0;
            found <= 1'b0;
            done <= 1'b0;
            pos <= 6'd0;
            i <= 4'd0;
            text_len_reg <= 6'd0;
            pat_len_reg <= 4'd0;
            max_pos <= 6'd0;
            found_flag <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        text_len_reg <= text_length;
                        pat_len_reg <= pattern_length;
                        if (pattern_length > text_length) begin
                            found_flag <= 1'b0;
                            start_index <= 6'd64;
                            end_index <= 6'd64;
                            state <= COMPLETE;
                        end else begin
                            max_pos <= text_length - pattern_length;
                            pos <= 6'd0;
                            state <= SEARCHING;
                        end
                    end
                end

                SEARCHING: begin
                    if (pos > max_pos) begin
                        found_flag <= 1'b0;
                        start_index <= 6'd64;
                        end_index <= 6'd64;
                        state <= COMPLETE;
                    end else begin
                        i <= 4'd0;
                        state <= MATCHING;
                    end
                end

                MATCHING: begin
                    if (text_char[pos + i] != pattern_char[i]) begin
                        pos <= pos + 6'd1;
                        state <= SEARCHING;
                    end else begin
                        if (i == pat_len_reg - 4'd1) begin
                            found_flag <= 1'b1;
                            start_index <= pos;
                            end_index <= pos + {2'd0, pat_len_reg};
                            state <= COMPLETE;
                        end else begin
                            i <= i + 4'd1;
                        end
                    end
                end

                COMPLETE: begin
                    found <= found_flag;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule