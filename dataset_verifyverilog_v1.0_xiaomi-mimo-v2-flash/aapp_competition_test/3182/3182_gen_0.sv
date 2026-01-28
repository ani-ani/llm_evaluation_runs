module right_triangle_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] points_x [0:15],
    input wire [7:0] points_y [0:15],
    input wire [4:0] num_points,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SETUP    = 3'd1;
    localparam [2:0] LOAD_I   = 3'd2;
    localparam [2:0] LOAD_J   = 3'd3;
    localparam [2:0] CHECK_K  = 3'd4;
    localparam [2:0] FINISH   = 3'd5;

    // State registers
    reg [2:0] state, next_state;
    
    // Counter registers
    reg [3:0] i_reg, j_reg, k_reg;
    reg [15:0] result_reg;
    reg done_reg;
    
    // Control flags
    reg [2:0] vertex_idx;  // 0: at i, 1: at j, 2: at k
    reg check_complete;
    reg triangle_found;
    
    // Temporary storage for coordinates
    reg signed [7:0] x_i, y_i;
    reg signed [7:0] x_j, y_j;
    reg signed [7:0] x_k, y_k;
    
    // Arithmetic registers (signed)
    reg signed [15:0] dx1, dy1;  // Vector differences
    reg signed [15:0] dx2, dy2;
    reg signed [31:0] dot_product;  // 32-bit for intermediate product
    
    // Cycle counter for safety
    reg [11:0] cycle_counter;
    localparam [11:0] MAX_CYCLES = 12'd4096;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_reg <= 16'd0;
            done_reg <= 1'b0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            k_reg <= 4'd0;
            vertex_idx <= 3'd0;
            check_complete <= 1'b0;
            triangle_found <= 1'b0;
            cycle_counter <= 12'd0;
            x_i <= 8'sd0; y_i <= 8'sd0;
            x_j <= 8'sd0; y_j <= 8'sd0;
            x_k <= 8'sd0; y_k <= 8'sd0;
            dx1 <= 16'sd0; dy1 <= 16'sd0;
            dx2 <= 16'sd0; dy2 <= 16'sd0;
            dot_product <= 32'sd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done_reg <= 1'b0;
                    result_reg <= 16'd0;
                    cycle_counter <= 12'd0;
                    if (start) begin
                        i_reg <= 4'd0;
                        j_reg <= 4'd1;
                        k_reg <= 4'd2;
                    end
                end
                
                SETUP: begin
                    // Load coordinates for current triplet
                    x_i <= $signed(points_x[i_reg]);
                    y_i <= $signed(points_y[i_reg]);
                    x_j <= $signed(points_x[j_reg]);
                    y_j <= $signed(points_y[j_reg]);
                    x_k <= $signed(points_x[k_reg]);
                    y_k <= $signed(points_y[k_reg]);
                    vertex_idx <= 3'd0;  // Start checking at vertex i
                    check_complete <= 1'b0;
                    triangle_found <= 1'b0;
                    cycle_counter <= cycle_counter + 12'd1;
                end
                
                LOAD_I: begin  // Check right angle at point i
                    if (vertex_idx == 3'd0) begin
                        // (pj-pi) and (pk-pi)
                        dx1 <= {8'd0, x_j} - {8'd0, x_i};  // Sign extension
                        dy1 <= {8'd0, y_j} - {8'd0, y_i};
                        dx2 <= {8'd0, x_k} - {8'd0, x_i};
                        dy2 <= {8'd0, y_k} - {8'd0, y_i};
                        vertex_idx <= 3'd1;
                    end else if (vertex_idx == 3'd1) begin
                        // (pi-pj) and (pk-pj)
                        dx1 <= {8'd0, x_i} - {8'd0, x_j};
                        dy1 <= {8'd0, y_i} - {8'd0, y_j};
                        dx2 <= {8'd0, x_k} - {8'd0, x_j};
                        dy2 <= {8'd0, y_k} - {8'd0, y_j};
                        vertex_idx <= 3'd2;
                    end else begin  // vertex_idx == 3'd2
                        // (pi-pk) and (pj-pk)
                        dx1 <= {8'd0, x_i} - {8'd0, x_k};
                        dy1 <= {8'd0, y_i} - {8'd0, y_k};
                        dx2 <= {8'd0, x_j} - {8'd0, x_k};
                        dy2 <= {8'd0, y_j} - {8'd0, y_k};
                        vertex_idx <= 3'd3;  // Done with this triplet
                    end
                end
                
                LOAD_J: begin
                    // Calculate dot product: dx1*dy2 + dy1*dx2
                    dot_product <= (dx1 * dx2) + (dy1 * dy2);
                end
                
                CHECK_K: begin
                    // Check if dot product is zero
                    if (dot_product == 32'sd0) begin
                        triangle_found <= 1'b1;
                    end
                    
                    if (vertex_idx == 3'd3) begin
                        // Done checking all three vertices
                        if (triangle_found) begin
                            result_reg <= result_reg + 16'd1;
                        end
                        check_complete <= 1'b1;
                    end
                end
                
                FINISH: begin
                    done_reg <= 1'b1;
                    result_reg <= result_reg;  // Hold result
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = SETUP;
            end
            
            SETUP: begin
                if (i_reg < num_points - 3'd2) next_state = LOAD_I;
                else next_state = FINISH;  // No valid triplets
            end
            
            LOAD_I: begin
                next_state = LOAD_J;
            end
            
            LOAD_J: begin
                next_state = CHECK_K;
            end
            
            CHECK_K: begin
                if (check_complete) begin
                    // Move to next k
                    if (k_reg < num_points - 4'd1) begin
                        next_state = SETUP;
                        // Increment k (done in next state)
                    end else begin
                        // k done, move j
                        if (j_reg < num_points - 4'd2) begin
                            next_state = SETUP;
                            // Increment j (done in next state)
                        end else begin
                            // j done, move i
                            if (i_reg < num_points - 4'd3) begin
                                next_state = SETUP;
                                // Increment i (done in next state)
                            end else begin
                                next_state = FINISH;
                            end
                        end
                    end
                end else begin
                    // Check next vertex
                    next_state = LOAD_I;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Handle loop increment logic
        if (state == CHECK_K && check_complete) begin
            if (k_reg < num_points - 4'd1) begin
                // Increment k for next iteration
            end else if (j_reg < num_points - 4'd2) begin
                // Increment j and reset k
            end else if (i_reg < num_points - 4'd3) begin
                // Increment i and reset j,k
            end
        end
    end

    // Counter increment logic (separate combinational block)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            i_reg <= 4'd0;
            j_reg <= 4'd1;
            k_reg <= 4'd2;
        end else if (state == CHECK_K && check_complete) begin
            if (k_reg < num_points - 4'd1) begin
                k_reg <= k_reg + 4'd1;
            end else begin
                k_reg <= i_reg + 4'd2;  // Reset k to j+1 position
                if (j_reg < num_points - 4'd2) begin
                    j_reg <= j_reg + 4'd1;
                end else begin
                    j_reg <= i_reg + 4'd1;  // Reset j to i+1 position
                    if (i_reg < num_points - 4'd3) begin
                        i_reg <= i_reg + 4'd1;
                    end
                end
            end
        end
    end

    // Output assignments
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            result <= result_reg;
            done <= done_reg;
        end
    end

endmodule