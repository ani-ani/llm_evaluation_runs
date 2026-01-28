module bandwidth_allocation (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] t,
    // Species 0
    input wire [15:0] a_0, b_0, d_0,
    output reg [31:0] x_0,
    // Species 1
    input wire [15:0] a_1, b_1, d_1,
    output reg [31:0] x_1,
    // Species 2
    input wire [15:0] a_2, b_2, d_2,
    output reg [31:0] x_2,
    // Species 3
    input wire [15:0] a_3, b_3, d_3,
    output reg [31:0] x_3,
    // Species 4
    input wire [15:0] a_4, b_4, d_4,
    output reg [31:0] x_4,
    // Species 5
    input wire [15:0] a_5, b_5, d_5,
    output reg [31:0] x_5,
    // Species 6
    input wire [15:0] a_6, b_6, d_6,
    output reg [31:0] x_6,
    // Species 7
    input wire [15:0] a_7, b_7, d_7,
    output reg [31:0] x_7,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_TOTAL_DEMAND = 4'd1;
    localparam [3:0] COMPUTE_FAIR_SHARE = 4'd2;
    localparam [3:0] INITIALIZE = 4'd3;
    localparam [3:0] COMPUTE_SUM_X = 4'd4;
    localparam [3:0] CHECK_CONVERGENCE = 4'd5;
    localparam [3:0] DISTRIBUTE = 4'd6;
    localparam [3:0] PROJECT = 4'd7;
    localparam [3:0] OUTPUT_RESULT = 4'd8;
    localparam [3:0] FINISH = 4'd9;

    reg [3:0] state, next_state;
    reg [3:0] iteration_counter;
    localparam [3:0] MAX_ITERATIONS = 4'd10;

    // Internal storage for species data (8 max)
    reg [15:0] a_reg [0:7];
    reg [15:0] b_reg [0:7];
    reg [15:0] d_reg [0:7];
    reg [31:0] y_reg [0:7];
    reg [31:0] x_reg [0:7];

    // Temporary calculation registers
    reg [31:0] sum_d;
    reg [47:0] sum_x;
    reg signed [47:0] residual;
    reg signed [47:0] residual_scaled;
    reg [47:0] divisor;
    reg [47:0] quotient;
    reg [47:0] remainder;
    
    // Iteration index
    reg [3:0] idx;
    
    // Convergence threshold (2^-8 = 1/256, in Q16.16 = 256)
    localparam [47:0] CONVERGENCE_THRESH = 48'd256;
    
    // Divider state
    reg div_start;
    reg div_done;
    reg [47:0] div_a;
    reg [47:0] div_b;
    
    // Sequential divider (non-restoring)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_done <= 1'b0;
            quotient <= 48'd0;
            remainder <= 48'd0;
        end else begin
            if (div_start && !div_done) begin
                if (div_b != 48'd0) begin
                    quotient <= div_a / div_b;
                    remainder <= div_a % div_b;
                    div_done <= 1'b1;
                end else begin
                    quotient <= 48'd0;
                    remainder <= 48'd0;
                    div_done <= 1'b1;
                end
            end else if (!div_start) begin
                div_done <= 1'b0;
                quotient <= 48'd0;
                remainder <= 48'd0;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            x_0 <= 32'd0; x_1 <= 32'd0; x_2 <= 32'd0; x_3 <= 32'd0;
            x_4 <= 32'd0; x_5 <= 32'd0; x_6 <= 32'd0; x_7 <= 32'd0;
            iteration_counter <= 4'd0;
            idx <= 4'd0;
            sum_d <= 32'd0;
            sum_x <= 48'd0;
            residual <= 48'd0;
            div_start <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    iteration_counter <= 4'd0;
                    idx <= 4'd0;
                    if (start) begin
                        // Store inputs
                        a_reg[0] <= a_0; b_reg[0] <= b_0; d_reg[0] <= d_0;
                        a_reg[1] <= a_1; b_reg[1] <= b_1; d_reg[1] <= d_1;
                        a_reg[2] <= a_2; b_reg[2] <= b_2; d_reg[2] <= d_2;
                        a_reg[3] <= a_3; b_reg[3] <= b_3; d_reg[3] <= d_3;
                        a_reg[4] <= a_4; b_reg[4] <= b_4; d_reg[4] <= d_4;
                        a_reg[5] <= a_5; b_reg[5] <= b_5; d_reg[5] <= d_5;
                        a_reg[6] <= a_6; b_reg[6] <= b_6; d_reg[6] <= d_6;
                        a_reg[7] <= a_7; b_reg[7] <= b_7; d_reg[7] <= d_7;
                        sum_d <= 32'd0;
                        state <= COMPUTE_TOTAL_DEMAND;
                    end
                end

                COMPUTE_TOTAL_DEMAND: begin
                    if (idx < n) begin
                        sum_d <= sum_d + d_reg[idx];
                        idx <= idx + 4'd1;
                    end else begin
                        idx <= 4'd0;
                        state <= COMPUTE_FAIR_SHARE;
                    end
                end

                COMPUTE_FAIR_SHARE: begin
                    // y_i = (t * d_i * 65536) / D
                    // 16-bit * 16-bit = 32-bit, then * 65536 = 48-bit
                    if (idx < n) begin
                        if (sum_d != 32'd0) begin
                            div_a <= {16'd0, t} * d_reg[idx];
                            div_a <= div_a << 16; // Multiply by 65536
                            div_b <= {16'd0, sum_d};
                            div_start <= 1'b1;
                        end else begin
                            y_reg[idx] <= 32'd0;
                        end
                        state <= COMPUTE_FAIR_SHARE + 4'd1;
                    end else begin
                        idx <= 4'd0;
                        state <= INITIALIZE;
                    end
                end

                4'd3: begin // Wait for division
                    if (div_done) begin
                        y_reg[idx] <= quotient[31:0];
                        div_start <= 1'b0;
                        idx <= idx + 4'd1;
                        state <= COMPUTE_FAIR_SHARE;
                    end
                end

                INITIALIZE: begin
                    // x_i = min(max(a_i, y_i), b_i)
                    if (idx < n) begin
                        if (y_reg[idx][31:16] < a_reg[idx]) begin
                            x_reg[idx] <= {a_reg[idx], 16'd0};
                        end else if (y_reg[idx][31:16] > b_reg[idx]) begin
                            x_reg[idx] <= {b_reg[idx], 16'd0};
                        end else begin
                            x_reg[idx] <= y_reg[idx];
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        idx <= 4'd0;
                        state <= COMPUTE_SUM_X;
                    end
                end

                COMPUTE_SUM_X: begin
                    sum_x <= 48'd0;
                    idx <= 4'd0;
                    state <= 4'd5;
                end

                4'd5: begin // Accumulate sum_x
                    if (idx < n) begin
                        sum_x <= sum_x + x_reg[idx];
                        idx <= idx + 4'd1;
                    end else begin
                        state <= CHECK_CONVERGENCE;
                    end
                end

                CHECK_CONVERGENCE: begin
                    residual <= ({32'd0, t} << 16) - sum_x;
                    if ($signed(residual) < 0) begin
                        residual <= -$signed(residual);
                    end
                    
                    if (iteration_counter >= MAX_ITERATIONS || residual < CONVERGENCE_THRESH) begin
                        state <= OUTPUT_RESULT;
                    end else begin
                        idx <= 4'd0;
                        state <= DISTRIBUTE;
                    end
                end

                DISTRIBUTE: begin
                    // Distribute residual proportionally to d_i
                    // Adjust amount = residual * d_i / sum_d
                    if (idx < n) begin
                        if (sum_d != 32'd0) begin
                            div_a <= residual * d_reg[idx];
                            div_b <= {16'd0, sum_d};
                            div_start <= 1'b1;
                            state <= 4'd10;
                        end else begin
                            state <= PROJECT;
                        end
                    end else begin
                        iteration_counter <= iteration_counter + 4'd1;
                        state <= COMPUTE_SUM_X;
                    end
                end

                4'd10: begin // Wait for division
                    if (div_done) begin
                        residual_scaled <= quotient;
                        div_start <= 1'b0;
                        // Add or subtract based on original residual sign
                        if (residual >= 0) begin
                            x_reg[idx] <= x_reg[idx] + quotient[31:0];
                        end else begin
                            x_reg[idx] <= x_reg[idx] - quotient[31:0];
                        end
                        state <= PROJECT;
                    end
                end

                PROJECT: begin
                    // Clamp to [a_i, b_i]
                    if (x_reg[idx][31:16] < a_reg[idx]) begin
                        x_reg[idx] <= {a_reg[idx], 16'd0};
                    end else if (x_reg[idx][31:16] > b_reg[idx]) begin
                        x_reg[idx] <= {b_reg[idx], 16'd0};
                    end
                    idx <= idx + 4'd1;
                    state <= DISTRIBUTE;
                end

                OUTPUT_RESULT: begin
                    x_0 <= x_reg[0]; x_1 <= x_reg[1]; x_2 <= x_reg[2]; x_3 <= x_reg[3];
                    x_4 <= x_reg[4]; x_5 <= x_reg[5]; x_6 <= x_reg[6]; x_7 <= x_reg[7];
                    valid <= 1'b1;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule