module password_recovery (
    input clk,
    input rst_n,
    input start,
    input [7:0] K,
    input [3:0] M,
    input load_en,
    input [4:0] load_addr,
    input [7:0] load_data,
    input [3:0] load_len,
    input query_load_en,
    input [2:0] query_addr,
    input [31:0] query_pos,
    output reg [7:0] result_char,
    output reg [2:0] result_addr,
    output reg result_valid,
    output reg done,
    output reg error
);

reg [7:0] S [0:15];
reg [3:0] S_len;
reg [7:0] T [0:25][0:7];
reg [3:0] T_len [0:25];
reg [31:0] query_pos_arr [0:7];
reg [7:0] results [0:7];
reg [31:0] length_table [0:25][0:256];

reg [3:0] state;
localparam IDLE = 4'd0;
localparam PRECOMP = 4'd1;
localparam PRECOMP_LOOP = 4'd2;
localparam PRECOMP_SUM = 4'd3;
localparam COMPUTE = 4'd4;
localparam FIND_CHAR = 4'd5;
localparam UPDATE = 4'd6;
localparam OUTPUT = 4'd7;
localparam DONE = 4'd8;

reg [7:0] cur_q;
reg [7:0] cur_level;
reg [7:0] cur_char;
reg [31:0] cur_pos;
reg [31:0] cumulative;
reg [3:0] cur_len;
reg [3:0] idx;
reg [7:0] cur_str [0:7];
reg [7:0] pc;
reg [7:0] pl;
reg [3:0] pi;
reg [31:0] temp_sum;
reg [3:0] i;
reg [7:0] char_idx;
reg [3:0] char_pos;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        error <= 0;
        result_valid <= 0;
        result_addr <= 0;
        S_len <= 0;
        cur_q <= 0;
        pc <= 0;
        pl <= 0;
        pi <= 0;
        temp_sum <= 0;
        cumulative <= 0;
        cur_pos <= 0;
        cur_len <= 0;
        cur_level <= 0;
        cur_char <= 0;
        for (i = 0; i < 16; i = i + 1) S[i] <= 8'd0;
        for (i = 0; i < 26; i = i + 1) begin
            T_len[i] <= 4'd0;
            for (int j = 0; j < 8; j = j + 1) T[i][j] <= 8'd0;
        end
        for (i = 0; i < 8; i = i + 1) begin
            query_pos_arr[i] <= 32'd0;
            results[i] <= 8'd0;
            cur_str[i] <= 8'd0;
        end
        for (i = 0; i < 26; i = i + 1) begin
            for (int j = 0; j < 256; j = j + 1) length_table[i][j] <= 32'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                error <= 0;
                result_valid <= 0;
                result_addr <= 0;
                if (load_en) begin
                    if (load_addr < 16) begin
                        S[load_addr] <= load_data;
                        S_len <= load_len;
                    end else if (load_addr >= 16 && load_addr < 42) begin
                        char_idx <= load_addr - 16;
                        char_pos <= load_len[2:0];
                        T[load_addr - 16][load_len[2:0]] <= load_data;
                        T_len[load_addr - 16] <= load_len[7:4];
                    end
                end
                if (query_load_en) begin
                    query_pos_arr[query_addr] <= query_pos;
                end
                if (start && load_addr == 41) begin
                    if (S_len == 0 || K == 0 || K > 8'd256 || M == 0 || M > 8) begin
                        error <= 1;
                        state <= DONE;
                    end else begin
                        cur_q <= 0;
                        pc <= 0;
                        pl <= 0;
                        state <= PRECOMP;
                    end
                end
            end

            PRECOMP: begin
                if (pc < 26) begin
                    length_table[pc][0] <= 32'd1;
                    pc <= pc + 8'd1;
                end else begin
                    pc <= 0;
                    pl <= 8'd1;
                    state <= (K > 0) ? PRECOMP_LOOP : COMPUTE;
                end
            end

            PRECOMP_LOOP: begin
                if (pl <= K) begin
                    if (pc < 26) begin
                        temp_sum <= 32'd0;
                        pi <= 0;
                        state <= PRECOMP_SUM;
                    end else begin
                        pc <= 0;
                        pl <= pl + 8'd1;
                    end
                end else begin
                    state <= COMPUTE;
                end
            end

            PRECOMP_SUM: begin
                if (pi < T_len[pc]) begin
                    temp_sum <= temp_sum + length_table[T[pc][pi]][pl - 1];
                    pi <= pi + 8'd1;
                end else begin
                    length_table[pc][pl] <= temp_sum;
                    pc <= pc + 8'd1;
                    state <= PRECOMP_LOOP;
                end
            end

            COMPUTE: begin
                if (cur_q < M) begin
                    cur_level <= K;
                    cur_len <= S_len;
                    cur_pos <= query_pos_arr[cur_q];
                    for (i = 0; i < 8; i = i + 1) begin
                        cur_str[i] <= (i < S_len) ? S[i] : 8'd0;
                    end
                    state <= FIND_CHAR;
                end else begin
                    state <= OUTPUT;
                end
            end

            FIND_CHAR: begin
                if (cur_level == 0) begin
                    if (cur_pos > 0 && cur_pos <= cur_len) begin
                        results[cur_q] <= cur_str[cur_pos - 1];
                        cur_q <= cur_q + 8'd1;
                        state <= COMPUTE;
                    end else begin
                        error <= 1;
                        state <= DONE;
                    end
                end else begin
                    cumulative <= 32'd0;
                    idx <= 0;
                    state <= UPDATE;
                end
            end

            UPDATE: begin
                if (idx < cur_len) begin
                    cur_char <= cur_str[idx];
                    if (cur_pos <= cumulative + length_table[cur_str[idx]][cur_level]) begin
                        cur_pos <= cur_pos - cumulative;
                        cur_len <= T_len[cur_str[idx]];
                        for (i = 0; i < 8; i = i + 1) begin
                            cur_str[i] <= (i < T_len[cur_str[idx]]) ? T[cur_str[idx]][i] : 8'd0;
                        end
                        cur_level <= cur_level - 8'd1;
                        state <= FIND_CHAR;
                    end else begin
                        cumulative <= cumulative + length_table[cur_str[idx]][cur_level];
                        idx <= idx + 8'd1;
                    end
                end else begin
                    error <= 1;
                    state <= DONE;
                end
            end

            OUTPUT: begin
                if (result_addr < M) begin
                    result_char <= results[result_addr];
                    result_addr <= result_addr + 3'd1;
                    result_valid <= 1;
                end else begin
                    result_valid <= 0;
                    done <= 1;
                    state <= DONE;
                end
            end

            DONE: begin
                if (!start) begin
                    state <= IDLE;
                    done <= 0;
                    result_addr <= 0;
                end
            end

            default: state <= IDLE;
        endcase
    end
end

endmodule