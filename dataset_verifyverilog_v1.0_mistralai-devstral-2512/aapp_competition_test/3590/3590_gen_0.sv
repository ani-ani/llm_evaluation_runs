module min_cut_cost(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire a_valid,
    input wire b_valid,
    input wire signed [31:0] a_x,
    input wire signed [31:0] a_y,
    input wire signed [31:0] b_x,
    input wire signed [31:0] b_y,
    output reg signed [63:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_A = 3'd1;
    localparam [2:0] LOAD_B = 3'd2;
    localparam [2:0] CALCULATE = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Vertex storage (8 slots each)
    reg signed [31:0] a_x_mem [0:7];
    reg signed [31:0] a_y_mem [0:7];
    reg signed [31:0] b_x_mem [0:7];
    reg signed [31:0] b_y_mem [0:7];

    // Vertex counters
    reg [2:0] a_count;
    reg [2:0] b_count;
    reg [2:0] a_idx;
    reg [2:0] b_idx;

    // DP table and intermediate results
    reg signed [31:0] dp [0:7];
    reg signed [31:0] min_cost;
    reg signed [31:0] current_cost;

    // Fixed-point arithmetic components
    reg signed [31:0] dx, dy;
    reg signed [31:0] dx_sq, dy_sq;
    reg signed [31:0] dist_sq;
    reg signed [31:0] sqrt_val;
    reg [4:0] sqrt_iter;

    // Control signals
    reg load_a_done;
    reg load_b_done;
    reg calc_done;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            a_count <= 3'd0;
            b_count <= 3'd0;
            a_idx <= 3'd0;
            b_idx <= 3'd0;
            min_cost <= 32'd0;
            current_cost <= 32'd0;
            load_a_done <= 1'b0;
            load_b_done <= 1'b0;
            calc_done <= 1'b0;
            done <= 1'b0;
            busy <= 1'b0;
            result <= 64'd0;

            // Initialize vertex storage
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                a_x_mem[i] <= 32'd0;
                a_y_mem[i] <= 32'd0;
                b_x_mem[i] <= 32'd0;
                b_y_mem[i] <= 32'd0;
                dp[i] <= 32'd0;
            end
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
                    next_state = LOAD_A;
                    busy = 1'b1;
                end
            end

            LOAD_A: begin
                if (a_valid && a_count < 8) begin
                    next_state = LOAD_A;
                end else if (a_count >= 8) begin
                    next_state = LOAD_B;
                    load_a_done = 1'b1;
                end
            end

            LOAD_B: begin
                if (b_valid && b_count < 8) begin
                    next_state = LOAD_B;
                end else if (b_count >= 8) begin
                    next_state = CALCULATE;
                    load_b_done = 1'b1;
                end
            end

            CALCULATE: begin
                if (calc_done) begin
                    next_state = DONE_STATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
                busy = 1'b0;
            end

            default: next_state = IDLE;
        endcase
    end

    // Load A vertices
    always @(posedge clk) begin
        if (state == LOAD_A && a_valid && a_count < 8) begin
            a_x_mem[a_count] <= a_x;
            a_y_mem[a_count] <= a_y;
            a_count <= a_count + 1'b1;
        end
    end

    // Load B vertices
    always @(posedge clk) begin
        if (state == LOAD_B && b_valid && b_count < 8) begin
            b_x_mem[b_count] <= b_x;
            b_y_mem[b_count] <= b_y;
            b_count <= b_count + 1'b1;
        end
    end

    // Calculate minimum cut cost using DP
    always @(posedge clk) begin
        if (state == CALCULATE && !calc_done) begin
            // Initialize DP table
            if (a_idx == 0 && b_idx == 0) begin
                integer i;
                for (i = 0; i < 8; i = i + 1) begin
                    dp[i] <= 32'd0;
                end
                a_idx <= 1'b0;
                b_idx <= 1'b0;
            end

            // Compute distance between current vertices
            dx <= a_x_mem[a_idx] - b_x_mem[b_idx];
            dy <= a_y_mem[a_idx] - b_y_mem[b_idx];

            // Compute squared distance
            dx_sq <= $signed(dx) * $signed(dx);
            dy_sq <= $signed(dy) * $signed(dy);
            dist_sq <= dx_sq + dy_sq;

            // Newton-Raphson sqrt approximation (8 iterations)
            sqrt_val <= 32'd1 << 15; // Initial guess (1.0 in Q16.16)
            sqrt_iter <= 5'd0;

            // Perform sqrt iterations
            if (sqrt_iter < 8) begin
                reg signed [31:0] next_val;
                reg signed [31:0] temp;
                temp <= dist_sq / sqrt_val;
                next_val <= (sqrt_val + temp) >> 1;
                sqrt_val <= next_val;
                sqrt_iter <= sqrt_iter + 1'b1;
            end

            // Update DP table
            if (sqrt_iter == 8) begin
                current_cost <= dp[a_idx] + sqrt_val;
                if (current_cost < min_cost || min_cost == 0) begin
                    min_cost <= current_cost;
                end

                // Move to next vertex
                a_idx <= a_idx + 1'b1;
                if (a_idx == 8) begin
                    a_idx <= 1'b0;
                    b_idx <= b_idx + 1'b1;
                    if (b_idx == 8) begin
                        calc_done <= 1'b1;
                        result <= $signed(min_cost) << 32; // Convert to 32.32 format
                        done <= 1'b1;
                    end
                end
            end
        end else if (state == DONE_STATE) begin
            done <= 1'b0;
        end
    end

    // Busy signal
    always @(*) begin
        busy = (state != IDLE && state != DONE_STATE);
    end

endmodule