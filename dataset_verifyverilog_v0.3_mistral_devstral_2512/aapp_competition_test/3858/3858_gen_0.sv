module compute_convex_score(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] N,
    input wire signed [15:0] x0,
    input wire signed [15:0] x1,
    input wire signed [15:0] x2,
    input wire signed [15:0] x3,
    input wire signed [15:0] x4,
    input wire signed [15:0] x5,
    input wire signed [15:0] x6,
    input wire signed [15:0] x7,
    input wire signed [15:0] y0,
    input wire signed [15:0] y1,
    input wire signed [15:0] y2,
    input wire signed [15:0] y3,
    input wire signed [15:0] y4,
    input wire signed [15:0] y5,
    input wire signed [15:0] y6,
    input wire signed [15:0] y7,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] OUTER_LOOP = 4'd2;
    localparam [3:0] INNER_LOOP = 4'd3;
    localparam [3:0] CHECK_COLLINEAR = 4'd4;
    localparam [3:0] COUNT_POINTS = 4'd5;
    localparam [3:0] CALC_SUBTRACT = 4'd6;
    localparam [3:0] UPDATE_RESULT = 4'd7;
    localparam [3:0] FINALIZE = 4'd8;
    localparam [3:0] COMPUTE_BASE = 4'd9;
    localparam [3:0] DONE_STATE = 4'd10;
    localparam [3:0] CLEANUP = 4'd11;
    localparam [3:0] FINISH = 4'd12;

    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Loop counters
    reg [2:0] i, j, k, m;
    reg [2:0] point_count;
    reg [31:0] temp_result;
    reg [31:0] base_value;
    reg [31:0] subtract_value;
    reg [31:0] pow2_value;
    reg [31:0] temp_calc;

    // Collinearity check variables
    reg signed [31:0] dx_ij, dy_ij, dx_ik, dy_ik, dx_jk, dy_jk;
    reg collinear;

    // Array of points (x,y pairs)
    reg signed [15:0] x [0:7];
    reg signed [15:0] y [0:7];

    // Modulo constant
    localparam [31:0] MOD = 32'd998244353;

    // Initialize point arrays
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x[0] <= 16'd0; x[1] <= 16'd0; x[2] <= 16'd0; x[3] <= 16'd0;
            x[4] <= 16'd0; x[5] <= 16'd0; x[6] <= 16'd0; x[7] <= 16'd0;
            y[0] <= 16'd0; y[1] <= 16'd0; y[2] <= 16'd0; y[3] <= 16'd0;
            y[4] <= 16'd0; y[5] <= 16'd0; y[6] <= 16'd0; y[7] <= 16'd0;
        end else begin
            x[0] <= x0; x[1] <= x1; x[2] <= x2; x[3] <= x3;
            x[4] <= x4; x[5] <= x5; x[6] <= x6; x[7] <= x7;
            y[0] <= y0; y[1] <= y1; y[2] <= y2; y[3] <= y3;
            y[4] <= y4; y[5] <= y5; y[6] <= y6; y[7] <= y7;
        end
    end

    // Power of 2 calculation (2^k mod MOD)
    always @(*) begin
        case (pow2_value)
            32'd1: temp_calc = 32'd2;
            32'd2: temp_calc = 32'd4;
            32'd3: temp_calc = 32'd8;
            32'd4: temp_calc = 32'd16;
            32'd5: temp_calc = 32'd32;
            32'd6: temp_calc = 32'd64;
            32'd7: temp_calc = 32'd128;
            32'd8: temp_calc = 32'd256;
            default: temp_calc = 32'd0;
        endcase
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 3'd0;
            j <= 3'd0;
            k <= 3'd0;
            m <= 3'd0;
            point_count <= 3'd0;
            temp_result <= 32'd0;
            base_value <= 32'd0;
            subtract_value <= 32'd0;
            pow2_value <= 32'd0;
            collinear <= 1'b0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    i <= 3'd0;
                    j <= 3'd0;
                    k <= 3'd0;
                    temp_result <= 32'd0;
                    next_state <= COMPUTE_BASE;
                end

                COMPUTE_BASE: begin
                    // Calculate base_value = (2^N - 1 - N - N*(N-1)/2) mod MOD
                    pow2_value <= 32'd1;
                    temp_calc <= 32'd1;
                    for (m = 3'd0; m < N; m = m + 3'd1) begin
                        temp_calc <= (temp_calc * 32'd2) % MOD;
                    end
                    base_value <= (temp_calc - 32'd1 - N - (N * (N - 3'd1)) / 32'd2) % MOD;
                    temp_result <= base_value;
                    next_state <= OUTER_LOOP;
                end

                OUTER_LOOP: begin
                    if (i < N) begin
                        j <= i + 3'd1;
                        next_state <= INNER_LOOP;
                    end else begin
                        next_state <= FINALIZE;
                    end
                end

                INNER_LOOP: begin
                    if (j < N) begin
                        point_count <= 3'd0;
                        k <= 3'd0;
                        next_state <= CHECK_COLLINEAR;
                    end else begin
                        i <= i + 3'd1;
                        next_state <= OUTER_LOOP;
                    end
                end

                CHECK_COLLINEAR: begin
                    if (k < N) begin
                        // Check if point k is collinear with i,j
                        dx_ij <= x[j] - x[i];
                        dy_ij <= y[j] - y[i];
                        dx_ik <= x[k] - x[i];
                        dy_ik <= y[k] - y[i];
                        dx_jk <= x[k] - x[j];
                        dy_jk <= y[k] - y[j];
                        
                        // Collinearity: (x_j-x_i)*(y_k-y_i) == (x_k-x_i)*(y_j-y_i)
                        collinear <= (dx_ij * dy_ik == dx_ik * dy_ij);
                        
                        if (collinear && k != i && k != j) begin
                            point_count <= point_count + 3'd1;
                        end
                        k <= k + 3'd1;
                        next_state <= CHECK_COLLINEAR;
                    end else begin
                        if (point_count >= 3'd3) begin
                            next_state <= CALC_SUBTRACT;
                        end else begin
                            j <= j + 3'd1;
                            next_state <= INNER_LOOP;
                        end
                    end
                end

                CALC_SUBTRACT: begin
                    // Calculate subtract_value = (2^k - 1 - k - k*(k-1)/2) mod MOD
                    pow2_value <= 32'd1;
                    temp_calc <= 32'd1;
                    for (m = 3'd0; m < point_count; m = m + 3'd1) begin
                        temp_calc <= (temp_calc * 32'd2) % MOD;
                    end
                    subtract_value <= (temp_calc - 32'd1 - point_count - (point_count * (point_count - 3'd1)) / 32'd2) % MOD;
                    next_state <= UPDATE_RESULT;
                end

                UPDATE_RESULT: begin
                    // Subtract from result
                    temp_result <= (temp_result - subtract_value) % MOD;
                    j <= j + 3'd1;
                    next_state <= INNER_LOOP;
                end

                FINALIZE: begin
                    result <= temp_result;
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= CLEANUP;
                end

                CLEANUP: begin
                    next_state <= FINISH;
                end

                FINISH: begin
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Safety: prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= IDLE;
            done <= 1'b1;
            result <= 32'd0;
        end
    end

endmodule