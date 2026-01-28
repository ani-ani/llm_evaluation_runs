module BipartiteMatching(
    input clk,
    input rst_n,
    input start,
    input [31:0] springs,
    input [31:0] towns,
    input [63:0] hill_x,
    input [63:0] hill_y,
    input [63:0] hill_h,
    input [7:0] max_len,
    output reg [23:0] result,
    output reg done,
    output reg impossible
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] BUILD_COST = 3'd1;
    localparam [2:0] HUNGARIAN = 3'd2;
    localparam [2:0] COMPUTE_RESULT = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Constants
    localparam [23:0] INF = 24'd16777215;
    localparam [7:0] MAX_HILLS = 8'd16;

    // Internal registers
    reg [3:0] num_springs;
    reg [3:0] num_towns;
    reg [3:0] i, j, k;
    reg [3:0] row, col, step;
    reg [23:0] cost_matrix [0:15][0:15];
    reg [23:0] u [0:15], v [0:15];
    reg [3:0] p [0:15];
    reg [3:0] way [0:15];
    reg [23:0] minv [0:15];
    reg [3:0] minv_j;
    reg [23:0] total_cost;
    reg [23:0] dist;
    reg [7:0] dx, dy;
    reg [15:0] dx_sq, dy_sq;
    reg [15:0] dist_sq;
    reg [15:0] sqrt_val;
    reg [7:0] sqrt_iter;
    reg [15:0] sqrt_temp;
    reg [15:0] sqrt_prev;
    reg [15:0] sqrt_curr;
    reg [15:0] sqrt_diff;
    reg [15:0] sqrt_step;
    reg [15:0] sqrt_lut [0:255];
    reg [15:0] sqrt_lut_addr;
    reg [15:0] sqrt_lut_data;

    // Initialize sqrt LUT
    integer idx;
    initial begin
        for (idx = 0; idx < 256; idx = idx + 1) begin
            sqrt_lut[idx] = $sqrt(idx * 10000) / 100;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            cycle_count <= 10'd0;
            num_springs <= 4'd0;
            num_towns <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            row <= 4'd0;
            col <= 4'd0;
            step <= 4'd0;
            total_cost <= 24'd0;
            dist <= 24'd0;
            dx <= 8'd0;
            dy <= 8'd0;
            dx_sq <= 16'd0;
            dy_sq <= 16'd0;
            dist_sq <= 16'd0;
            sqrt_val <= 16'd0;
            sqrt_iter <= 8'd0;
            sqrt_temp <= 16'd0;
            sqrt_prev <= 16'd0;
            sqrt_curr <= 16'd0;
            sqrt_diff <= 16'd0;
            sqrt_step <= 16'd0;
            sqrt_lut_addr <= 16'd0;
            sqrt_lut_data <= 16'd0;
            
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    cost_matrix[i][j] <= INF;
                end
                u[i] <= 24'd0;
                v[i] <= 24'd0;
                p[i] <= 4'd0;
                way[i] <= 4'd0;
                minv[i] <= 24'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        // Extract number of springs and towns
                        num_springs <= springs[3:0];
                        num_towns <= towns[3:0];
                        state <= BUILD_COST;
                    end
                end
                
                BUILD_COST: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        impossible <= 1'b1;
                    end else begin
                        // Build cost matrix
                        if (i < num_springs && j < num_towns) begin
                            // Get spring and town indices
                            dx <= hill_x[(i << 2) + 3: (i << 2)] - hill_x[(j << 2) + 3: (j << 2)];
                            dy <= hill_y[(i << 2) + 3: (i << 2)] - hill_y[(j << 2) + 3: (j << 2)];
                            
                            // Check height constraint
                            if (hill_h[(i << 2) + 3: (i << 2)] > hill_h[(j << 2) + 3: (j << 2)]) begin
                                // Compute distance
                                dx_sq <= dx * dx;
                                dy_sq <= dy * dy;
                                dist_sq <= dx_sq + dy_sq;
                                
                                // Approximate sqrt using LUT and Newton-Raphson
                                sqrt_lut_addr <= dist_sq[15:8];
                                sqrt_lut_data <= sqrt_lut[sqrt_lut_addr];
                                sqrt_prev <= sqrt_lut_data << 8;
                                sqrt_curr <= sqrt_prev;
                                
                                for (sqrt_iter = 0; sqrt_iter < 8; sqrt_iter = sqrt_iter + 1) begin
                                    sqrt_temp <= (dist_sq << 16) / sqrt_prev;
                                    sqrt_curr <= (sqrt_prev + sqrt_temp) >> 1;
                                    sqrt_diff <= sqrt_prev - sqrt_curr;
                                    if (sqrt_diff[15] == 0) begin
                                        sqrt_prev <= sqrt_curr;
                                    end
                                end
                                
                                sqrt_val <= sqrt_curr >> 8;
                                dist <= sqrt_val;
                                
                                // Check length constraint
                                if (dist <= max_len) begin
                                    cost_matrix[i][j] <= dist;
                                end else begin
                                    cost_matrix[i][j] <= INF;
                                end
                            end else begin
                                cost_matrix[i][j] <= INF;
                            end
                            
                            j <= j + 1;
                            if (j >= num_towns) begin
                                j <= 4'd0;
                                i <= i + 1;
                                if (i >= num_springs) begin
                                    i <= 4'd0;
                                    state <= HUNGARIAN;
                                end
                            end
                        end else begin
                            state <= HUNGARIAN;
                        end
                    end
                end
                
                HUNGARIAN: begin
                    cycle_count <= cycle_count + 10'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        impossible <= 1'b1;
                    end else begin
                        // Hungarian algorithm
                        if (step == 4'd0) begin
                            // Step 0: Initialize u and v
                            for (i = 0; i < num_springs; i = i + 1) begin
                                u[i] <= 24'd0;
                                for (j = 0; j < num_towns; j = j + 1) begin
                                    if (cost_matrix[i][j] < u[i]) begin
                                        u[i] <= cost_matrix[i][j];
                                    end
                                end
                            end
                            step <= 4'd1;
                        end else if (step == 4'd1) begin
                            // Step 1: Initialize p
                            for (j = 0; j < num_towns; j = j + 1) begin
                                p[j] <= 4'd0;
                            end
                            step <= 4'd2;
                        end else if (step == 4'd2) begin
                            // Step 2: Initialize way
                            for (j = 0; j < num_towns; j = j + 1) begin
                                way[j] <= 4'd0;
                            end
                            step <= 4'd3;
                        end else if (step == 4'd3) begin
                            // Step 3: Find augmenting path
                            for (i = 0; i < num_springs; i = i + 1) begin
                                p[4'd0] <= i;
                                j <= 4'd0;
                                minv[4'd0] <= INF;
                                for (j = 0; j < num_towns; j = j + 1) begin
                                    if (cost_matrix[p[j]][j] - u[p[j]] - v[j] < minv[j]) begin
                                        minv[j] <= cost_matrix[p[j]][j] - u[p[j]] - v[j];
                                        way[j] <= p[j];
                                    end
                                end
                                
                                // Find minimum minv
                                minv_j <= 4'd0;
                                for (j = 0; j < num_towns; j = j + 1) begin
                                    if (minv[j] < minv[minv_j]) begin
                                        minv_j <= j;
                                    end
                                end
                                
                                // Update v
                                for (j = 0; j < num_towns; j = j + 1) begin
                                    if (j == minv_j) begin
                                        v[j] <= v[j] + minv[j];
                                    end
                                end
                                
                                // Update u
                                for (j = 0; j < num_towns; j = j + 1) begin
                                    if (p[j] != 4'd0) begin
                                        u[p[j]] <= u[p[j]] + minv[j];
                                    end
                                end
                                
                                // Update p
                                p[minv_j] <= way[minv_j];
                            end
                            step <= 4'd4;
                        end else if (step == 4'd4) begin
                            // Step 4: Compute total cost
                            total_cost <= 24'd0;
                            for (j = 0; j < num_towns; j = j + 1) begin
                                if (p[j] != 4'd0) begin
                                    total_cost <= total_cost + cost_matrix[p[j]][j];
                                end
                            end
                            
                            // Check if all towns are matched
                            impossible <= 1'b0;
                            for (j = 0; j < num_towns; j = j + 1) begin
                                if (p[j] == 4'd0) begin
                                    impossible <= 1'b1;
                                end
                            end
                            
                            if (impossible) begin
                                state <= FINISH;
                            end else begin
                                state <= COMPUTE_RESULT;
                            end
                        end
                    end
                end
                
                COMPUTE_RESULT: begin
                    result <= total_cost;
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