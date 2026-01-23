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
    output reg done,
    output reg [4:0] count,
    output reg [CHAR_WIDTH-1:0] substring [0:MAX_T_LEN-1]
);

    // State encoding
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CLEAR_T = 3'd1;
    localparam [2:0] COMPUTE_T = 3'd2;
    localparam [2:0] CLEAR_S = 3'd3;
    localparam [2:0] CALC_PATTERN = 3'd4;
    localparam [2:0] COMPARE = 3'd5;
    localparam [2:0] INCREMENT_I = 3'd6;
    localparam [2:0] DONE = 3'd7;

    // Registers
    reg [2:0] state;
    reg [4:0] count_reg;
    reg [4:0] i_reg;
    reg [4:0] j_reg;
    reg [4:0] max_i;
    reg [4:0] len_S_reg;
    reg [4:0] len_T_reg;
    reg [MAX_S_LEN*CHAR_WIDTH-1:0] S_reg;
    reg [MAX_T_LEN*CHAR_WIDTH-1:0] T_reg;
    reg [PATTERNS_WIDTH-1:0] pattern_T_reg;
    reg [PATTERNS_WIDTH-1:0] pattern_S_reg;
    reg [3:0] mapping [0:25];
    reg [0:25] seen;
    reg [CHAR_WIDTH-1:0] substring_reg [0:MAX_T_LEN-1];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            count_reg <= 5'd0;
            i_reg <= 5'd0;
            j_reg <= 5'd0;
            len_S_reg <= 5'd0;
            len_T_reg <= 5'd0;
            S_reg <= {MAX_S_LEN*CHAR_WIDTH{1'b0}};
            T_reg <= {MAX_T_LEN*CHAR_WIDTH{1'b0}};
            pattern_T_reg <= {PATTERNS_WIDTH{1'b0}};
            pattern_S_reg <= {PATTERNS_WIDTH{1'b0}};
            for (integer i = 0; i < 26; i = i + 1) begin
                seen[i] <= 1'b0;
                mapping[i] <= 4'd0;
            end
            for (integer i = 0; i < MAX_T_LEN; i = i + 1) begin
                substring_reg[i] <= {CHAR_WIDTH{1'b0}};
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        S_reg <= S_flat;
                        T_reg <= T_flat;
                        len_S_reg <= len_S;
                        len_T_reg <= len_T;
                        count_reg <= 5'd0;
                        i_reg <= 5'd0;
                        j_reg <= 5'd0;
                        if (len_S < len_T) begin
                            state <= DONE;
                        end else begin
                            max_i <= len_S - len_T;
                            state <= CLEAR_T;
                        end
                    end
                end

                CLEAR_T: begin
                    for (integer i = 0; i < 26; i = i + 1) begin
                        seen[i] <= 1'b0;
                        mapping[i] <= 4'd0;
                    end
                    state <= COMPUTE_T;
                    j_reg <= 5'd0;
                end

                COMPUTE_T: begin
                    if (j_reg < len_T_reg) begin
                        if (T_reg[j_reg*CHAR_WIDTH +: CHAR_WIDTH] >= "a" && T_reg[j_reg*CHAR_WIDTH +: CHAR_WIDTH] <= "z") begin
                            if (seen[T_reg[j_reg*CHAR_WIDTH +: CHAR_WIDTH] - "a"] == 1'b0) begin
                                seen[T_reg[j_reg*CHAR_WIDTH +: CHAR_WIDTH] - "a"] <= 1'b1;
                                mapping[T_reg[j_reg*CHAR_WIDTH +: CHAR_WIDTH] - "a"] <= j_reg;
                                pattern_T_reg[4*j_reg+:4] <= j_reg;
                            end else begin
                                pattern_T_reg[4*j_reg+:4] <= mapping[T_reg[j_reg*CHAR_WIDTH +: CHAR_WIDTH] - "a"];
                            end
                        end
                        j_reg <= j_reg + 5'd1;
                    end else begin
                        state <= CLEAR_S;
                    end
                end

                CLEAR_S: begin
                    for (integer i = 0; i < 26; i = i + 1) begin
                        seen[i] <= 1'b0;
                        mapping[i] <= 4'd0;
                    end
                    state <= CALC_PATTERN;
                    j_reg <= 5'd0;
                end

                CALC_PATTERN: begin
                    if (j_reg < len_T_reg) begin
                        if (S_reg[(i_reg + j_reg)*CHAR_WIDTH +: CHAR_WIDTH] >= "a" && S_reg[(i_reg + j_reg)*CHAR_WIDTH +: CHAR_WIDTH] <= "z") begin
                            if (seen[S_reg[(i_reg + j_reg)*CHAR_WIDTH +: CHAR_WIDTH] - "a"] == 1'b0) begin
                                seen[S_reg[(i_reg + j_reg)*CHAR_WIDTH +: CHAR_WIDTH] - "a"] <= 1'b1;
                                mapping[S_reg[(i_reg + j_reg)*CHAR_WIDTH +: CHAR_WIDTH] - "a"] <= j_reg;
                                pattern_S_reg[4*j_reg+:4] <= j_reg;
                            end else begin
                                pattern_S_reg[4*j_reg+:4] <= mapping[S_reg[(i_reg + j_reg)*CHAR_WIDTH +: CHAR_WIDTH] - "a"];
                            end
                        end
                        j_reg <= j_reg + 5'd1;
                    end else begin
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    if ((pattern_S_reg & {len_T_reg{4'hF}, {(MAX_T_LEN - len_T_reg)*4{1'b0}}}) == (pattern_T_reg & {len_T_reg{4'hF}, {(MAX_T_LEN - len_T_reg)*4{1'b0}}})) begin
                        count_reg <= count_reg + 5'd1;
                        if (count_reg == 5'd1) begin
                            for (integer k = 0; k < MAX_T_LEN; k = k + 1) begin
                                if (k < len_T_reg) begin
                                    substring_reg[k] <= S_reg[(i_reg + k)*CHAR_WIDTH +: CHAR_WIDTH];
                                end else begin
                                    substring_reg[k] <= {CHAR_WIDTH{1'b0}};
                                end
                            end
                        end
                    end
                    state <= INCREMENT_I;
                end

                INCREMENT_I: begin
                    i_reg <= i_reg + 5'd1;
                    if (i_reg < max_i) begin
                        state <= CLEAR_S;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Assign outputs
    always @(*) begin
        count = count_reg;
        for (integer i = 0; i < MAX_T_LEN; i = i + 1) begin
            substring[i] = substring_reg[i];
        end
    end

endmodule