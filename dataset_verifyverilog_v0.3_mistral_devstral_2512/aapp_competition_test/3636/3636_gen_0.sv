module min_obstacles_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [4:0] m,
    input wire [31:0] p,
    output reg [31:0] result,
    output reg done
);

    // State machine states
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT_PRECOMP = 4'd1;
    localparam [3:0] INIT_DP = 4'd2;
    localparam [3:0] START_COLUMN = 4'd3;
    localparam [3:0] LOOP_CUR = 4'd4;
    localparam [3:0] LOOP_PREV = 4'd5;
    localparam [3:0] COMPUTE_CANDIDATE = 4'd6;
    localparam [3:0] NEXT_PREV = 4'd7;
    localparam [3:0] NEXT_CUR = 4'd8;
    localparam [3:0] NEXT_COLUMN = 4'd9;
    localparam [3:0] FINALIZE = 4'd10;
    localparam [3:0] DONE_STATE = 4'd11;

    // Parameters
    parameter N_MAX = 8;
    parameter STATE_COUNT = 1 << N_MAX;
    parameter M_MAX = 16;

    // Internal registers
    reg [3:0] current_state, next_state;
    reg [7:0] cur_state;
    reg [7:0] prev_state;
    reg [7:0] state_limit;
    reg [7:0] col_index;
    reg [7:0] popcount_cur;
    reg [7:0] tmp_min;
    reg [31:0] tmp_cnt;
    reg [7:0] global_min;
    reg [31:0] global_cnt;

    // DP arrays
    reg [7:0] dp_prev_min [0:STATE_COUNT-1];
    reg [31:0] dp_prev_cnt [0:STATE_COUNT-1];
    reg [7:0] dp_new_min [0:STATE_COUNT-1];
    reg [31:0] dp_new_cnt [0:STATE_COUNT-1];

    // Precomputed tables
    reg [7:0] popcount_rom [0:STATE_COUNT-1];
    reg valid_transition [0:STATE_COUNT-1][0:STATE_COUNT-1];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            col_index <= 8'd0;
            cur_state <= 8'd0;
            prev_state <= 8'd0;
            state_limit <= 8'd0;
            popcount_cur <= 8'd0;
            tmp_min <= 8'd0;
            tmp_cnt <= 32'd0;
            global_min <= 8'd0;
            global_cnt <= 32'd0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = INIT_PRECOMP;
                end
            end

            INIT_PRECOMP: begin
                next_state = INIT_DP;
            end

            INIT_DP: begin
                next_state = START_COLUMN;
            end

            START_COLUMN: begin
                col_index = 8'd2;
                state_limit = 1 << n;
                cur_state = 8'd0;
                next_state = LOOP_CUR;
            end

            LOOP_CUR: begin
                if (cur_state < state_limit) begin
                    popcount_cur = popcount_rom[cur_state];
                    tmp_min = 8'hFF;
                    tmp_cnt = 32'd0;
                    prev_state = 8'd0;
                    next_state = LOOP_PREV;
                end else begin
                    next_state = NEXT_COLUMN;
                end
            end

            LOOP_PREV: begin
                if (prev_state < state_limit) begin
                    if (valid_transition[prev_state][cur_state]) begin
                        next_state = COMPUTE_CANDIDATE;
                    end else begin
                        next_state = NEXT_PREV;
                    end
                end else begin
                    dp_new_min[cur_state] = tmp_min;
                    dp_new_cnt[cur_state] = tmp_cnt;
                    next_state = NEXT_CUR;
                end
            end

            COMPUTE_CANDIDATE: begin
                next_state = NEXT_PREV;
            end

            NEXT_PREV: begin
                prev_state = prev_state + 8'd1;
                next_state = LOOP_PREV;
            end

            NEXT_CUR: begin
                cur_state = cur_state + 8'd1;
                next_state = LOOP_CUR;
            end

            NEXT_COLUMN: begin
                col_index = col_index + 8'd1;
                if (col_index > m) begin
                    next_state = FINALIZE;
                end else begin
                    cur_state = 8'd0;
                    next_state = LOOP_CUR;
                end
            end

            FINALIZE: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                done = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Precomputation of popcount and validity tables
    integer i, j;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < STATE_COUNT; i = i + 1) begin
                popcount_rom[i] <= 8'd0;
                for (j = 0; j < STATE_COUNT; j = j + 1) begin
                    valid_transition[i][j] <= 1'b0;
                end
            end
        end else if (current_state == INIT_PRECOMP) begin
            for (i = 0; i < STATE_COUNT; i = i + 1) begin
                popcount_rom[i] <= compute_popcount(i, n);
                for (j = 0; j < STATE_COUNT; j = j + 1) begin
                    valid_transition[i][j] <= valid_check(i, j, n);
                end
            end
        end
    end

    // Initialize DP for column 1
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < STATE_COUNT; i = i + 1) begin
                dp_prev_min[i] <= 8'd0;
                dp_prev_cnt[i] <= 32'd0;
            end
        end else if (current_state == INIT_DP) begin
            for (i = 0; i < STATE_COUNT; i = i + 1) begin
                dp_prev_min[i] <= popcount_rom[i];
                dp_prev_cnt[i] <= 32'd1;
            end
        end
    end

    // Compute candidate in DP update
    always @(*) begin
        if (current_state == COMPUTE_CANDIDATE) begin
            if (dp_prev_min[prev_state] + popcount_cur < tmp_min) begin
                tmp_min = dp_prev_min[prev_state] + popcount_cur;
                tmp_cnt = dp_prev_cnt[prev_state];
            end else if (dp_prev_min[prev_state] + popcount_cur == tmp_min) begin
                tmp_cnt = (tmp_cnt + dp_prev_cnt[prev_state]) % p;
            end
        end
    end

    // Swap DP arrays
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < STATE_COUNT; i = i + 1) begin
                dp_new_min[i] <= 8'd0;
                dp_new_cnt[i] <= 32'd0;
            end
        end else if (current_state == NEXT_COLUMN && col_index <= m) begin
            for (i = 0; i < STATE_COUNT; i = i + 1) begin
                dp_prev_min[i] <= dp_new_min[i];
                dp_prev_cnt[i] <= dp_new_cnt[i];
            end
        end
    end

    // Finalize result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            global_min <= 8'd0;
            global_cnt <= 32'd0;
        end else if (current_state == FINALIZE) begin
            global_min = 8'hFF;
            global_cnt = 32'd0;
            for (i = 0; i < STATE_COUNT; i = i + 1) begin
                if (dp_prev_min[i] < global_min) begin
                    global_min = dp_prev_min[i];
                    global_cnt = dp_prev_cnt[i];
                end else if (dp_prev_min[i] == global_min) begin
                    global_cnt = (global_cnt + dp_prev_cnt[i]) % p;
                end
            end
            result <= global_cnt;
        end
    end

    // Helper function to compute popcount
    function [7:0] compute_popcount;
        input [N_MAX-1:0] value;
        input [3:0] n;
        integer i;
        begin
            compute_popcount = 8'd0;
            for (i = 0; i < N_MAX; i = i + 1) begin
                if (i < n && value[i]) compute_popcount = compute_popcount + 8'd1;
            end
        end
    endfunction

    // Helper function to check transition validity
    function valid_check;
        input [N_MAX-1:0] prev;
        input [N_MAX-1:0] cur;
        input [3:0] n;
        integer i;
        begin
            valid_check = 1'b1;
            for (i = 0; i < N_MAX-1; i = i + 1) begin
                if (i < n-1) begin
                    if (prev[i] == 0 && prev[i+1] == 0 && cur[i] == 0 && cur[i+1] == 0) begin
                        valid_check = 1'b0;
                    end
                end
            end
        end
    endfunction

endmodule