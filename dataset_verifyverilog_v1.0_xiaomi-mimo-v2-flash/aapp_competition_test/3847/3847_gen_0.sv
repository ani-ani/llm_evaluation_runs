module max_area_subrectangle (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] m,
    input wire [15:0] a [0:15],
    input wire [15:0] b [0:15],
    input wire [31:0] x,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] PRECOMPUTE_A = 3'd1;
    localparam [2:0] PRECOMPUTE_B = 3'd2;
    localparam [2:0] COMPUTE_AREA = 3'd3;
    localparam [2:0] FINISH       = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // min_sum_a and min_sum_b (length 1-16, index 1-16)
    reg [31:0] min_sum_a [15:1]; // Index 1-15 for lengths 1-15, plus 16
    reg [31:0] min_sum_b [15:1];

    // Counter variables for loops
    reg [3:0] i, j, k, l;
    reg [3:0] len_a, len_b;
    reg [31:0] current_sum;
    reg [31:0] temp_area;
    reg [31:0] best_area;

    // Temporary sum registers for loops
    reg [31:0] sum_a;
    reg [31:0] sum_b;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            l <= 4'd0;
            len_a <= 4'd0;
            len_b <= 4'd0;
            current_sum <= 32'd0;
            temp_area <= 32'd0;
            best_area <= 32'd0;
            sum_a <= 32'd0;
            sum_b <= 32'd0;
            // Initialize min_sum arrays
            min_sum_a[1] <= 32'hFFFFFFFF;
            min_sum_a[2] <= 32'hFFFFFFFF;
            min_sum_a[3] <= 32'hFFFFFFFF;
            min_sum_a[4] <= 32'hFFFFFFFF;
            min_sum_a[5] <= 32'hFFFFFFFF;
            min_sum_a[6] <= 32'hFFFFFFFF;
            min_sum_a[7] <= 32'hFFFFFFFF;
            min_sum_a[8] <= 32'hFFFFFFFF;
            min_sum_a[9] <= 32'hFFFFFFFF;
            min_sum_a[10] <= 32'hFFFFFFFF;
            min_sum_a[11] <= 32'hFFFFFFFF;
            min_sum_a[12] <= 32'hFFFFFFFF;
            min_sum_a[13] <= 32'hFFFFFFFF;
            min_sum_a[14] <= 32'hFFFFFFFF;
            min_sum_a[15] <= 32'hFFFFFFFF;
            min_sum_b[1] <= 32'hFFFFFFFF;
            min_sum_b[2] <= 32'hFFFFFFFF;
            min_sum_b[3] <= 32'hFFFFFFFF;
            min_sum_b[4] <= 32'hFFFFFFFF;
            min_sum_b[5] <= 32'hFFFFFFFF;
            min_sum_b[6] <= 32'hFFFFFFFF;
            min_sum_b[7] <= 32'hFFFFFFFF;
            min_sum_b[8] <= 32'hFFFFFFFF;
            min_sum_b[9] <= 32'hFFFFFFFF;
            min_sum_b[10] <= 32'hFFFFFFFF;
            min_sum_b[11] <= 32'hFFFFFFFF;
            min_sum_b[12] <= 32'hFFFFFFFF;
            min_sum_b[13] <= 32'hFFFFFFFF;
            min_sum_b[14] <= 32'hFFFFFFFF;
            min_sum_b[15] <= 32'hFFFFFFFF;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    best_area <= 32'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    k <= 4'd0;
                    l <= 4'd0;
                    len_a <= 4'd1;
                    len_b <= 4'd1;
                    // Reset min_sum arrays
                    min_sum_a[1] <= 32'hFFFFFFFF;
                    min_sum_a[2] <= 32'hFFFFFFFF;
                    min_sum_a[3] <= 32'hFFFFFFFF;
                    min_sum_a[4] <= 32'hFFFFFFFF;
                    min_sum_a[5] <= 32'hFFFFFFFF;
                    min_sum_a[6] <= 32'hFFFFFFFF;
                    min_sum_a[7] <= 32'hFFFFFFFF;
                    min_sum_a[8] <= 32'hFFFFFFFF;
                    min_sum_a[9] <= 32'hFFFFFFFF;
                    min_sum_a[10] <= 32'hFFFFFFFF;
                    min_sum_a[11] <= 32'hFFFFFFFF;
                    min_sum_a[12] <= 32'hFFFFFFFF;
                    min_sum_a[13] <= 32'hFFFFFFFF;
                    min_sum_a[14] <= 32'hFFFFFFFF;
                    min_sum_a[15] <= 32'hFFFFFFFF;
                    min_sum_b[1] <= 32'hFFFFFFFF;
                    min_sum_b[2] <= 32'hFFFFFFFF;
                    min_sum_b[3] <= 32'hFFFFFFFF;
                    min_sum_b[4] <= 32'hFFFFFFFF;
                    min_sum_b[5] <= 32'hFFFFFFFF;
                    min_sum_b[6] <= 32'hFFFFFFFF;
                    min_sum_b[7] <= 32'hFFFFFFFF;
                    min_sum_b[8] <= 32'hFFFFFFFF;
                    min_sum_b[9] <= 32'hFFFFFFFF;
                    min_sum_b[10] <= 32'hFFFFFFFF;
                    min_sum_b[11] <= 32'hFFFFFFFF;
                    min_sum_b[12] <= 32'hFFFFFFFF;
                    min_sum_b[13] <= 32'hFFFFFFFF;
                    min_sum_b[14] <= 32'hFFFFFFFF;
                    min_sum_b[15] <= 32'hFFFFFFFF;
                    if (start) begin
                        state <= PRECOMPUTE_A;
                    end
                end

                PRECOMPUTE_A: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute min_sum for length len_a
                    if (i == 4'd0 && j == 4'd0) begin
                        current_sum <= 32'd0;
                    end
                    
                    if (i < n && j < n && i <= j) begin
                        if (j == 4'd0) begin
                            current_sum <= {16'd0, a[i]};
                        end else begin
                            current_sum <= current_sum + {16'd0, a[j]};
                        end
                        if (j == (i + len_a - 4'd1) && j < n) begin
                            if (current_sum < min_sum_a[len_a]) begin
                                min_sum_a[len_a] <= current_sum;
                            end
                        end
                        j <= j + 4'd1;
                    end else begin
                        // Reset j and move i
                        j <= 4'd0;
                        if (i < n - len_a) begin
                            i <= i + 4'd1;
                        end else begin
                            // Finished this length
                            if (len_a < n) begin
                                len_a <= len_a + 4'd1;
                                i <= 4'd0;
                                j <= 4'd0;
                            end else begin
                                // Done with A, go to B
                                len_a <= 4'd1;
                                i <= 4'd0;
                                j <= 4'd0;
                                state <= PRECOMPUTE_B;
                            end
                        end
                    end
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= PRECOMPUTE_B;
                    end
                end

                PRECOMPUTE_B: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute min_sum for length len_b
                    if (i == 4'd0 && j == 4'd0) begin
                        current_sum <= 32'd0;
                    end
                    
                    if (i < m && j < m && i <= j) begin
                        if (j == 4'd0) begin
                            current_sum <= {16'd0, b[i]};
                        end else begin
                            current_sum <= current_sum + {16'd0, b[j]};
                        end
                        if (j == (i + len_b - 4'd1) && j < m) begin
                            if (current_sum < min_sum_b[len_b]) begin
                                min_sum_b[len_b] <= current_sum;
                            end
                        end
                        j <= j + 4'd1;
                    end else begin
                        // Reset j and move i
                        j <= 4'd0;
                        if (i < m - len_b) begin
                            i <= i + 4'd1;
                        end else begin
                            // Finished this length
                            if (len_b < m) begin
                                len_b <= len_b + 4'd1;
                                i <= 4'd0;
                                j <= 4'd0;
                            end else begin
                                // Done with B, go to compute area
                                len_b <= 4'd1;
                                i <= 4'd1;
                                j <= 4'd1;
                                state <= COMPUTE_AREA;
                            end
                        end
                    end
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        i <= 4'd1;
                        j <= 4'd1;
                        state <= COMPUTE_AREA;
                    end
                end

                COMPUTE_AREA: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if lengths are valid (<= n and <= m)
                    if (i <= n && j <= m) begin
                        // Check if product is valid
                        if (i > 4'd0 && j > 4'd0 && i <= 4'd15 && j <= 4'd15) begin
                            if (min_sum_a[i] != 32'hFFFFFFFF && min_sum_b[j] != 32'hFFFFFFFF) begin
                                // 32-bit multiplication to avoid overflow
                                temp_area <= min_sum_a[i] * min_sum_b[j];
                                
                                if (min_sum_a[i] * min_sum_b[j] <= x) begin
                                    temp_area <= {16'd0, i} * {16'd0, j};
                                    if ({16'd0, i} * {16'd0, j} > best_area) begin
                                        best_area <= {16'd0, i} * {16'd0, j};
                                    end
                                end
                            end
                        end
                    end
                    
                    // Move to next (i, j) pair
                    if (j < n) begin
                        j <= j + 4'd1;
                    end else begin
                        j <= 4'd1;
                        if (i < m) begin
                            i <= i + 4'd1;
                        end else begin
                            // Done computing
                            result <= best_area[15:0];
                            state <= FINISH;
                        end
                    end
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= best_area[15:0];
                        state <= FINISH;
                    end
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