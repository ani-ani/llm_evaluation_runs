module password_recovery (
    input clk,
    input rst_n,
    input start,
    
    // Configuration
    input [7:0] K,          // Iterations (1-256)
    input [3:0] M,          // Queries (1-8)
    
    // Data loading interface
    input load_en,
    input [4:0] load_addr,  // 0-15=S, 16-41=T[0-25]
    input [7:0] load_data,
    input [3:0] load_len,   // Length for current entity
    
    // Query loading
    input query_load_en,
    input [2:0] query_addr,
    input [31:0] query_pos,
    
    // Results
    output reg [7:0] result_char,
    output reg [2:0] result_addr,
    output reg result_valid,
    output reg done,
    output reg error
);

// Memory arrays
reg [7:0] S [0:15];
reg [3:0] S_len;
reg [7:0] T [0:25][0:7];
reg [3:0] T_len [0:25];
reg [31:0] query_pos_arr [0:7];
reg [7:0] results [0:7];

// Length table: length_table[c][k] = length of expanding char c k times
reg [31:0] length_table [0:25][0:256];

// State machine
reg [3:0] state;
localparam [3:0] IDLE = 4'd0;
localparam [3:0] PRECOMP = 4'd1;
localparam [3:0] PRECOMP_LOOP = 4'd2;
localparam [3:0] PRECOMP_SUM = 4'd3;
localparam [3:0] COMPUTE = 4'd4;
localparam [3:0] FIND_CHAR = 4'd5;
localparam [3:0] UPDATE = 4'd6;
localparam [3:0] OUTPUT = 4'd7;
localparam [3:0] DONE = 4'd8;

// Processing registers
reg [7:0] cur_q;
reg [7:0] cur_level;
reg [7:0] cur_char;
reg [31:0] cur_pos;
reg [31:0] cumulative;
reg [3:0] cur_len;
reg [3:0] idx;
reg [7:0] cur_str [0:7];
reg [7:0] pc;
reg [3:0] pl;
reg [3:0] pi;
reg [31:0] temp_sum;

integer i;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        error <= 1'b0;
        result_valid <= 1'b0;
        result_addr <= 3'd0;
        
        // Initialize all registers
        cur_q <= 8'd0;
        cur_level <= 8'd0;
        cur_char <= 8'd0;
        cur_pos <= 32'd0;
        cumulative <= 32'd0;
        cur_len <= 4'd0;
        idx <= 4'd0;
        pc <= 8'd0;
        pl <= 4'd0;
        pi <= 4'd0;
        temp_sum <= 32'd0;
        
        // Initialize arrays
        for (i = 0; i < 16; i = i + 1) begin
            S[i] <= 8'd0;
        end
        S_len <= 4'd0;
        
        for (i = 0; i < 26; i = i + 1) begin
            T_len[i] <= 4'd0;
            for (integer j = 0; j < 8; j = j + 1) begin
                T[i][j] <= 8'd0;
            end
        end
        
        for (i = 0; i < 8; i = i + 1) begin
            query_pos_arr[i] <= 32'd0;
            results[i] <= 8'd0;
        end
        
        for (i = 0; i < 26; i = i + 1) begin
            for (integer j = 0; j < 256; j = j + 1) begin
                length_table[i][j] <= 32'd0;
            end
        end
        
        for (i = 0; i < 8; i = i + 1) begin
            cur_str[i] <= 8'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                if (load_en) begin
                    if (load_addr < 16) begin
                        S[load_addr] <= load_data;
                        if (load_addr == 15) begin
                            S_len <= load_len;
                        end
                    end else if (load_addr >= 16 && load_addr < 42) begin
                        integer char_idx = load_addr - 16;
                        integer char_pos = load_len[2:0];
                        T[char_idx][char_pos] <= load_data;
                        T_len[char_idx] <= load_len[7:4];
                    end
                end
                
                if (query_load_en) begin
                    query_pos_arr[query_addr] <= query_pos;
                end
                
                if (start && load_addr == 41) begin
                    if (S_len == 0 || K == 0 || K > 256 || M == 0 || M > 8) begin
                        error <= 1'b1;
                        state <= DONE;
                    end else begin
                        cur_q <= 8'd0;
                        pc <= 8'd0;
                        pl <= 4'd0;
                        state <= PRECOMP;
                    end
                end
            end
            
            PRECOMP: begin
                if (pc < 26) begin
                    length_table[pc][0] <= 32'd1;
                    pc <= pc + 8'd1;
                end else begin
                    pc <= 8'd0;
                    pl <= 4'd1;
                    if (K > 0) begin
                        state <= PRECOMP_LOOP;
                    end else begin
                        state <= COMPUTE;
                    end
                end
            end
            
            PRECOMP_LOOP: begin
                if (pl <= K) begin
                    if (pc < 26) begin
                        temp_sum <= 32'd0;
                        pi <= 4'd0;
                        state <= PRECOMP_SUM;
                    end else begin
                        pc <= 8'd0;
                        pl <= pl + 4'd1;
                    end
                end else begin
                    state <= COMPUTE;
                end
            end
            
            PRECOMP_SUM: begin
                if (pi < T_len[pc]) begin
                    temp_sum <= temp_sum + length_table[T[pc][pi]][pl-1];
                    pi <= pi + 4'd1;
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
                        if (i < S_len) begin
                            cur_str[i] <= S[i];
                        end else begin
                            cur_str[i] <= 8'd0;
                        end
                    end
                    
                    state <= FIND_CHAR;
                end else begin
                    state <= OUTPUT;
                end
            end
            
            FIND_CHAR: begin
                if (cur_level == 0) begin
                    if (cur_pos > 0 && cur_pos <= cur_len) begin
                        results[cur_q] <= cur_str[cur_pos-1];
                        cur_q <= cur_q + 8'd1;
                        state <= COMPUTE;
                    end else begin
                        error <= 1'b1;
                        state <= DONE;
                    end
                end else begin
                    cumulative <= 32'd0;
                    idx <= 4'd0;
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
                            if (i < T_len[cur_str[idx]]) begin
                                cur_str[i] <= T[cur_str[idx]][i];
                            end else begin
                                cur_str[i] <= 8'd0;
                            end
                        end
                        
                        cur_level <= cur_level - 8'd1;
                        state <= FIND_CHAR;
                    end else begin
                        cumulative <= cumulative + length_table[cur_str[idx]][cur_level];
                        idx <= idx + 4'd1;
                    end
                end else begin
                    error <= 1'b1;
                    state <= DONE;
                end
            end
            
            OUTPUT: begin
                if (result_addr < M) begin
                    result_char <= results[result_addr];
                    result_addr <= result_addr + 3'd1;
                    result_valid <= 1'b1;
                end else begin
                    result_valid <= 1'b0;
                    done <= 1'b1;
                    state <= DONE;
                end
            end
            
            DONE: begin
                if (!start) begin
                    state <= IDLE;
                    done <= 1'b0;
                    result_addr <= 3'd0;
                end
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule