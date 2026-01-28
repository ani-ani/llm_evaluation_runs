module LineIntersectionCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [31:0] x0_0, y0_0, x1_0, y1_0,
    input wire signed [31:0] x0_1, y0_1, x1_1, y1_1,
    input wire signed [31:0] x0_2, y0_2, x1_2, y1_2,
    input wire [2:0] line_valid,
    output reg signed [7:0] count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] DEDUPLICATE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Intermediate storage for intersection points
    reg signed [63:0] x_num [0:2];
    reg signed [63:0] y_num [0:2];
    reg signed [63:0] D [0:2];
    reg [2:0] point_count;
    reg infinite_flag;
    
    // Current pair being processed
    reg [1:0] i_reg, j_reg;
    
    // Deduplication state
    reg [1:0] dup_i, dup_j;
    reg [2:0] unique_count;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            count <= 8'd0;
            done <= 1'b0;
            
            // Initialize all registers
            for (integer k = 0; k < 3; k = k + 1) begin
                x_num[k] <= 64'd0;
                y_num[k] <= 64'd0;
                D[k] <= 64'd0;
            end
            point_count <= 3'd0;
            infinite_flag <= 1'b0;
            i_reg <= 2'd0;
            j_reg <= 2'd0;
            dup_i <= 2'd0;
            dup_j <= 2'd0;
            unique_count <= 3'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE;
                        // Reset computation state
                        point_count <= 3'd0;
                        infinite_flag <= 1'b0;
                        i_reg <= 2'd0;
                        j_reg <= 2'd1;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all pairs
                    if (i_reg == 2'd2 && j_reg == 2'd3) begin
                        if (infinite_flag) begin
                            count <= 8'hFF;
                            next_state <= FINISH;
                        end else begin
                            next_state <= DEDUPLICATE;
                            dup_i <= 2'd0;
                            dup_j <= 2'd0;
                            unique_count <= 3'd0;
                        end
                    end else begin
                        // Process current pair (i_reg, j_reg)
                        if (line_valid[i_reg] && line_valid[j_reg]) begin
                            reg signed [31:0] dx_i, dy_i, dx_j, dy_j;
                            reg signed [63:0] D_val, t1_num, t2_num;
                            reg signed [63:0] v_dot_i, n2, n3, min_n, max_n;
                            reg collinear, overlap;
                            
                            // Compute direction vectors
                            dx_i = x1_0 - x0_0;
                            dy_i = y1_0 - y0_0;
                            dx_j = x1_1 - x0_1;
                            dy_j = y1_1 - y0_1;
                            
                            if (i_reg == 2'd0) begin
                                dx_i = x1_0 - x0_0;
                                dy_i = y1_0 - y0_0;
                            end else if (i_reg == 2'd1) begin
                                dx_i = x1_1 - x0_1;
                                dy_i = y1_1 - y0_1;
                            end else begin // i_reg == 2'd2
                                dx_i = x1_2 - x0_2;
                                dy_i = y1_2 - y0_2;
                            end
                            
                            if (j_reg == 2'd0) begin
                                dx_j = x1_0 - x0_0;
                                dy_j = y1_0 - y0_0;
                            end else if (j_reg == 2'd1) begin
                                dx_j = x1_1 - x0_1;
                                dy_j = y1_1 - y0_1;
                            end else begin // j_reg == 2'd2
                                dx_j = x1_2 - x0_2;
                                dy_j = y1_2 - y0_2;
                            end
                            
                            // Compute denominator
                            D_val = $signed(dx_i) * $signed(dy_j) - $signed(dx_j) * $signed(dy_i);
                            
                            if (D_val == 64'd0) begin
                                // Check collinearity
                                reg signed [63:0] collinear_check;
                                if (i_reg == 2'd0 && j_reg == 2'd1) begin
                                    collinear_check = ($signed(x0_1) - $signed(x0_0)) * $signed(dy_i) - ($signed(y0_1) - $signed(y0_0)) * $signed(dx_i);
                                end else if (i_reg == 2'd0 && j_reg == 2'd2) begin
                                    collinear_check = ($signed(x0_2) - $signed(x0_0)) * $signed(dy_i) - ($signed(y0_2) - $signed(y0_0)) * $signed(dx_i);
                                end else if (i_reg == 2'd1 && j_reg == 2'd2) begin
                                    collinear_check = ($signed(x0_2) - $signed(x0_1)) * $signed(dy_i) - ($signed(y0_2) - $signed(y0_1)) * $signed(dx_i);
                                end
                                
                                collinear = (collinear_check == 64'd0);
                                
                                if (collinear) begin
                                    // Check overlap
                                    v_dot_i = $signed(dx_i) * $signed(dx_i) + $signed(dy_i) * $signed(dy_i);
                                    
                                    if (i_reg == 2'd0 && j_reg == 2'd1) begin
                                        n2 = ($signed(x0_1) - $signed(x0_0)) * $signed(dx_i) + ($signed(y0_1) - $signed(y0_0)) * $signed(dy_i);
                                        n3 = ($signed(x1_1) - $signed(x0_0)) * $signed(dx_i) + ($signed(y1_1) - $signed(y0_0)) * $signed(dy_i);
                                    end else if (i_reg == 2'd0 && j_reg == 2'd2) begin
                                        n2 = ($signed(x0_2) - $signed(x0_0)) * $signed(dx_i) + ($signed(y0_2) - $signed(y0_0)) * $signed(dy_i);
                                        n3 = ($signed(x1_2) - $signed(x0_0)) * $signed(dx_i) + ($signed(y1_2) - $signed(y0_0)) * $signed(dy_i);
                                    end else if (i_reg == 2'd1 && j_reg == 2'd2) begin
                                        n2 = ($signed(x0_2) - $signed(x0_1)) * $signed(dx_i) + ($signed(y0_2) - $signed(y0_1)) * $signed(dy_i);
                                        n3 = ($signed(x1_2) - $signed(x0_1)) * $signed(dx_i) + ($signed(y1_2) - $signed(y0_1)) * $signed(dy_i);
                                    end
                                    
                                    min_n = (n2 < n3) ? n2 : n3;
                                    max_n = (n2 > n3) ? n2 : n3;
                                    
                                    overlap = ($signed(max_n) > 64'd0 && $signed(min_n) < v_dot_i);
                                    
                                    if (overlap) begin
                                        infinite_flag <= 1'b1;
                                    end
                                end
                            end else begin
                                // Compute numerators
                                if (i_reg == 2'd0 && j_reg == 2'd1) begin
                                    t1_num = ($signed(x0_1) - $signed(x0_0)) * $signed(dy_j) - ($signed(y0_1) - $signed(y0_0)) * $signed(dx_j);
                                    t2_num = ($signed(x0_1) - $signed(x0_0)) * $signed(dy_i) - ($signed(y0_1) - $signed(y0_0)) * $signed(dx_i);
                                end else if (i_reg == 2'd0 && j_reg == 2'd2) begin
                                    t1_num = ($signed(x0_2) - $signed(x0_0)) * $signed(dy_j) - ($signed(y0_2) - $signed(y0_0)) * $signed(dx_j);
                                    t2_num = ($signed(x0_2) - $signed(x0_0)) * $signed(dy_i) - ($signed(y0_2) - $signed(y0_0)) * $signed(dx_i);
                                end else if (i_reg == 2'd1 && j_reg == 2'd2) begin
                                    t1_num = ($signed(x0_2) - $signed(x0_1)) * $signed(dy_j) - ($signed(y0_2) - $signed(y0_1)) * $signed(dx_j);
                                    t2_num = ($signed(x0_2) - $signed(x0_1)) * $signed(dy_i) - ($signed(y0_2) - $signed(y0_1)) * $signed(dx_i);
                                end
                                
                                // Check if t1 and t2 are in [0,1]
                                reg t1_valid, t2_valid;
                                
                                if (D_val > 64'd0) begin
                                    t1_valid = (t1_num >= 64'd0) && (t1_num <= D_val);
                                    t2_valid = (t2_num >= 64'd0) && (t2_num <= D_val);
                                end else begin
                                    t1_valid = (t1_num <= 64'd0) && (t1_num >= D_val);
                                    t2_valid = (t2_num <= 64'd0) && (t2_num >= D_val);
                                end
                                
                                if (t1_valid && t2_valid) begin
                                    // Store intersection point
                                    if (i_reg == 2'd0) begin
                                        x_num[point_count] = $signed(x0_0) * D_val + t1_num * $signed(dx_i);
                                        y_num[point_count] = $signed(y0_0) * D_val + t1_num * $signed(dy_i);
                                    end else if (i_reg == 2'd1) begin
                                        x_num[point_count] = $signed(x0_1) * D_val + t1_num * $signed(dx_i);
                                        y_num[point_count] = $signed(y0_1) * D_val + t1_num * $signed(dy_i);
                                    end else begin // i_reg == 2'd2
                                        x_num[point_count] = $signed(x0_2) * D_val + t1_num * $signed(dx_i);
                                        y_num[point_count] = $signed(y0_2) * D_val + t1_num * $signed(dy_i);
                                    end
                                    D[point_count] = D_val;
                                    point_count <= point_count + 3'd1;
                                end
                            end
                        end
                        
                        // Move to next pair
                        if (j_reg == 2'd2) begin
                            i_reg <= i_reg + 2'd1;
                            j_reg <= i_reg + 2'd1;
                        end else begin
                            j_reg <= j_reg + 2'd1;
                        end
                    end
                    
                    // Safety check for cycle count
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end
                
                DEDUPLICATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all pairs
                    if (dup_i == point_count && dup_j == point_count) begin
                        count <= unique_count;
                        next_state <= FINISH;
                    end else begin
                        reg duplicate;
                        duplicate = 1'b0;
                        
                        // Check if current point (dup_j) is equal to any previous point (dup_i)
                        if (dup_j > dup_i) begin
                            if (x_num[dup_i] * D[dup_j] == x_num[dup_j] * D[dup_i] &&
                                y_num[dup_i] * D[dup_j] == y_num[dup_j] * D[dup_i]) begin
                                duplicate = 1'b1;
                            end
                        end
                        
                        // Move to next comparison
                        if (dup_j == point_count) begin
                            dup_i <= dup_i + 3'd1;
                            dup_j <= 2'd0;
                        end else begin
                            dup_j <= dup_j + 3'd1;
                        end
                        
                        // If not duplicate and we've checked all previous points, increment unique count
                        if (!duplicate && dup_j == point_count && dup_i == point_count) begin
                            unique_count <= unique_count + 3'd1;
                        end
                    end
                    
                    // Safety check for cycle count
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule