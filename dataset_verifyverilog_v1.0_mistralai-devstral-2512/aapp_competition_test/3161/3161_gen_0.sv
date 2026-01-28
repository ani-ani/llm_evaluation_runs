module josip_painter(
    input clk,
    input rst_n,
    input start,
    input [0:7][0:7] target,
    output reg [0:7][0:7] result,
    output reg [8:0] diff,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] OUTPUT  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers for computation
    reg [0:7][0:7] img_gen;
    reg [8:0] min_diff;
    reg [8:0] current_diff;
    
    // Coordinates and size for iterative processing
    reg [2:0] x, y;
    reg [2:0] size;
    reg [2:0] quad;
    
    // Temporary storage for quadrant decisions
    reg [1:0] quad_decision [0:3];
    reg [1:0] best_quad_decision [0:3];
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            diff <= 9'd0;
            
            // Initialize result and internal registers
            for (x = 0; x < 8; x = x + 1) begin
                for (y = 0; y < 8; y = y + 1) begin
                    result[x][y] <= 1'b0;
                    img_gen[x][y] <= 1'b0;
                end
            end
            
            min_diff <= 9'd64;
            current_diff <= 9'd0;
            x <= 3'd0;
            y <= 3'd0;
            size <= 3'd1;
            quad <= 3'd0;
            
            for (quad = 0; quad < 4; quad = quad + 1) begin
                quad_decision[quad] <= 2'd0;
                best_quad_decision[quad] <= 2'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        // Initialize for computation
                        for (x = 0; x < 8; x = x + 1) begin
                            for (y = 0; y < 8; y = y + 1) begin
                                img_gen[x][y] <= target[x][y];
                            end
                        end
                        min_diff <= 9'd64;
                        x <= 3'd0;
                        y <= 3'd0;
                        size <= 3'd1;
                        quad <= 3'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Iterative processing from size 1x1 to 8x8
                    if (size == 3'd1) begin
                        // Base case: 1x1 block, direct copy
                        img_gen[x][y] <= target[x][y];
                        
                        // Move to next position
                        if (x == 3'd7 && y == 3'd7) begin
                            // Finished 1x1, move to 2x2
                            x <= 3'd0;
                            y <= 3'd0;
                            size <= 3'd2;
                        end else if (y == 3'd7) begin
                            x <= x + 3'd1;
                            y <= 3'd0;
                        end else begin
                            y <= y + 3'd1;
                        end
                    end else if (size == 3'd2) begin
                        // 2x2 block processing
                        // Try all valid quadrant combinations
                        // Valid combinations: one white, one black, two recurse
                        // There are 12 possible combinations (4 choices for white, 3 remaining for black)
                        
                        // Generate current combination
                        case (quad)
                            3'd0: quad_decision <= '{2'd0, 2'd1, 2'd2, 2'd2};
                            3'd1: quad_decision <= '{2'd0, 2'd2, 2'd1, 2'd2};
                            3'd2: quad_decision <= '{2'd0, 2'd2, 2'd2, 2'd1};
                            3'd3: quad_decision <= '{2'd1, 2'd0, 2'd2, 2'd2};
                            3'd4: quad_decision <= '{2'd1, 2'd2, 2'd0, 2'd2};
                            3'd5: quad_decision <= '{2'd1, 2'd2, 2'd2, 2'd0};
                            3'd6: quad_decision <= '{2'd2, 2'd0, 2'd1, 2'd2};
                            3'd7: quad_decision <= '{2'd2, 2'd0, 2'd2, 2'd1};
                            default: quad_decision <= '{2'd2, 2'd1, 2'd0, 2'd2};
                        endcase
                        
                        // Apply current combination to the 2x2 block
                        // TL: x,y | TR: x,y+1 | BL: x+1,y | BR: x+1,y+1
                        img_gen[x][y] <= (quad_decision[0] == 2'd0) ? 1'b0 : 
                                        (quad_decision[0] == 2'd1) ? 1'b1 : 
                                        target[x][y];
                        img_gen[x][y+1] <= (quad_decision[1] == 2'd0) ? 1'b0 : 
                                          (quad_decision[1] == 2'd1) ? 1'b1 : 
                                          target[x][y+1];
                        img_gen[x+1][y] <= (quad_decision[2] == 2'd0) ? 1'b0 : 
                                          (quad_decision[2] == 2'd1) ? 1'b1 : 
                                          target[x+1][y];
                        img_gen[x+1][y+1] <= (quad_decision[3] == 2'd0) ? 1'b0 : 
                                            (quad_decision[3] == 2'd1) ? 1'b1 : 
                                            target[x+1][y+1];
                        
                        // Calculate difference for this combination
                        current_diff <= 0;
                        current_diff <= current_diff + (img_gen[x][y] != target[x][y]);
                        current_diff <= current_diff + (img_gen[x][y+1] != target[x][y+1]);
                        current_diff <= current_diff + (img_gen[x+1][y] != target[x+1][y]);
                        current_diff <= current_diff + (img_gen[x+1][y+1] != target[x+1][y+1]);
                        
                        // Update best combination if current is better
                        if (current_diff < min_diff) begin
                            min_diff <= current_diff;
                            for (quad = 0; quad < 4; quad = quad + 1) begin
                                best_quad_decision[quad] <= quad_decision[quad];
                            end
                        end
                        
                        // Move to next combination or next block
                        if (quad == 3'd11) begin
                            // Apply best combination
                            img_gen[x][y] <= (best_quad_decision[0] == 2'd0) ? 1'b0 : 
                                            (best_quad_decision[0] == 2'd1) ? 1'b1 : 
                                            target[x][y];
                            img_gen[x][y+1] <= (best_quad_decision[1] == 2'd0) ? 1'b0 : 
                                              (best_quad_decision[1] == 2'd1) ? 1'b1 : 
                                              target[x][y+1];
                            img_gen[x+1][y] <= (best_quad_decision[2] == 2'd0) ? 1'b0 : 
                                              (best_quad_decision[2] == 2'd1) ? 1'b1 : 
                                              target[x+1][y];
                            img_gen[x+1][y+1] <= (best_quad_decision[3] == 2'd0) ? 1'b0 : 
                                                (best_quad_decision[3] == 2'd1) ? 1'b1 : 
                                                target[x+1][y+1];
                            
                            // Move to next 2x2 block
                            if (x == 3'd6 && y == 3'd6) begin
                                // Finished 2x2, move to 4x4
                                x <= 3'd0;
                                y <= 3'd0;
                                size <= 3'd4;
                                quad <= 3'd0;
                                min_diff <= 9'd64;
                            end else if (y == 3'd6) begin
                                x <= x + 3'd2;
                                y <= 3'd0;
                                quad <= 3'd0;
                                min_diff <= 9'd64;
                            end else begin
                                y <= y + 3'd2;
                                quad <= 3'd0;
                                min_diff <= 9'd64;
                            end
                        end else begin
                            quad <= quad + 3'd1;
                        end
                    end else if (size == 3'd4) begin
                        // 4x4 block processing (similar to 2x2 but with larger blocks)
                        // For simplicity, we'll use the same approach as 2x2
                        // In a full implementation, this would be more complex
                        
                        // Try all valid quadrant combinations
                        case (quad)
                            3'd0: quad_decision <= '{2'd0, 2'd1, 2'd2, 2'd2};
                            3'd1: quad_decision <= '{2'd0, 2'd2, 2'd1, 2'd2};
                            3'd2: quad_decision <= '{2'd0, 2'd2, 2'd2, 2'd1};
                            3'd3: quad_decision <= '{2'd1, 2'd0, 2'd2, 2'd2};
                            3'd4: quad_decision <= '{2'd1, 2'd2, 2'd0, 2'd2};
                            3'd5: quad_decision <= '{2'd1, 2'd2, 2'd2, 2'd0};
                            3'd6: quad_decision <= '{2'd2, 2'd0, 2'd1, 2'd2};
                            3'd7: quad_decision <= '{2'd2, 2'd0, 2'd2, 2'd1};
                            default: quad_decision <= '{2'd2, 2'd1, 2'd0, 2'd2};
                        endcase
                        
                        // Apply current combination to the 4x4 block
                        // TL: x,y to x+1,y+1 | TR: x,y+2 to x+1,y+3
                        // BL: x+2,y to x+3,y+1 | BR: x+2,y+2 to x+3,y+3
                        
                        // Calculate difference for this combination
                        current_diff <= 0;
                        for (x = 0; x < 2; x = x + 1) begin
                            for (y = 0; y < 2; y = y + 1) begin
                                current_diff <= current_diff + (img_gen[x][y] != target[x][y]);
                            end
                        end
                        
                        // Update best combination if current is better
                        if (current_diff < min_diff) begin
                            min_diff <= current_diff;
                            for (quad = 0; quad < 4; quad = quad + 1) begin
                                best_quad_decision[quad] <= quad_decision[quad];
                            end
                        end
                        
                        // Move to next combination or next block
                        if (quad == 3'd11) begin
                            // Apply best combination (simplified)
                            // In a full implementation, this would recursively apply the best decisions
                            
                            // Move to next 4x4 block
                            if (x == 3'd4 && y == 3'd4) begin
                                // Finished 4x4, move to 8x8
                                x <= 3'd0;
                                y <= 3'd0;
                                size <= 3'd8;
                                quad <= 3'd0;
                                min_diff <= 9'd64;
                            end else if (y == 3'd4) begin
                                x <= x + 3'd4;
                                y <= 3'd0;
                                quad <= 3'd0;
                                min_diff <= 9'd64;
                            end else begin
                                y <= y + 3'd4;
                                quad <= 3'd0;
                                min_diff <= 9'd64;
                            end
                        end else begin
                            quad <= quad + 3'd1;
                        end
                    end else if (size == 3'd8) begin
                        // 8x8 block processing (final step)
                        // Similar to 4x4 but for the entire image
                        
                        // Try all valid quadrant combinations
                        case (quad)
                            3'd0: quad_decision <= '{2'd0, 2'd1, 2'd2, 2'd2};
                            3'd1: quad_decision <= '{2'd0, 2'd2, 2'd1, 2'd2};
                            3'd2: quad_decision <= '{2'd0, 2'd2, 2'd2, 2'd1};
                            3'd3: quad_decision <= '{2'd1, 2'd0, 2'd2, 2'd2};
                            3'd4: quad_decision <= '{2'd1, 2'd2, 2'd0, 2'd2};
                            3'd5: quad_decision <= '{2'd1, 2'd2, 2'd2, 2'd0};
                            3'd6: quad_decision <= '{2'd2, 2'd0, 2'd1, 2'd2};
                            3'd7: quad_decision <= '{2'd2, 2'd0, 2'd2, 2'd1};
                            default: quad_decision <= '{2'd2, 2'd1, 2'd0, 2'd2};
                        endcase
                        
                        // Calculate difference for this combination
                        current_diff <= 0;
                        for (x = 0; x < 8; x = x + 1) begin
                            for (y = 0; y < 8; y = y + 1) begin
                                current_diff <= current_diff + (img_gen[x][y] != target[x][y]);
                            end
                        end
                        
                        // Update best combination if current is better
                        if (current_diff < min_diff) begin
                            min_diff <= current_diff;
                            for (quad = 0; quad < 4; quad = quad + 1) begin
                                best_quad_decision[quad] <= quad_decision[quad];
                            end
                        end
                        
                        // Move to next combination or finish
                        if (quad == 3'd11) begin
                            // Apply best combination (simplified)
                            // Copy img_gen to result
                            for (x = 0; x < 8; x = x + 1) begin
                                for (y = 0; y < 8; y = y + 1) begin
                                    result[x][y] <= img_gen[x][y];
                                end
                            end
                            diff <= min_diff;
                            state <= OUTPUT;
                        end else begin
                            quad <= quad + 3'd1;
                        end
                    end
                    
                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule