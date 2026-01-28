module max_area_subrectangle(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] m,
    input [15:0] a [0:15],
    input [15:0] b [0:15],
    input [31:0] x,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_MIN_SUM_A = 3'd1;
    localparam [2:0] COMPUTE_MIN_SUM_B = 3'd2;
    localparam [2:0] COMPUTE_MAX_AREA = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd5000;

    // Arrays to store min_sum_a and min_sum_b
    reg [31:0] min_sum_a [0:15];
    reg [31:0] min_sum_b [0:15];

    // Counters for loops
    reg [3:0] i, j, k;
    reg [31:0] current_sum_a, current_sum_b;
    reg [31:0] min_sum_temp_a, min_sum_temp_b;

    // For max area computation
    reg [3:0] max_i, max_j;
    reg [15:0] max_area;
    reg [31:0] product;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize all registers
            for (i = 0; i < 16; i = i + 1) begin
                min_sum_a[i] <= 32'd0;
                min_sum_b[i] <= 32'd0;
            end
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            current_sum_a <= 32'd0;
            current_sum_b <= 32'd0;
            min_sum_temp_a <= 32'd0;
            min_sum_temp_b <= 32'd0;
            max_i <= 4'd0;
            max_j <= 4'd0;
            max_area <= 16'd0;
            product <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_MIN_SUM_A;
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                        current_sum_a <= 32'd0;
                        min_sum_temp_a <= 32'd0;
                    end
                end

                COMPUTE_MIN_SUM_A: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute min_sum_a for all lengths
                    if (i < n) begin
                        if (j == 0) begin
                            current_sum_a <= a[i];
                            min_sum_temp_a <= a[i];
                            j <= j + 4'd1;
                        end else if (j < i + 4'd1) begin
                            current_sum_a <= current_sum_a + a[i + j];
                            if (current_sum_a < min_sum_temp_a) begin
                                min_sum_temp_a <= current_sum_a;
                            end
                            j <= j + 4'd1;
                        end else begin
                            min_sum_a[i] <= min_sum_temp_a;
                            i <= i + 4'd1;
                            j <= 4'd0;
                            current_sum_a <= 32'd0;
                            min_sum_temp_a <= 32'd0;
                        end
                    end else begin
                        state <= COMPUTE_MIN_SUM_B;
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                        current_sum_b <= 32'd0;
                        min_sum_temp_b <= 32'd0;
                    end
                end

                COMPUTE_MIN_SUM_B: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute min_sum_b for all lengths
                    if (i < m) begin
                        if (j == 0) begin
                            current_sum_b <= b[i];
                            min_sum_temp_b <= b[i];
                            j <= j + 4'd1;
                        end else if (j < i + 4'd1) begin
                            current_sum_b <= current_sum_b + b[i + j];
                            if (current_sum_b < min_sum_temp_b) begin
                                min_sum_temp_b <= current_sum_b;
                            end
                            j <= j + 4'd1;
                        end else begin
                            min_sum_b[i] <= min_sum_temp_b;
                            i <= i + 4'd1;
                            j <= 4'd0;
                            current_sum_b <= 32'd0;
                            min_sum_temp_b <= 32'd0;
                        end
                    end else begin
                        state <= COMPUTE_MAX_AREA;
                        i <= 4'd0;
                        j <= 4'd0;
                        max_area <= 16'd0;
                        max_i <= 4'd0;
                        max_j <= 4'd0;
                    end
                end

                COMPUTE_MAX_AREA: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Find max(i*j) where min_sum_a[i] * min_sum_b[j] <= x
                    if (i < n) begin
                        if (j < m) begin
                            product <= min_sum_a[i] * min_sum_b[j];
                            if (product <= x) begin
                                if ((i + 4'd1) * (j + 4'd1) > max_area) begin
                                    max_area <= (i + 4'd1) * (j + 4'd1);
                                    max_i <= i;
                                    max_j <= j;
                                end
                            end
                            j <= j + 4'd1;
                        end else begin
                            i <= i + 4'd1;
                            j <= 4'd0;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= max_area;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 16'd0;
                end
            endcase
        end
    end
endmodule