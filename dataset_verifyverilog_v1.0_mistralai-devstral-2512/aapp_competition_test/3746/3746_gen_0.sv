module SmallY_TowerOfHanoi(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [143:0] cost_in,
    input wire [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] CALCULATE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Register declarations
    reg [2:0] state, next_state;
    reg [3:0] current_n;
    reg [3:0] src, dst, aux;
    reg [31:0] dp_prev [0:2][0:2];
    reg [31:0] dp_prev2 [0:2][0:2];
    reg [31:0] dp_curr [0:2][0:2];
    reg [15:0] cost_matrix [0:2][0:2];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize cost matrix from input
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            next_state <= IDLE;
            current_n <= 4'd0;
            src <= 2'd0;
            dst <= 2'd0;
            aux <= 2'd0;
            cycle_count <= 8'd0;
            result <= 32'd0;
            done <= 1'b0;

            // Initialize dp_prev and dp_prev2
            integer i, j;
            for (i = 0; i < 3; i = i + 1) begin
                for (j = 0; j < 3; j = j + 1) begin
                    dp_prev[i][j] <= 32'd0;
                    dp_prev2[i][j] <= 32'd0;
                    dp_curr[i][j] <= 32'd0;
                end
            end

            // Initialize cost matrix
            for (i = 0; i < 3; i = i + 1) begin
                for (j = 0; j < 3; j = j + 1) begin
                    cost_matrix[i][j] <= 16'd0;
                end
            end
        end else begin
            // Update cost matrix from input
            if (state == IDLE && start) begin
                integer idx;
                for (idx = 0; idx < 9; idx = idx + 1) begin
                    integer i = idx / 3;
                    integer j = idx % 3;
                    cost_matrix[i][j] <= cost_in[(idx * 16) +: 16];
                end
            end
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                next_state = CALCULATE;
            end

            CALCULATE: begin
                if (current_n == n) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Calculation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized in reset block
        end else begin
            case (state)
                INIT: begin
                    // Initialize dp_prev for n=1
                    integer i, j;
                    for (i = 0; i < 3; i = i + 1) begin
                        for (j = 0; j < 3; j = j + 1) begin
                            if (i != j) begin
                                dp_prev[i][j] <= cost_matrix[i][j];
                            end else begin
                                dp_prev[i][j] <= 32'd0;
                            end
                        end
                    end
                    current_n <= 4'd1;
                end

                CALCULATE: begin
                    if (current_n == 1) begin
                        // Already initialized in INIT state
                        current_n <= current_n + 4'd1;
                    end else begin
                        // Compute dp_curr for current_n
                        integer i, j;
                        for (i = 0; i < 3; i = i + 1) begin
                            for (j = 0; j < 3; j = j + 1) begin
                                if (i != j) begin
                                    aux = 3 - i - j;
                                    // Strategy 1: direct move
                                    reg [31:0] cost1 = dp_prev[i][aux] + cost_matrix[i][j] + dp_prev[aux][j];
                                    // Strategy 2: through auxiliary
                                    reg [31:0] cost2 = dp_prev2[i][j] + cost_matrix[i][aux] + dp_prev[aux][j] + 
                                               cost_matrix[aux][j] + dp_prev[j][i] + cost_matrix[i][j] + dp_prev2[i][j];
                                    // Choose minimum
                                    if (cost1 < cost2) begin
                                        dp_curr[i][j] <= cost1;
                                    end else begin
                                        dp_curr[i][j] <= cost2;
                                    end
                                end else begin
                                    dp_curr[i][j] <= 32'd0;
                                end
                            end
                        end

                        // Update dp_prev and dp_prev2 for next iteration
                        for (i = 0; i < 3; i = i + 1) begin
                            for (j = 0; j < 3; j = j + 1) begin
                                dp_prev2[i][j] <= dp_prev[i][j];
                                dp_prev[i][j] <= dp_curr[i][j];
                            end
                        end

                        // Increment current_n
                        if (current_n < n) begin
                            current_n <= current_n + 4'd1;
                        end
                    end
                end

                DONE_STATE: begin
                    result <= dp_prev[0][2];
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Cycle counter for safety
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else begin
            if (state != IDLE) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            end else begin
                cycle_count <= 8'd0;
            end
        end
    end

endmodule