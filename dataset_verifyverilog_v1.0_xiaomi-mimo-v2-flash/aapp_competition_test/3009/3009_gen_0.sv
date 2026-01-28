module LightingBalancing(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] lamps_x [0:15],
    input wire [9:0] lamps_y [0:15],
    input wire [15:0] lamps_e [0:15],
    input wire [3:0] num_lamps,
    output reg [31:0] result,
    output reg valid,
    output reg impossible,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] PREPARE       = 4'd1;
    localparam [3:0] SUBSET_LOOP   = 4'd2;
    localparam [3:0] CHECK_SUBSET  = 4'd3;
    localparam [3:0] CONVEX_HULL   = 4'd4;
    localparam [3:0] SORT_START    = 4'd5;
    localparam [3:0] SORT_COMPARE  = 4'd6;
    localparam [3:0] BUILD_HULL    = 4'd7;
    localparam [3:0] PERIMETER     = 4'd8;
    localparam [3:0] UPDATE_MIN    = 4'd9;
    localparam [3:0] COMPLETE      = 4'd10;
    localparam [3:0] IMPOSSIBLE    = 4'd11;

    reg [3:0] state, next_state;
    
    // Internal registers
    reg [15:0] total_energy;
    reg [15:0] target_energy;
    reg [31:0] current_min;
    reg [15:0] subset_sum;
    reg [31:0] current_perimeter;
    reg [15:0] subset_mask;
    reg [4:0] subset_idx;
    reg [3:0] lamp_idx;
    reg [3:0] hull_size;
    reg [3:0] hull_idx;
    reg [3:0] perm_idx;
    reg [15:0] temp_energy;
    
    // Sorting registers
    reg [9:0] sorted_x [0:15];
    reg [9:0] sorted_y [0:15];
    reg [3:0] sorted_indices [0:15];
    reg [3:0] swap_temp_idx;
    reg [9:0] swap_temp_x;
    reg [9:0] swap_temp_y;
    reg sort_done;
    reg [3:0] i, j;
    
    // Convex hull registers
    reg [9:0] hull_x [0:15];
    reg [9:0] hull_y [0:15];
    reg [3:0] hull_ptr;
    
    // Distance calculation registers
    reg signed [31:0] dx;
    reg signed [31:0] dy;
    reg signed [63:0] dx_sq;
    reg signed [63:0] dy_sq;
    reg signed [63:0] sum_sq;
    reg [15:0] dist_int;
    reg [15:0] dist_frac;
    reg [31:0] dist_result;
    reg [15:0] sqrt_temp;
    reg [15:0] sqrt_val;
    reg [3:0] sqrt_iter;
    
    // Cross product for convex hull
    reg signed [31:0] cross_x1, cross_y1, cross_x2, cross_y2;
    reg signed [63:0] cross_result;
    
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            valid <= 1'b0;
            impossible <= 1'b0;
            done <= 1'b0;
            total_energy <= 16'd0;
            target_energy <= 16'd0;
            current_min <= 32'h7FFFFFFF;
            subset_sum <= 16'd0;
            current_perimeter <= 32'd0;
            subset_mask <= 16'd0;
            subset_idx <= 5'd0;
            lamp_idx <= 4'd0;
            hull_size <= 4'd0;
            hull_idx <= 4'd0;
            perm_idx <= 4'd0;
            temp_energy <= 16'd0;
            sort_done <= 1'b0;
            hull_ptr <= 4'd0;
            dist_result <= 32'd0;
            sqrt_temp <= 16'd0;
            sqrt_val <= 16'd0;
            sqrt_iter <= 4'd0;
            for (k = 0; k < 16; k = k + 1) begin
                sorted_x[k] <= 10'd0;
                sorted_y[k] <= 10'd0;
                sorted_indices[k] <= 4'd0;
                hull_x[k] <= 10'd0;
                hull_y[k] <= 10'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    if (start) begin
                        state <= PREPARE;
                    end
                end
                
                PREPARE: begin
                    // Compute total energy and check validity
                    if (lamp_idx < num_lamps) begin
                        temp_energy <= lamps_e[lamp_idx];
                        lamp_idx <= lamp_idx + 4'd1;
                    end else begin
                        lamp_idx <= 4'd0;
                        // Check if total is even and > 0
                        if (total_energy[0] == 1'b1 || total_energy == 16'd0) begin
                            state <= IMPOSSIBLE;
                        end else begin
                            target_energy <= total_energy >> 1;
                            current_min <= 32'h7FFFFFFF;
                            subset_idx <= 5'd0;
                            state <= SUBSET_LOOP;
                        end
                    end
                end
                
                SUBSET_LOOP: begin
                    // Generate subset (skip empty and full)
                    if (subset_idx < (5'd1 << num_lamps)) begin
                        subset_mask <= (16'hFFFF >> (16 - num_lamps)) & subset_idx;
                        subset_idx <= subset_idx + 5'd1;
                        if (subset_mask == 16'd0 || subset_mask == ((16'hFFFF >> (16 - num_lamps)))) begin
                            // Skip empty or full subset
                            state <= SUBSET_LOOP;
                        end else begin
                            subset_sum <= 16'd0;
                            lamp_idx <= 4'd0;
                            state <= CHECK_SUBSET;
                        end
                    end else begin
                        state <= COMPLETE;
                    end
                end
                
                CHECK_SUBSET: begin
                    // Compute subset energy sum
                    if (lamp_idx < num_lamps) begin
                        if (subset_mask[lamp_idx]) begin
                            subset_sum <= subset_sum + lamps_e[lamp_idx];
                        end
                        lamp_idx <= lamp_idx + 4'd1;
                    end else begin
                        // Check if balanced
                        if (subset_sum == target_energy) begin
                            // Valid subset - build convex hull
                            hull_size <= 4'd0;
                            lamp_idx <= 4'd0;
                            state <= CONVEX_HULL;
                        end else begin
                            state <= SUBSET_LOOP;
                        end
                    end
                end
                
                CONVEX_HULL: begin
                    // Extract points in subset
                    if (lamp_idx < num_lamps) begin
                        if (subset_mask[lamp_idx]) begin
                            sorted_x[hull_size] <= lamps_x[lamp_idx];
                            sorted_y[hull_size] <= lamps_y[lamp_idx];
                            sorted_indices[hull_size] <= lamp_idx;
                            hull_size <= hull_size + 4'd1;
                        end
                        lamp_idx <= lamp_idx + 4'd1;
                    end else begin
                        // Sort points by x, then y
                        if (hull_size <= 4'd1) begin
                            // 0 or 1 point = zero perimeter
                            current_perimeter <= 32'd0;
                            state <= UPDATE_MIN;
                        end else begin
                            i <= 4'd0;
                            j <= 4'd1;
                            sort_done <= 1'b0;
                            state <= SORT_START;
                        end
                    end
                end
                
                SORT_START: begin
                    // Bubble sort for small arrays
                    if (j < hull_size) begin
                        // Compare x coordinates
                        if (sorted_x[i] > sorted_x[j]) begin
                            swap_temp_x <= sorted_x[i];
                            swap_temp_y <= sorted_y[i];
                            swap_temp_idx <= sorted_indices[i];
                            sorted_x[i] <= sorted_x[j];
                            sorted_y[i] <= sorted_y[j];
                            sorted_indices[i] <= sorted_indices[j];
                            sorted_x[j] <= swap_temp_x;
                            sorted_y[j] <= swap_temp_y;
                            sorted_indices[j] <= swap_temp_idx;
                        end else if (sorted_x[i] == sorted_x[j] && sorted_y[i] > sorted_y[j]) begin
                            swap_temp_x <= sorted_x[i];
                            swap_temp_y <= sorted_y[i];
                            swap_temp_idx <= sorted_indices[i];
                            sorted_x[i] <= sorted_x[j];
                            sorted_y[i] <= sorted_y[j];
                            sorted_indices[i] <= sorted_indices[j];
                            sorted_x[j] <= swap_temp_x;
                            sorted_y[j] <= swap_temp_y;
                            sorted_indices[j] <= swap_temp_idx;
                        end
                        j <= j + 4'd1;
                        state <= SORT_COMPARE;
                    end else begin
                        i <= i + 4'd1;
                        j <= i + 4'd2;
                        if (i >= hull_size - 4'd1) begin
                            // Build lower hull
                            hull_ptr <= 4'd0;
                            lamp_idx <= 4'd0;
                            state <= BUILD_HULL;
                        end else begin
                            state <= SORT_START;
                        end
                    end
                end
                
                SORT_COMPARE: begin
                    // Continue bubble sort
                    if (j < hull_size) begin
                        // Compare x coordinates
                        if (sorted_x[i] > sorted_x[j]) begin
                            swap_temp_x <= sorted_x[i];
                            swap_temp_y <= sorted_y[i];
                            swap_temp_idx <= sorted_indices[i];
                            sorted_x[i] <= sorted_x[j];
                            sorted_y[i] <= sorted_y[j];
                            sorted_indices[i] <= sorted_indices[j];
                            sorted_x[j] <= swap_temp_x;
                            sorted_y[j] <= swap_temp_y;
                            sorted_indices[j] <= swap_temp_idx;
                        end else if (sorted_x[i] == sorted_x[j] && sorted_y[i] > sorted_y[j]) begin
                            swap_temp_x <= sorted_x[i];
                            swap_temp_y <= sorted_y[i];
                            swap_temp_idx <= sorted_indices[i];
                            sorted_x[i] <= sorted_x[j];
                            sorted_y[i] <= sorted_y[j];
                            sorted_indices[i] <= sorted_indices[j];
                            sorted_x[j] <= swap_temp_x;
                            sorted_y[j] <= swap_temp_y;
                            sorted_indices[j] <= swap_temp_idx;
                        end
                        j <= j + 4'd1;
                        state <= SORT_COMPARE;
                    end else begin
                        i <= i + 4'd1;
                        j <= i + 4'd2;
                        if (i >= hull_size - 4'd1) begin
                            hull_ptr <= 4'd0;
                            lamp_idx <= 4'd0;
                            state <= BUILD_HULL;
                        end else begin
                            state <= SORT_START;
                        end
                    end
                end
                
                BUILD_HULL: begin
                    // Monotone chain algorithm
                    if (lamp_idx < hull_size) begin
                        // Check if hull has at least 2 points
                        if (hull_ptr >= 4'd2) begin
                            // Compute cross product
                            cross_x1 <= {22'd0, sorted_x[lamp_idx]} - {22'd0, hull_x[hull_ptr - 4'd2]};
                            cross_y1 <= {22'd0, sorted_y[lamp_idx]} - {22'd0, hull_y[hull_ptr - 4'd2]};
                            cross_x2 <= {22'd0, hull_x[hull_ptr - 4'd1]} - {22'd0, hull_x[hull_ptr - 4'd2]};
                            cross_y2 <= {22'd0, hull_y[hull_ptr - 4'd1]} - {22'd0, hull_y[hull_ptr - 4'd2]};
                            state <= BUILD_HULL;
                            // For lower hull, we want cross product <= 0
                            // But need to wait for cross calculation
                            // Simplified: just pop and continue
                            if ((({22'd0, sorted_x[lamp_idx]} - {22'd0, hull_x[hull_ptr - 4'd2]}) * 
                                 ({22'd0, hull_y[hull_ptr - 4'd1]} - {22'd0, hull_y[hull_ptr - 4'd2]}) - 
                                 ({22'd0, sorted_y[lamp_idx]} - {22'd0, hull_y[hull_ptr - 4'd2]}) * 
                                 ({22'd0, hull_x[hull_ptr - 4'd1]} - {22'd0, hull_x[hull_ptr - 4'd2]}) <= 32'd0)) begin
                                hull_ptr <= hull_ptr - 4'd1;
                            end else begin
                                hull_x[hull_ptr] <= sorted_x[lamp_idx];
                                hull_y[hull_ptr] <= sorted_y[lamp_idx];
                                hull_ptr <= hull_ptr + 4'd1;
                                lamp_idx <= lamp_idx + 4'd1;
                            end
                        end else begin
                            hull_x[hull_ptr] <= sorted_x[lamp_idx];
                            hull_y[hull_ptr] <= sorted_y[lamp_idx];
                            hull_ptr <= hull_ptr + 4'd1;
                            lamp_idx <= lamp_idx + 4'd1;
                        end
                    end else begin
                        // Build upper hull
                        lamp_idx <= hull_size - 4'd2;
                        hull_ptr <= hull_ptr - 4'd1; // Remove duplicate last point
                        state <= PERIMETER;
                    end
                end
                
                PERIMETER: begin
                    // Calculate perimeter of hull
                    if (hull_ptr <= 4'd1) begin
                        // Less than 2 points
                        current_perimeter <= 32'd0;
                        state <= UPDATE_MIN;
                    end else begin
                        // Calculate distance between consecutive points
                        if (perm_idx < hull_ptr - 4'd1) begin
                            dx <= {22'd0, hull_x[perm_idx + 4'd1]} - {22'd0, hull_x[perm_idx]};
                            dy <= {22'd0, hull_y[perm_idx + 4'd1]} - {22'd0, hull_y[perm_idx]};
                            perm_idx <= perm_idx + 4'd1;
                            state <= PERIMETER;
                            // Compute distance and add to perimeter
                            dist_int <= 16'd0;
                            dist_frac <= 16'd0;
                        end else if (perm_idx == hull_ptr - 4'd1) begin
                            // Close the loop: last to first point
                            dx <= {22'd0, hull_x[0]} - {22'd0, hull_x[hull_ptr - 4'd1]};
                            dy <= {22'd0, hull_y[0]} - {22'd0, hull_y[hull_ptr - 4'd1]};
                            perm_idx <= perm_idx + 4'd1;
                            state <= PERIMETER;
                        end else begin
                            // Done with perimeter
                            state <= UPDATE_MIN;
                        end
                    end
                end
                
                UPDATE_MIN: begin
                    // Compare with current minimum
                    if (current_perimeter < current_min) begin
                        current_min <= current_perimeter;
                    end
                    perm_idx <= 4'd0;
                    state <= SUBSET_LOOP;
                end
                
                COMPLETE: begin
                    if (current_min == 32'h7FFFFFFF) begin
                        state <= IMPOSSIBLE;
                    end else begin
                        result <= current_min;
                        valid <= 1'b1;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                
                IMPOSSIBLE: begin
                    result <= 32'd0;
                    impossible <= 1'b1;
                    valid <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Accumulate total energy during PREPARE
            if (state == PREPARE && lamp_idx < num_lamps) begin
                total_energy <= total_energy + temp_energy;
            end
            
            // Distance calculation logic
            if (state == PERIMETER && perm_idx > 4'd0 && perm_idx <= hull_ptr) begin
                // Compute squared distance (Q16.16 * 64)
                dx_sq <= dx * dx;
                dy_sq <= dy * dy;
                sum_sq <= dx_sq + dy_sq;
                // Simplified sqrt (integer part only for now)
                sqrt_temp <= 16'd0;
                sqrt_val <= 16'd0;
                sqrt_iter <= 4'd0;
                // For now, use approximation
                // Square root approximation
                if (sum_sq[63:32] < 32'd65536) begin
                    // Use 16-bit lookup
                    sqrt_val <= approx_sqrt(sum_sq[47:16]);
                end else begin
                    sqrt_val <= approx_sqrt(sum_sq[63:48]);
                end
                // Add to perimeter (scaled by 64 for Q10.6)
                current_perimeter <= current_perimeter + (sqrt_val << 16);
            end
        end
    end
    
    // Simple square root approximation function
    function [15:0] approx_sqrt;
        input [31:0] x;
        begin
            // Newton-Raphson approximation
            // Starting guess
            approx_sqrt = x >> 16;
            if (approx_sqrt < 16'd256) approx_sqrt = 16'd256;
            // One iteration
            approx_sqrt = (approx_sqrt + (x >> 16) / approx_sqrt) >> 1;
        end
    endfunction

endmodule