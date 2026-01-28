module untileable_cells #(
    parameter STREET_LEN = 16,
    parameter MAX_PATTERNS = 8,
    parameter MAX_PATTERN_LEN = 16,
    parameter CHAR_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] street_len,
    input wire [CHAR_WIDTH-1:0] street_chars [STREET_LEN-1:0],
    input wire [3:0] num_patterns,
    input wire [3:0] pattern_len [MAX_PATTERNS-1:0],
    input wire [CHAR_WIDTH-1:0] pattern_chars [MAX_PATTERNS-1:0][MAX_PATTERN_LEN-1:0],
    output reg [7:0] result,
    output reg done
);

// State encoding
localparam [2:0] IDLE = 3'd0;
localparam [2:0] CHECK = 3'd1;
localparam [2:0] UPDATE = 3'd2;
localparam [2:0] COUNT = 3'd3;

reg [2:0] state;
reg [STREET_LEN-1:0] coverage;
reg [3:0] pat_idx;
reg [3:0] pos_idx;
reg [7:0] result_reg;
reg match_found;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        coverage <= 0;
        result <= 8'd0;
        done <= 1'b0;
        pat_idx <= 4'd0;
        pos_idx <= 4'd0;
        result_reg <= 8'd0;
        match_found <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    coverage <= 0;
                    pat_idx <= 4'd0;
                    pos_idx <= 4'd0;
                    result_reg <= 8'd0;
                    state <= CHECK;
                end
            end
            
            CHECK: begin
                if (pat_idx < num_patterns) begin
                    if (pos_idx <= street_len - pattern_len[pat_idx]) begin
                        match_found <= 1'b1;
                        for (integer i = 0; i < MAX_PATTERN_LEN; i = i + 1) begin
                            if (i < pattern_len[pat_idx]) begin
                                if (pattern_chars[pat_idx][i] != street_chars[pos_idx + i]) begin
                                    match_found <= 1'b0;
                                end
                            end
                        end
                        state <= UPDATE;
                    end else begin
                        pat_idx <= pat_idx + 4'd1;
                        pos_idx <= 4'd0;
                    end
                end else begin
                    state <= COUNT;
                end
            end
            
            UPDATE: begin
                if (match_found) begin
                    for (integer i = 0; i < MAX_PATTERN_LEN; i = i + 1) begin
                        if (i < pattern_len[pat_idx]) begin
                            coverage[pos_idx + i] <= 1'b1;
                        end
                    end
                end
                pos_idx <= pos_idx + 4'd1;
                state <= CHECK;
            end
            
            COUNT: begin
                result_reg <= 8'd0;
                for (integer i = 0; i < STREET_LEN; i = i + 1) begin
                    if (i < street_len) begin
                        if (!coverage[i]) begin
                            result_reg <= result_reg + 8'd1;
                        end
                    end
                end
                result <= result_reg;
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule