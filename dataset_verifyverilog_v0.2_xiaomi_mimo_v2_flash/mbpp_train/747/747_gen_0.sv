module lcs_3strings(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_x,
    input [7:0] char_y,
    input [7:0] char_z,
    input [2:0] idx_x,
    input [2:0] idx_y,
    input [2:0] idx_z,
    input char_valid,
    output reg [3:0] result,
    output reg done,
    output reg ready
);

    // Parameters
    parameter MAX_LEN = 8;
    parameter STATE_IDLE = 4'b0001;
    parameter STATE_LOAD = 4'b0010;
    parameter STATE_INIT = 4'b0011;
    parameter STATE_COMPUTE = 4'b0100;
    parameter STATE_DONE = 4'b0101;

    // State and next state
    reg [3:0] current_state;
    reg [3:0] next_state;

    // Character storage (8 chars per string)
    reg [7:0] str_x [0:7];
    reg [7:0] str_y [0:7];
    reg [7:0] str_z [0:7];

    // DP Table Memory
    // We use two layers: prev_layer (i-1) and curr_layer (i)
    // Each layer is 9x9 (j, k)
    reg [3:0] dp_prev [0:8][0:8]; // RAM for previous i layer
    reg [3:0] dp_curr [0:8][0:8]; // RAM for current i layer

    // Control counters
    reg [2:0] load_idx; // 0-7 for loading characters
    reg [2:0] init_j;   // 0-8 for initialization
    reg [2:0] init_k;   // 0-8 for initialization

    // Compute counters
    reg [2:0] i;        // 1-8
    reg [2:0] j;        // 1-8
    reg [2:0] k;        // 1-8

    // Temporary values for computation
    reg [3:0] val_prev_j_k;
    reg [3:0] val_curr_prev_j;
    reg [3:0] val_curr_prev_k;
    reg [3:0] val_prev_diag;
    reg [3:0] max_val;

    // Match flag
    reg match;

    // Next State Logic
    always @(*) begin
        case (current_state)
            STATE_IDLE: begin
                if (start)
                    next_state = STATE_LOAD;
                else
                    next_state = STATE_IDLE;
            end
            STATE_LOAD: begin
                if (load_idx == 3'd7 && char_valid)
                    next_state = STATE_INIT;
                else
                    next_state = STATE_LOAD;
            end
            STATE_INIT: begin
                if (init_j == 3'd8 && init_k == 3'd8)
                    next_state = STATE_COMPUTE;
                else
                    next_state = STATE_INIT;
            end
            STATE_COMPUTE: begin
                if (i == 3'd8 && j == 3'd8 && k == 3'd8)
                    next_state = STATE_DONE;
                else
                    next_state = STATE_COMPUTE;
            end
            STATE_DONE: begin
                if (start) // Reset or restart handling implied by start
                    next_state = STATE_LOAD;
                else
                    next_state = STATE_DONE;
            end
            default: next_state = STATE_IDLE;
        endcase
    end

    // State Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Output Logic and Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b1;
            done <= 1'b0;
            result <= 4'b0;
            load_idx <= 3'b0;
            init_j <= 3'b0;
            init_k <= 3'b0;
            i <= 3'b0;
            j <= 3'b0;
            k <= 3'b0;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    load_idx <= 3'b0;
                    init_j <= 3'b0;
                    init_k <= 3'b0;
                    i <= 3'b0;
                    j <= 3'b0;
                    k <= 3'b0;
                end
                STATE_LOAD: begin
                    ready <= 1'b0;
                    if (char_valid) begin
                        str_x[idx_x] <= char_x;
                        str_y[idx_y] <= char_y;
                        str_z[idx_z] <= char_z;
                        if (idx_x == load_idx && idx_y == load_idx && idx_z == load_idx) begin
                            load_idx <= load_idx + 1;
                        end else if (idx_x > load_idx || idx_y > load_idx || idx_z > load_idx) begin
                        end
                    end
                    if (char_valid) begin
                        if (load_idx < 3'd7) load_idx <= load_idx + 1;
                        else load_idx <= 3'd0;
                    end
                end
                STATE_INIT: begin
                    dp_curr[init_j][init_k] <= 4'b0;
                    dp_prev[init_j][init_k] <= 4'b0;
                    if (init_k == 3'd8) begin
                        init_k <= 3'b0;
                        if (init_j == 3'd8) begin
                            init_j <= 3'b0;
                        end else begin
                            init_j <= init_j + 1;
                        end
                    end else begin
                        init_k <= init_k + 1;
                    end
                end
                STATE_COMPUTE: begin
                    match = (str_x[i-1] == str_y[j-1]) && (str_y[j-1] == str_z[k-1]);
                    val_prev_j_k = (i > 1) ? dp_prev[j][k] : 4'b0;
                    val_curr_prev_j = (j > 1) ? dp_curr[j-1][k] : 4'b0;
                    val_curr_prev_k = (k > 1) ? dp_curr[j][k-1] : 4'b0;
                    val_prev_diag = (i > 1 && j > 1 && k > 1) ? dp_prev[j-1][k-1] : 4'b0;
                    if (match) begin
                        max_val = val_prev_diag + 1;
                    end else begin
                        max_val = val_prev_j_k;
                        if (val_curr_prev_j > max_val) max_val = val_curr_prev_j;
                        if (val_curr_prev_k > max_val) max_val = val_curr_prev_k;
                    end
                    dp_curr[j][k] <= max_val;
                    if (k == 3'd8) begin
                        k <= 3'b1;
                        if (j == 3'd8) begin
                            j <= 3'b1;
                            if (i == 3'd8) begin
                                result <= max_val;
                            end else begin
                                i <= i + 1;
                            end
                        end
                    end else begin
                        k <= k + 1;
                    end
                end
                STATE_DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Internal signals for micro-machine
    reg [3:0] micro_state;
    parameter MICRO_IDLE = 0;
    parameter MICRO_FETCH = 1;
    parameter MICRO_UPDATE = 2;
    parameter MICRO_STORE = 3;
    parameter MICRO_SWAP = 4;
    parameter MICRO_DONE = 5;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ready <= 1'b1;
            done <= 1'b0;
            result <= 4'b0;
            load_idx <= 3'b0;
            init_j <= 3'b0;
            init_k <= 3'b0;
            i <= 3'b0;
            j <= 3'b0;
            k <= 3'b0;
            micro_state <= MICRO_IDLE;
        end else begin
            case (current_state)
                STATE_IDLE: begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    if (start) begin
                        ready <= 1'b0;
                        load_idx <= 3'b0;
                    end
                end
                STATE_LOAD: begin
                    if (char_valid) begin
                        str_x[idx_x] <= char_x;
                        str_y[idx_y] <= char_y;
                        str_z[idx_z] <= char_z;
                        if (idx_x == load_idx && idx_y == load_idx && idx_z == load_idx) begin
                            if (load_idx < 3'd7) load_idx <= load_idx + 1;
                        end
                    end
                end
                STATE_INIT: begin
                    dp_curr[init_j][init_k] <= 4'b0;
                    dp_prev[init_j][init_k] <= 4'b0;
                    if (init_k == 3'd8) begin
                        init_k <= 3'b0;
                        if (init_j == 3'd8) begin
                            init_j <= 3'b0;
                            i <= 3'd1;
                            j <= 3'd1;
                            k <= 3'd1;
                            micro_state <= MICRO_FETCH;
                        end else begin
                            init_j <= init_j + 1;
                        end
                    end else begin
                        init_k <= init_k + 1;
                    end
                end
                STATE_COMPUTE_DP: begin
                    case (micro_state)
                        MICRO_FETCH: begin
                            if (i > 0 && j > 0 && k > 0) begin
                                val_prev_j_k <= dp_prev[j][k];
                                val_curr_prev_j <= (j > 0) ? dp_curr[j-1][k] : 4'b0;
                                val_curr_prev_k <= (k > 0) ? dp_curr[j][k-1] : 4'b0;
                                val_prev_diag <= (i > 0 && j > 0 && k > 0) ? dp_prev[j-1][k-1] : 4'b0;
                                if (str_x[i-1] == str_y[j-1] && str_y[j-1] == str_z[k-1]) begin
                                    match <= 1'b1;
                                end else begin
                                    match <= 1'b0;
                                end
                            end
                            micro_state <= MICRO_UPDATE;
                        end
                        MICRO_UPDATE: begin
                            if (match) begin
                                max_val <= val_prev_diag + 1;
                            end else begin
                                max_val <= val_prev_j_k;
                                if (val_curr_prev_j > val_prev_j_k) max_val <= val_curr_prev_j;
                                if (val_curr_prev_k > max_val) max_val <= val_curr_prev_k;
                            end
                            micro_state <= MICRO_STORE;
                        end
                        MICRO_STORE: begin
                            dp_curr[j][k] <= max_val;
                            if (k == 3'd8) begin
                                k <= 3'd1;
                                if (j == 3'd8) begin
                                    j <= 3'd1;
                                    if (i == 3'd8) begin
                                        result <= max_val;
                                        micro_state <= MICRO_DONE;
                                    end else begin
                                        i <= i + 1;
                                        init_j <= 3'd0;
                                        init_k <= 3'd0;
                                        micro_state <= MICRO_SWAP;
                                    end
                                end else begin
                                    j <= j + 1;
                                    micro_state <= MICRO_FETCH;
                                end
                            end else begin
                                k <= k + 1;
                                micro_state <= MICRO_FETCH;
                            end
                        end
                        MICRO_SWAP: begin
                            dp_prev[init_j][init_k] <= dp_curr[init_j][init_k];
                            if (init_k == 3'd8) begin
                                init_k <= 3'b0;
                                if (init_j == 3'd8) begin
                                    init_j <= 3'b0;
                                    micro_state <= MICRO_FETCH;
                                end else begin
                                    init_j <= init_j + 1;
                                end
                            end else begin
                                init_k <= init_k + 1;
                            end
                        end
                        MICRO_DONE: begin
                        end
                    endcase
                end
                STATE_DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    always @(*) begin
        if (current_state == STATE_COMPUTE_DP) begin
            if (micro_state == MICRO_DONE)
                next_state = STATE_DONE;
            else
                next_state = STATE_COMPUTE_DP;
        end
    end

endmodule