module mad_compute(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid [0:7][0:7],
    input wire [5:0] a_min,
    input wire [5:0] a_max,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] GENERATE_RECTANGLES = 4'd1;
    localparam [3:0] COMPUTE_DENSITIES = 4'd2;
    localparam [3:0] SORT = 4'd3;
    localparam [3:0] MEDIAN = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    // Fixed-point scale (2^16)
    localparam [31:0] FIXED_POINT_SCALE = 32'd65536;

    // Maximum number of rectangles (8x8 grid, max area 64)
    localparam [11:0] MAX_RECTANGLES = 12'd1024;

    // State registers
    reg [3:0] state;
    reg [31:0] density_count;
    reg [31:0] sort_iterations;
    reg [31:0] median_iterations;

    // Rectangle generation counters
    reg [2:0] rect_row_start;
    reg [2:0] rect_row_end;
    reg [2:0] rect_col_start;
    reg [2:0] rect_col_end;

    // Density computation registers
    reg [31:0] total_statisticians;
    reg [31:0] area;
    reg [31:0] density;

    // Density storage (1024 x 32-bit)
    reg [31:0] densities [0:1023];

    // Sorting registers
    reg [31:0] temp_density;
    reg [11:0] i, j;

    // Median computation registers
    reg [31:0] median_value;
    reg [31:0] median_sum;

    // Cycle counter for safety
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all state
            state <= IDLE;
            density_count <= 32'd0;
            sort_iterations <= 32'd0;
            median_iterations <= 32'd0;
            rect_row_start <= 3'd0;
            rect_row_end <= 3'd0;
            rect_col_start <= 3'd0;
            rect_col_end <= 3'd0;
            total_statisticians <= 32'd0;
            area <= 32'd0;
            density <= 32'd0;
            median_value <= 32'd0;
            median_sum <= 32'd0;
            cycle_count <= 16'd0;
            done <= 1'b0;
            result <= 32'd0;

            // Initialize density storage
            integer k;
            for (k = 0; k < 1024; k = k + 1) begin
                densities[k] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= GENERATE_RECTANGLES;
                        rect_row_start <= 3'd0;
                        rect_row_end <= 3'd0;
                        rect_col_start <= 3'd0;
                        rect_col_end <= 3'd0;
                        density_count <= 32'd0;
                    end
                end

                GENERATE_RECTANGLES: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Generate all possible rectangles
                    if (rect_row_end < 8) begin
                        // Compute area
                        area <= (rect_row_end - rect_row_start + 1) * (rect_col_end - rect_col_start + 1);
                        
                        // Check if area is within [a_min, a_max]
                        if (area >= a_min && area <= a_max) begin
                            // Compute total statisticians
                            total_statisticians <= 32'd0;
                            state <= COMPUTE_DENSITIES;
                        end else begin
                            // Move to next rectangle
                            if (rect_col_end < 7) begin
                                rect_col_end <= rect_col_end + 3'd1;
                            end else if (rect_row_end < 7) begin
                                rect_row_end <= rect_row_end + 3'd1;
                                rect_col_end <= rect_col_start;
                            end else if (rect_col_start < 7) begin
                                rect_col_start <= rect_col_start + 3'd1;
                                rect_row_end <= rect_row_start;
                                rect_col_end <= rect_col_start;
                            end else if (rect_row_start < 7) begin
                                rect_row_start <= rect_row_start + 3'd1;
                                rect_col_start <= 3'd0;
                                rect_row_end <= rect_row_start;
                                rect_col_end <= rect_col_start;
                            end else begin
                                // All rectangles processed
                                state <= SORT;
                                i <= 32'd0;
                                j <= 32'd0;
                                sort_iterations <= 32'd0;
                            end
                        end
                    end else begin
                        // All rectangles processed
                        state <= SORT;
                        i <= 32'd0;
                        j <= 32'd0;
                        sort_iterations <= 32'd0;
                    end
                end

                COMPUTE_DENSITIES: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Sum all cells in the rectangle
                    reg [2:0] r, c;
                    reg [31:0] sum;
                    
                    if (rect_row_end < 8) begin
                        // Compute sum of statisticians
                        sum = 32'd0;
                        for (r = rect_row_start; r <= rect_row_end; r = r + 1) begin
                            for (c = rect_col_start; c <= rect_col_end; c = c + 1) begin
                                sum = sum + grid[r][c];
                            end
                        end
                        total_statisticians <= sum;
                        
                        // Compute density: (total_statisticians * FIXED_POINT_SCALE) / area
                        // Using iterative subtraction for division
                        reg [31:0] numerator;
                        reg [31:0] denominator;
                        reg [31:0] quotient;
                        reg [31:0] remainder;
                        reg [4:0] div_iter;
                        
                        numerator = total_statisticians * FIXED_POINT_SCALE;
                        denominator = area;
                        quotient = 32'd0;
                        remainder = numerator;
                        
                        for (div_iter = 0; div_iter < 32; div_iter = div_iter + 1) begin
                            remainder = remainder << 1;
                            quotient = quotient << 1;
                            if (remainder >= denominator) begin
                                remainder = remainder - denominator;
                                quotient = quotient + 1;
                            end
                        end
                        
                        density <= quotient;
                        
                        // Store density
                        if (density_count < MAX_RECTANGLES) begin
                            densities[density_count] <= density;
                            density_count <= density_count + 32'd1;
                        end
                        
                        // Move to next rectangle
                        if (rect_col_end < 7) begin
                            rect_col_end <= rect_col_end + 3'd1;
                        end else if (rect_row_end < 7) begin
                            rect_row_end <= rect_row_end + 3'd1;
                            rect_col_end <= rect_col_start;
                        end else if (rect_col_start < 7) begin
                            rect_col_start <= rect_col_start + 3'd1;
                            rect_row_end <= rect_row_start;
                            rect_col_end <= rect_col_start;
                        end else if (rect_row_start < 7) begin
                            rect_row_start <= rect_row_start + 3'd1;
                            rect_col_start <= 3'd0;
                            rect_row_end <= rect_row_start;
                            rect_col_end <= rect_col_start;
                        end else begin
                            // All rectangles processed
                            state <= SORT;
                            i <= 32'd0;
                            j <= 32'd0;
                            sort_iterations <= 32'd0;
                        end
                    end else begin
                        // All rectangles processed
                        state <= SORT;
                        i <= 32'd0;
                        j <= 32'd0;
                        sort_iterations <= 32'd0;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Bubble sort implementation
                    if (sort_iterations < density_count) begin
                        if (j < (density_count - sort_iterations - 1)) begin
                            if (densities[j] > densities[j + 1]) begin
                                temp_density <= densities[j];
                                densities[j] <= densities[j + 1];
                                densities[j + 1] <= temp_density;
                            end
                            j <= j + 32'd1;
                        end else begin
                            j <= 32'd0;
                            sort_iterations <= sort_iterations + 32'd1;
                        end
                    end else begin
                        // Sorting complete, move to median computation
                        state <= MEDIAN;
                        median_iterations <= 32'd0;
                        median_sum <= 32'd0;
                    end
                end

                MEDIAN: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Compute median
                    if (density_count == 0) begin
                        median_value <= 32'd0;
                        state <= DONE_STATE;
                    end else if (density_count % 2 == 1) begin
                        // Odd count: take middle element
                        median_value <= densities[density_count / 2];
                        state <= DONE_STATE;
                    end else begin
                        // Even count: average of two middle elements
                        median_sum <= densities[density_count / 2 - 1] + densities[density_count / 2];
                        median_value <= median_sum / 2;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= median_value;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 32'd0;
                end
            endcase
            
            // Safety check for cycle count
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b0;
                result <= 32'd0;
            end
        end
    end

endmodule