module assembly_optimizer (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_symbols,
    input [2:0] seq_length,
    input [2:0] sequence [0:7],
    input [17:0] time_table [0:2][0:2],
    input [1:0] result_table [0:2][0:2],
    output reg [19:0] min_time,
    output reg [1:0] result_symbol,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        LOAD_SEQ,
        INIT_DP,
        DP_OUTER,
        DP_MIDDLE,
        DP_INNER,
        FIND_RESULT,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [2:0] outer_len;
    reg [2:0] middle_start;
    reg [2:0] inner_split;
    reg [1:0] symbol_k;
    reg [1:0] symbol_l;
    reg [1:0] symbol_m;

    // DP table: dp[i][j][k] for i,j in 0..7, k in 0..2
    reg [19:0] dp [0:7][0:7][0:2];

    // Sequence storage
    reg [2:0] seq_reg [0:7];

    // Temporary variables for computation
    reg [19:0] current_min;
    reg [19:0] temp_time;
    reg [1:0] temp_result;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            min_time <= 0;
            result_symbol <= 0;
            outer_len <= 0;
            middle_start <= 0;
            inner_split <= 0;
            symbol_k <= 0;
            symbol_l <= 0;
            symbol_m <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) next_state = LOAD_SEQ;
            end
            LOAD_SEQ: begin
                next_state = INIT_DP;
            end
            INIT_DP: begin
                next_state = DP_OUTER;
            end
            DP_OUTER: begin
                if (outer_len == seq_length) next_state = FIND_RESULT;
                else next_state = DP_MIDDLE;
            end
            DP_MIDDLE: begin
                if (middle_start == 8 - outer_len) next_state = DP_OUTER;
                else next_state = DP_INNER;
            end
            DP_INNER: begin
                if (inner_split == middle_start + outer_len - 1) next_state = DP_MIDDLE;
                else next_state = DP_INNER;
            end
            FIND_RESULT: begin
                next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
        endcase
    end

    // State actions
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset all registers
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 8; j++) begin
                    for (int k = 0; k < 3; k++) begin
                        dp[i][j][k] <= 20'hFFFFF;
                    end
                end
            end
        end else begin
            case (current_state)
                LOAD_SEQ: begin
                    // Load sequence into internal memory
                    for (int i = 0; i < 8; i++) begin
                        seq_reg[i] <= sequence[i];
                    end
                end
                INIT_DP: begin
                    // Initialize base cases (length 1)
                    for (int i = 0; i < seq_length; i++) begin
                        for (int k = 0; k < 3; k++) begin
                            if (k == seq_reg[i]) dp[i][i][k] <= 0;
                            else dp[i][i][k] <= 20'hFFFFF;
                        end
                    end
                    outer_len <= 2;
                end
                DP_OUTER: begin
                    if (outer_len < seq_length) begin
                        middle_start <= 0;
                        outer_len <= outer_len + 1;
                    end
                end
                DP_MIDDLE: begin
                    if (middle_start < 8 - outer_len) begin
                        inner_split <= middle_start;
                        symbol_k <= 0;
                        middle_start <= middle_start + 1;
                    end
                end
                DP_INNER: begin
                    // Compute dp[middle_start][middle_start+outer_len-1][symbol_k]
                    current_min = 20'hFFFFF;
                    temp_result = 0;
                    
                    for (symbol_l = 0; symbol_l < 3; symbol_l++) begin
                        for (symbol_m = 0; symbol_m < 3; symbol_m++) begin
                            if (result_table[symbol_l][symbol_m] == symbol_k) begin
                                temp_time = dp[middle_start][inner_split][symbol_l] + 
                                           dp[inner_split+1][middle_start+outer_len-1][symbol_m] + 
                                           time_table[symbol_l][symbol_m];
                                if (temp_time < current_min) begin
                                    current_min = temp_time;
                                    temp_result = symbol_k;
                                end
                            end
                        end
                    end
                    
                    dp[middle_start][middle_start+outer_len-1][symbol_k] <= current_min;
                    
                    // Update split position
                    if (symbol_k == 2) begin
                        if (inner_split < middle_start + outer_len - 1) begin
                            inner_split <= inner_split + 1;
                        end
                        symbol_k <= 0;
                    end else begin
                        symbol_k <= symbol_k + 1;
                    end
                end
                FIND_RESULT: begin
                    // Find minimum in dp[0][seq_length-1][*]
                    min_time = 20'hFFFFF;
                    result_symbol = 0;
                    
                    for (int k = 0; k < 3; k++) begin
                        if (dp[0][seq_length-1][k] < min_time) begin
                            min_time = dp[0][seq_length-1][k];
                            result_symbol = k;
                        end
                    end
                    done <= 1;
                end
                DONE: begin
                    // Keep outputs stable
                end
            endcase
        end
    end

endmodule