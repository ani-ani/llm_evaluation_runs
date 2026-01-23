module find_fragment #(
    parameter MAX_S_LEN = 16,
    parameter MAX_T_LEN = 16,
    parameter CHAR_WIDTH = 8,
    parameter PATTERNS_WIDTH = 4 * MAX_T_LEN
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [MAX_S_LEN*CHAR_WIDTH-1:0] S_flat,
    input wire [MAX_T_LEN*CHAR_WIDTH-1:0] T_flat,
    input wire [4:0] len_S,
    input wire [4:0] len_T,
    output wire done,
    output wire [4:0] count,
    output wire [CHAR_WIDTH-1:0] substring [0:MAX_T_LEN-1]
);

    // State encoding
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] CLEAR_T      = 3'd1;
    localparam [2:0] COMPUTE_T    = 3'd2;
    localparam [2:0] CLEAR_S      = 3'd3;
    localparam [2:0] CALC_PATTERN = 3'd4;
    localparam [2:0] COMPARE      = 3'd5;
    localparam [2:0] INCREMENT_I  = 3'd6;
    localparam [2:0] DONE_STATE   = 3'd7;

    // Registers
    reg [2:0] state;
    reg done_reg;
    reg [4:0] count_reg;
    reg [4:0] i_reg;
    reg [4:0] j_reg;
    reg [4:0] max_i_reg;
    reg [4:0] len_S_reg;
    reg [4:0] len_T_reg;
    reg [MAX_S_LEN*CHAR_WIDTH-1:0] S_reg;
    reg [MAX_T_LEN*CHAR_WIDTH-1:0] T_reg;
    reg [PATTERNS_WIDTH-1:0] pattern_T_reg;
    reg [PATTERNS_WIDTH-1:0] pattern_S_reg;
    reg [3:0] mapping [0:25];
    reg [0:25] seen;
    reg [CHAR_WIDTH-1:0] substring_reg [0:MAX_T_LEN-1];

    // Temporary variables
    reg [CHAR_WIDTH-1:0] char_T;
    reg [CHAR_WIDTH-1:0] char_S;
    reg [4:0] idx;
    reg [4:0] idx_S;
    reg [PATTERNS_WIDTH-1:0] mask;
    reg [3:0] k;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done_reg <= 1'b0;
            count_reg <= 5'd0;
            i_reg <= 5'd0;
            j_reg <= 5'd0;
            max_i_reg <= 5'd0;
            len_S_reg <= 5'd0;
            len_T_reg <= 5'd0;
            S_reg <= {(MAX_S_LEN*CHAR_WIDTH){1'b0}};
            T_reg <= {(MAX_T_LEN*CHAR_WIDTH){1'b0}};
            pattern_T_reg <= {PATTERNS_WIDTH{1'b0}};
            pattern_S_reg <= {PATTERNS_WIDTH{1'b0}};
            for (k = 0; k < 26; k = k + 1) begin
                seen[k] <= 1'b0;
                mapping[k] <= 4'd0;
            end
            for (k = 0; k < MAX_T_LEN; k = k + 1) begin
                substring_reg[k] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    if (start) begin
                        S_reg <= S_flat;
                        T_reg <= T_flat;
                        len_S_reg <= len_S;
                        len_T_reg <= len_T;
                        count_reg <= 5'd0;
                        i_reg <= 5'd0;
                        j_reg <= 5'd0;
                        if (len_S < len_T) begin
                            state <= DONE_STATE;
                        end else begin
                            max_i_reg <= len_S - len_T;
                            state <= CLEAR_T;
                        end
                    end
                end

                CLEAR_T: begin
                    for (k = 0; k < 26; k = k + 1) begin
                        seen[k] <= 1'b0;
                        mapping[k] <= 4'd0;
                    end
                    state <= COMPUTE_T;
                    j_reg <= 5'd0;
                end

                COMPUTE_T: begin
                    if (j_reg < len_T_reg) begin
                        char_T = T_reg[j_reg*CHAR_WIDTH +: CHAR_WIDTH];
                        idx = char_T - 8'd97;
                        if (seen[idx] == 0) begin
                            seen[idx] <= 1'b1;
                            mapping[idx] <= j_reg[3:0];
                            pattern_T_reg[4*j_reg+:4] <= j_reg[3:0];
                        end else begin
                            pattern_T_reg[4*j_reg+:4] <= mapping[idx];
                        end
                        j_reg <= j_reg + 5'd1;
                    end else begin
                        state <= CLEAR_S;
                    end
                end

                CLEAR_S: begin
                    for (k = 0; k < 26; k = k + 1) begin
                        seen[k] <= 1'b0;
                        mapping[k] <= 4'd0;
                    end
                    state <= CALC_PATTERN;
                    j_reg <= 5'd0;
                end

                CALC_PATTERN: begin
                    if (j_reg < len_T_reg) begin
                        idx_S = i_reg + j_reg;
                        char_S = S_reg[idx_S*CHAR_WIDTH +: CHAR_WIDTH];
                        idx = char_S - 8'd97;
                        if (seen[idx] == 0) begin
                            seen[idx] <= 1'b1;
                            mapping[idx] <= j_reg[3:0];
                            pattern_S_reg[4*j_reg+:4] <= j_reg[3:0];
                        end else begin
                            pattern_S_reg[4*j_reg+:4] <= mapping[idx];
                        end
                        j_reg <= j_reg + 5'd1;
                    end else begin
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    mask = {PATTERNS_WIDTH{1'b0}};
                    for (k = 0; k < MAX_T_LEN; k = k + 1) begin
                        if (k < len_T_reg) begin
                            mask[4*k+:4] = 4'hF;
                        end
                    end
                    if ((pattern_S_reg & mask) == (pattern_T_reg & mask)) begin
                        count_reg <= count_reg + 5'd1;
                        if (count_reg == 5'd0) begin
                            for (k = 0; k < MAX_T_LEN; k = k + 1) begin
                                if (k < len_T_reg) begin
                                    substring_reg[k] <= S_reg[(i_reg + k)*CHAR_WIDTH +: CHAR_WIDTH];
                                end else begin
                                    substring_reg[k] <= 8'd0;
                                end
                            end
                        end
                    end
                    state <= INCREMENT_I;
                end

                INCREMENT_I: begin
                    i_reg <= i_reg + 5'd1;
                    if (i_reg < max_i_reg) begin
                        state <= CLEAR_S;
                    end else begin
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done_reg <= 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Continuous assignments
    assign done = done_reg;
    assign count = count_reg;
    assign substring = substring_reg;

endmodule