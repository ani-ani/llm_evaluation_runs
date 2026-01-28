module MongeSubmatrixFinder(
    input clk,
    input rst_n,
    input start,
    input [511:0] matrix_flat,
    input [2:0] rows,
    input [2:0] cols,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LATCH = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal registers
    reg [511:0] latched_matrix;
    reg [2:0] latched_rows;
    reg [2:0] latched_cols;

    // Counters for iteration
    reg [2:0] r1, c1, r2, c2;
    reg [2:0] i, j;

    // Monge property check
    reg monge_valid;
    reg [7:0] current_area;
    reg [7:0] max_area;

    // Cycle counter for safety
    reg [12:0] cycle_count;
    localparam [12:0] MAX_CYCLES = 13'd4000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 13'd0;
            r1 <= 3'd0;
            c1 <= 3'd0;
            r2 <= 3'd0;
            c2 <= 3'd0;
            i <= 3'd0;
            j <= 3'd0;
            monge_valid <= 1'b1;
            current_area <= 8'd0;
            max_area <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 13'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LATCH;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LATCH: begin
                    latched_matrix <= matrix_flat;
                    latched_rows <= rows;
                    latched_cols <= cols;
                    r1 <= 3'd0;
                    c1 <= 3'd0;
                    r2 <= 3'd1;
                    c2 <= 3'd1;
                    max_area <= 8'd0;
                    next_state <= CHECK;
                end

                CHECK: begin
                    // Check if we've processed all submatrices
                    if (r1 == latched_rows - 1 && c1 == latched_cols - 1 && 
                        r2 == latched_rows && c2 == latched_cols) begin
                        next_state <= FINISH;
                    end else begin
                        // Initialize Monge check for new submatrix
                        if (r1 == 3'd0 && c1 == 3'd0 && r2 == 3'd1 && c2 == 3'd1) begin
                            monge_valid <= 1'b1;
                        end

                        // Check Monge property for current 2x2
                        if (monge_valid && r2 > r1 + 1 && c2 > c1 + 1) begin
                            // Extract elements
                            integer idx1 = r1 * 8 + c1;
                            integer idx2 = r1 * 8 + c2;
                            integer idx3 = r2 * 8 + c1;
                            integer idx4 = r2 * 8 + c2;

                            signed [7:0] a = latched_matrix[idx1*8 +: 8];
                            signed [7:0] b = latched_matrix[idx2*8 +: 8];
                            signed [7:0] c = latched_matrix[idx3*8 +: 8];
                            signed [7:0] d = latched_matrix[idx4*8 +: 8];

                            if (a + d > b + c) begin
                                monge_valid <= 1'b0;
                            end
                        end

                        // Move to next 2x2 in current submatrix
                        if (r2 < latched_rows && c2 < latched_cols) begin
                            if (r2 == latched_rows - 1 && c2 == latched_cols - 1) begin
                                // Finished checking this submatrix
                                if (monge_valid) begin
                                    current_area <= (r2 - r1) * (c2 - c1);
                                    if (current_area > max_area) begin
                                        max_area <= current_area;
                                    end
                                end

                                // Move to next submatrix
                                if (c2 == latched_cols) begin
                                    if (c1 == latched_cols - 1) begin
                                        r1 <= r1 + 1;
                                        c1 <= 3'd0;
                                        r2 <= r1 + 1;
                                        c2 <= 3'd1;
                                    end else begin
                                        c1 <= c1 + 1;
                                        r2 <= r1 + 1;
                                        c2 <= c1 + 1;
                                    end
                                end else begin
                                    c2 <= c2 + 1;
                                end
                            end else if (c2 == latched_cols - 1) begin
                                r2 <= r2 + 1;
                                c2 <= c1 + 1;
                            end else begin
                                c2 <= c2 + 1;
                            end
                        end else begin
                            // Move to next submatrix
                            if (c2 == latched_cols) begin
                                if (c1 == latched_cols - 1) begin
                                    r1 <= r1 + 1;
                                    c1 <= 3'd0;
                                    r2 <= r1 + 1;
                                    c2 <= 3'd1;
                                end else begin
                                    c1 <= c1 + 1;
                                    r2 <= r1 + 1;
                                    c2 <= c1 + 1;
                                end
                            end else begin
                                c2 <= c2 + 1;
                            end
                        end
                    end
                end

                FINISH: begin
                    result <= max_area;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Safety check for cycle count
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 13'd0;
        end
    end

endmodule