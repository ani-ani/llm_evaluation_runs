module search_steps(
    input clk,
    input rst_n,
    input load_db,
    input [3:0] db_word_idx,
    input [79:0] db_word_in,
    input search_start,
    input [79:0] query_word,
    output reg [15:0] result,
    output reg done
);

    localparam [3:0] MAX_WORDS = 4'd16;
    localparam [3:0] MAX_LEN = 4'd16;
    localparam [4:0] CHAR_BITS = 5'd5;

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPARE_CHAR = 3'd2;
    localparam [2:0] NEXT_WORD = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [79:0] db_mem [0:15];
    reg [3:0] idx_cnt;
    reg [3:0] char_idx;
    reg [15:0] result_reg;
    reg [15:0] steps_cnt;
    reg [4:0] char_q, char_d;
    reg match_flag;
    reg exact_match;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            idx_cnt <= 4'd0;
            char_idx <= 4'd0;
            result_reg <= 16'd0;
            steps_cnt <= 16'd0;
            match_flag <= 1'b0;
            exact_match <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (load_db) begin
                    next_state = LOAD;
                end else if (search_start) begin
                    next_state = COMPARE_CHAR;
                    result_reg = 16'd0;
                    steps_cnt = 16'd0;
                    idx_cnt = 4'd0;
                    char_idx = 4'd0;
                    match_flag = 1'b0;
                    exact_match = 1'b0;
                end
            end
            LOAD: begin
                if (!load_db) begin
                    next_state = IDLE;
                end
            end
            COMPARE_CHAR: begin
                char_q = query_word[(char_idx + 1'b1) * CHAR_BITS - 1'b1 : char_idx * CHAR_BITS];
                char_d = db_mem[idx_cnt][(char_idx + 1'b1) * CHAR_BITS - 1'b1 : char_idx * CHAR_BITS];
                if (char_q == char_d && char_idx < MAX_LEN - 1'b1) begin
                    char_idx = char_idx + 1'b1;
                end else begin
                    result_reg = result_reg + char_idx + 1'b1;
                    if (char_idx == MAX_LEN - 1'b1) begin
                        exact_match = 1'b1;
                    end
                    next_state = NEXT_WORD;
                end
            end
            NEXT_WORD: begin
                if (exact_match || idx_cnt == MAX_WORDS - 1'b1) begin
                    next_state = DONE_STATE;
                end else begin
                    idx_cnt = idx_cnt + 1'b1;
                    char_idx = 4'd0;
                    next_state = COMPARE_CHAR;
                end
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (load_db) begin
            db_mem[db_word_idx] <= db_word_in;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            if (state == DONE_STATE) begin
                result <= result_reg;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule