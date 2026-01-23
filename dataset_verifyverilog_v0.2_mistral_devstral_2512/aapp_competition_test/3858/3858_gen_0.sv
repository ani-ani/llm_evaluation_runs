module convex_scoring (
    input clk,
    input rst_n,
    input start,
    input [7:0] N,
    input [15:0] points_x [0:15],
    input [15:0] points_y [0:15],
    output reg [31:0] result,
    output reg done
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam CALCULATE_SLOPES = 3'b001;
    localparam COUNT_COLLINEAR = 3'b010;
    localparam ACCUMULATE_RESULT = 3'b011;
    localparam DONE = 3'b100;

    // State machine
    reg [2:0] state = IDLE;

    // Counters
    reg [7:0] i = 0;
    reg [7:0] j = 0;
    reg [7:0] k = 0;
    reg [7:0] collinear_count = 0;

    // Temporary storage
    reg [15:0] dx, dy;
    reg [15:0] dx_temp, dy_temp;
    reg [31:0] temp_result;

    // Flags
    reg [15:0] used [0:15] = '{default: 0};

    // GCD calculation
    reg [15:0] a, b;
    reg [15:0] gcd_result;

    // Power of 2 calculation
    reg [31:0] pow2_N;
    reg [31:0] pow2_M;

    // Modulo constant
    localparam MOD = 998244353;

    // GCD calculation function
    function [15:0] gcd;
        input [15:0] a, b;
        reg [15:0] x, y;
        begin
            x = a;
            y = b;
            while (y != 0) begin
                x = x % y;
                x = {x, y};
                y = x[31:16];
                x = x[15:0];
            end
            gcd = x;
        end
    endfunction

    // Power of 2 calculation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pow2_N <= 0;
            pow2_M <= 0;
        end else begin
            if (state == IDLE && start) begin
                pow2_N <= 1 << N;
            end
            if (state == COUNT_COLLINEAR && collinear_count > 0) begin
                pow2_M <= 1 << collinear_count;
            end
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 0;
            j <= 0;
            k <= 0;
            collinear_count <= 0;
            dx <= 0;
            dy <= 0;
            dx_temp <= 0;
            dy_temp <= 0;
            temp_result <= 0;
            done <= 0;
            result <= 0;
            for (int idx = 0; idx < 16; idx = idx + 1) begin
                used[idx] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CALCULATE_SLOPES;
                        i <= 0;
                        j <= 0;
                        temp_result <= pow2_N - 1 - N;
                    end
                end
                CALCULATE_SLOPES: begin
                    if (i < N) begin
                        if (j < N && j > i) begin
                            dx <= points_x[j] - points_x[i];
                            dy <= points_y[j] - points_y[i];
                            if (dx == 0 && dy == 0) begin
                                j <= j + 1;
                            end else begin
                                state <= COUNT_COLLINEAR;
                                collinear_count <= 0;
                                k <= 0;
                            end
                        end else begin
                            i <= i + 1;
                            j <= 0;
                        end
                    end else begin
                        state <= DONE;
                        result <= temp_result;
                        done <= 1;
                    end
                end
                COUNT_COLLINEAR: begin
                    if (k < N) begin
                        if (k != i && k != j && !used[k]) begin
                            dx_temp <= points_x[k] - points_x[i];
                            dy_temp <= points_y[k] - points_y[i];
                            if (dx * dy_temp == dy * dx_temp) begin
                                collinear_count <= collinear_count + 1;
                                used[k] <= 1;
                            end
                        end
                        k <= k + 1;
                    end else begin
                        state <= ACCUMULATE_RESULT;
                    end
                end
                ACCUMULATE_RESULT: begin
                    if (collinear_count >= 2) begin
                        temp_result <= temp_result - (pow2_M - collinear_count - 1);
                    end
                    state <= CALCULATE_SLOPES;
                    j <= j + 1;
                end
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule