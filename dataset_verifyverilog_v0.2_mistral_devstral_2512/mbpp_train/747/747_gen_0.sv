module lcs_3strings (
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

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        LOAD_CHARS,
        INIT_TABLE,
        COMPUTE_DP,
        FETCH_STATE,
        MATCH_CHECK,
        UPDATE_DP,
        STORE_RESULT,
        DONE
    } state_t;

    state_t state, next_state;

    // Character storage
    reg [7:0] str_x [0:7];
    reg [7:0] str_y [0:7];
    reg [7:0] str_z [0:7];
    reg [2:0] char_idx;

    // DP table storage (using 2D arrays for current and previous layers)
    reg [3:0] dp_current [0:8][0:8];
    reg [3:0] dp_prev [0:8][0:8];
    reg [2:0] i, j, k;

    // Temporary storage for DP computation
    reg [3:0] max_val;
    reg match;

    // Initialize state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ready <= 1'b1;
            done <= 1'b0;
            result <= 4'b0;
            char_idx <= 3'b0;
            i <= 3'b0;
            j <= 3'b0;
            k <= 3'b0;
        end else begin
            state <= next_state;
        end
    end

    // State machine
    always @(*) begin
        case (state)
            IDLE: begin
                ready = 1'b1;
                done = 1'b0;
                if (start) begin
                    next_state = LOAD_CHARS;
                    ready = 1'b0;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD_CHARS: begin
                if (char_valid) begin
                    str_x[idx_x] = char_x;
                    str_y[idx_y] = char_y;
                    str_z[idx_z] = char_z;
                    if (char_idx == 7) begin
                        next_state = INIT_TABLE;
                        char_idx = 3'b0;
                    end else begin
                        char_idx = char_idx + 1;
                    end
                end else begin
                    next_state = LOAD_CHARS;
                end
            end

            INIT_TABLE: begin
                // Initialize first row, column, and layer to 0
                for (int m = 0; m < 9; m++) begin
                    for (int n = 0; n < 9; n++) begin
                        dp_current[m][n] = 4'b0;
                        dp_prev[m][n] = 4'b0;
                    end
                end
                next_state = COMPUTE_DP;
            end

            COMPUTE_DP: begin
                if (i == 8 && j == 8 && k == 8) begin
                    next_state = DONE;
                end else begin
                    next_state = FETCH_STATE;
                end
            end

            FETCH_STATE: begin
                // Fetch previous DP values
                next_state = MATCH_CHECK;
            end

            MATCH_CHECK: begin
                // Check if characters match
                match = (str_x[i] == str_y[j]) && (str_y[j] == str_z[k]);
                next_state = UPDATE_DP;
            end

            UPDATE_DP: begin
                // Compute new DP value
                if (match) begin
                    max_val = dp_prev[i][j] + 1;
                end else begin
                    max_val = dp_prev[i+1][j];
                    if (dp_prev[i][j+1] > max_val) max_val = dp_prev[i][j+1];
                    if (dp_prev[i][j] > max_val) max_val = dp_prev[i][j];
                end
                next_state = STORE_RESULT;
            end

            STORE_RESULT: begin
                // Store result in DP table
                dp_current[i][j] = max_val;
                // Update indices
                if (k == 8) begin
                    if (j == 8) begin
                        i = i + 1;
                        j = 3'b0;
                    end else begin
                        j = j + 1;
                    end
                    k = 3'b0;
                end else begin
                    k = k + 1;
                end
                next_state = COMPUTE_DP;
            end

            DONE: begin
                result = dp_current[8][8];
                done = 1'b1;
                ready = 1'b1;
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule