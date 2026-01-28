module evasion_probability(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] R,
    input wire [3:0] C,
    input wire [3:0] K,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MOD = 32'd1000000007;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNT_PAIRS = 3'd1;
    localparam [2:0] COMPUTE_INVERSE = 3'd2;
    localparam [2:0] COMPUTE_RESULT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [31:0] safe_count;
    reg [31:0] total_pairs;
    reg [31:0] inv_total;
    reg [31:0] product;

    // Pair counters
    reg [7:0] p_idx;
    reg [7:0] y_idx;
    reg [3:0] p_r, p_c;
    reg [3:0] y_r, y_c;

    // Inverse computation registers
    reg [31:0] a, b, x, y, temp;
    reg [31:0] a_reg, b_reg, x_reg, y_reg;
    reg [4:0] inv_cycle;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            safe_count <= 32'd0;
            total_pairs <= 32'd0;
            inv_total <= 32'd0;
            product <= 32'd0;
            p_idx <= 8'd0;
            y_idx <= 8'd0;
            p_r <= 4'd0;
            p_c <= 4'd0;
            y_r <= 4'd0;
            y_c <= 4'd0;
            a_reg <= 32'd0;
            b_reg <= 32'd0;
            x_reg <= 32'd0;
            y_reg <= 32'd0;
            inv_cycle <= 5'd0;
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
                    next_state = COUNT_PAIRS;
                    safe_count = 32'd0;
                    total_pairs = R * C;
                    total_pairs = total_pairs * total_pairs;
                    p_idx = 8'd0;
                    y_idx = 8'd0;
                end
            end

            COUNT_PAIRS: begin
                if (p_idx == (R * C) - 1 && y_idx == (R * C) - 1) begin
                    next_state = COMPUTE_INVERSE;
                    a_reg = MOD;
                    b_reg = total_pairs;
                    x_reg = 32'd0;
                    y_reg = 32'd1;
                    inv_cycle = 5'd0;
                end
            end

            COMPUTE_INVERSE: begin
                if (inv_cycle == 32) begin
                    next_state = COMPUTE_RESULT;
                    inv_total = x_reg;
                end
            end

            COMPUTE_RESULT: begin
                next_state = DONE_STATE;
                product = safe_count * inv_total;
                result = product % MOD;
            end

            DONE_STATE: begin
                next_state = IDLE;
                done = 1'b1;
            end

            default: next_state = IDLE;
        endcase
    end

    // Pair counting logic
    always @(posedge clk) begin
        if (state == COUNT_PAIRS) begin
            // Convert indices to coordinates
            p_r = p_idx[7:4];
            p_c = p_idx[3:0];
            y_r = y_idx[7:4];
            y_c = y_idx[3:0];

            // Check if distance > K
            if ((p_r > y_r ? p_r - y_r : y_r - p_r) + (p_c > y_c ? p_c - y_c : y_c - p_c) > K) begin
                safe_count = safe_count + 32'd1;
            end

            // Increment counters
            if (y_idx == (R * C) - 1) begin
                y_idx = 8'd0;
                p_idx = p_idx + 8'd1;
            end else begin
                y_idx = y_idx + 8'd1;
            end
        end
    end

    // Modular inverse computation (Binary Extended GCD)
    always @(posedge clk) begin
        if (state == COMPUTE_INVERSE && inv_cycle < 32) begin
            a = a_reg;
            b = b_reg;
            x = x_reg;
            y = y_reg;

            if (b == 0) begin
                inv_total = x;
                next_state = COMPUTE_RESULT;
            end else begin
                if (a[0] == 0) begin
                    a = a >> 1;
                    if (x[0] == 0) begin
                        x = x >> 1;
                    end else begin
                        x = (x >> 1) | (32'd1 << 31);
                    end
                end else if (b[0] == 0) begin
                    b = b >> 1;
                    if (y[0] == 0) begin
                        y = y >> 1;
                    end else begin
                        y = (y >> 1) | (32'd1 << 31);
                    end
                end else if (a >= b) begin
                    a = a - b;
                    if (x >= y) begin
                        x = x - y;
                    end else begin
                        x = x + MOD - y;
                    end
                end else begin
                    b = b - a;
                    if (y >= x) begin
                        y = y - x;
                    end else begin
                        y = y + MOD - x;
                    end
                end

                a_reg = a;
                b_reg = b;
                x_reg = x;
                y_reg = y;
                inv_cycle = inv_cycle + 5'd1;
            end
        end
    end

    // Done signal handling
    always @(posedge clk) begin
        if (state == DONE_STATE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule