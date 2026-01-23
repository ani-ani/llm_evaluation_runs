module triangle_coverage_compare(
    input clk,
    input rst_n,
    input start,
    input [2:0] garry_tri_count,
    input [2:0] jerry_tri_count,
    input [5:0] garry_tri_0_x1, garry_tri_0_y1, garry_tri_0_x2, garry_tri_0_y2, garry_tri_0_x3, garry_tri_0_y3,
    input [5:0] garry_tri_1_x1, garry_tri_1_y1, garry_tri_1_x2, garry_tri_1_y2, garry_tri_1_x3, garry_tri_1_y3,
    input [5:0] garry_tri_2_x1, garry_tri_2_y1, garry_tri_2_x2, garry_tri_2_y2, garry_tri_2_x3, garry_tri_2_y3,
    input [5:0] garry_tri_3_x1, garry_tri_3_y1, garry_tri_3_x2, garry_tri_3_y2, garry_tri_3_x3, garry_tri_3_y3,
    input [5:0] jerry_tri_0_x1, jerry_tri_0_y1, jerry_tri_0_x2, jerry_tri_0_y2, jerry_tri_0_x3, jerry_tri_0_y3,
    input [5:0] jerry_tri_1_x1, jerry_tri_1_y1, jerry_tri_1_x2, jerry_tri_1_y2, jerry_tri_1_x3, jerry_tri_1_y3,
    input [5:0] jerry_tri_2_x1, jerry_tri_2_y1, jerry_tri_2_x2, jerry_tri_2_y2, jerry_tri_2_x3, jerry_tri_2_y3,
    input [5:0] jerry_tri_3_x1, jerry_tri_3_y1, jerry_tri_3_x2, jerry_tri_3_y2, jerry_tri_3_x3, jerry_tri_3_y3,
    output reg same,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam GARRY_PROCESS = 3'b001;
    localparam JERRY_PROCESS = 3'b010;
    localparam COMPARE = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state, next_state;
    reg [5:0] pixel_counter, next_pixel_counter;
    reg [2:0] tri_counter, next_tri_counter;
    reg [63:0] garry_coverage, next_garry_coverage;
    reg [63:0] jerry_coverage, next_jerry_coverage;
    reg next_same, next_done;

    // Triangle registers and wire for current triangle selection
    reg [2:0] curr_tri_idx;
    reg [2:0] curr_x1, curr_y1, curr_x2, curr_y2, curr_x3, curr_y3;
    wire [2:0] px_wire, py_wire;

    // Pixel center calculation
    // px = {pixel_counter[5:3], 1'b1} -> value 1,3,5,7 (3 bits)
    // py = {pixel_counter[2:0], 1'b1} -> value 1,3,5,7 (3 bits)
    assign px_wire = {pixel_counter[5:3], 1'b1};
    assign py_wire = {pixel_counter[2:0], 1'b1};

    // Combinational logic for triangle selection
    always @(*) begin
        case (curr_tri_idx)
            3'd0: begin
                curr_x1 = garry_tri_0_x1[2:0]; curr_y1 = garry_tri_0_y1[2:0];
                curr_x2 = garry_tri_0_x2[2:0]; curr_y2 = garry_tri_0_y2[2:0];
                curr_x3 = garry_tri_0_x3[2:0]; curr_y3 = garry_tri_0_y3[2:0];
            end
            3'd1: begin
                curr_x1 = garry_tri_1_x1[2:0]; curr_y1 = garry_tri_1_y1[2:0];
                curr_x2 = garry_tri_1_x2[2:0]; curr_y2 = garry_tri_1_y2[2:0];
                curr_x3 = garry_tri_1_x3[2:0]; curr_y3 = garry_tri_1_y3[2:0];
            end
            3'd2: begin
                curr_x1 = garry_tri_2_x1[2:0]; curr_y1 = garry_tri_2_y1[2:0];
                curr_x2 = garry_tri_2_x2[2:0]; curr_y2 = garry_tri_2_y2[2:0];
                curr_x3 = garry_tri_2_x3[2:0]; curr_y3 = garry_tri_2_y3[2:0];
            end
            3'd3: begin
                curr_x1 = garry_tri_3_x1[2:0]; curr_y1 = garry_tri_3_y1[2:0];
                curr_x2 = garry_tri_3_x2[2:0]; curr_y2 = garry_tri_3_y2[2:0];
                curr_x3 = garry_tri_3_x3[2:0]; curr_y3 = garry_tri_3_y3[2:0];
            end
            default: begin
                curr_x1 = 3'b0; curr_y1 = 3'b0;
                curr_x2 = 3'b0; curr_y2 = 3'b0;
                curr_x3 = 3'b0; curr_y3 = 3'b0;
            end
        endcase
    end

    // Inside test logic (Barycentric / Cross product)
    // Point P (px, py) is inside triangle A(x1,y1), B(x2,y2), C(x3,y3)
    // if cross(B-A, P-A) >= 0 AND cross(C-B, P-B) >= 0 AND cross(A-C, P-C) >= 0
    // Note: Cross product is 2D: (x2-x1)*(yp-y1) - (y2-y1)*(xp-x1)
    // All inputs are 3-bit integers. Coordinate multiplication fits in 6 bits.
    // We assume vertices are ordered CCW.
    reg is_inside;
    wire signed [6:0] c1, c2, c3;
    wire signed [3:0] px_s, py_s, x1_s, y1_s, x2_s, y2_s, x3_s, y3_s;
    
    assign px_s = {1'b0, px_wire};
    assign py_s = {1'b0, py_wire};
    assign x1_s = {1'b0, curr_x1};
    assign y1_s = {1'b0, curr_y1};
    assign x2_s = {1'b0, curr_x2};
    assign y2_s = {1'b0, curr_y2};
    assign x3_s = {1'b0, curr_x3};
    assign y3_s = {1'b0, curr_y3};

    // Edge 1: B-A * P-A
    assign c1 = (x2_s - x1_s) * (py_s - y1_s) - (y2_s - y1_s) * (px_s - x1_s);
    // Edge 2: C-B * P-B
    assign c2 = (x3_s - x2_s) * (py_s - y2_s) - (y3_s - y2_s) * (px_s - x2_s);
    // Edge 3: A-C * P-C
    assign c3 = (x1_s - x3_s) * (py_s - y3_s) - (y1_s - y3_s) * (px_s - x3_s);

    always @(*) begin
        // Check if all cross products are non-negative (>= 0)
        if (c1[6] == 0 && c2[6] == 0 && c3[6] == 0)
            is_inside = 1'b1;
        else
            is_inside = 1'b0;
    end

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pixel_counter <= 6'd0;
            tri_counter <= 3'd0;
            garry_coverage <= 64'd0;
            jerry_coverage <= 64'd0;
            same <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            pixel_counter <= next_pixel_counter;
            tri_counter <= next_tri_counter;
            garry_coverage <= next_garry_coverage;
            jerry_coverage <= next_jerry_coverage;
            same <= next_same;
            done <= next_done;
        end
    end

    always @(*) begin
        // Default assignments
        next_state = state;
        next_pixel_counter = pixel_counter;
        next_tri_counter = tri_counter;
        next_garry_coverage = garry_coverage;
        next_jerry_coverage = jerry_coverage;
        next_same = same;
        next_done = done;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = GARRY_PROCESS;
                    next_pixel_counter = 6'd0;
                    next_tri_counter = 3'd0;
                    next_garry_coverage = 64'd0;
                    next_jerry_coverage = 64'd0;
                    next_same = 1'b0;
                end
            end

            GARRY_PROCESS: begin
                // Iterate pixels 0-63, triangles 0-(garry_tri_count-1)
                if (pixel_counter < 64) begin
                    if (tri_counter < garry_tri_count) begin
                        // Check if current pixel is covered by current triangle
                        // Tri selection is combinational based on tri_counter
                        if (is_inside) begin
                            next_garry_coverage[pixel_counter] = 1'b1;
                        end
                        // Move to next triangle
                        if (tri_counter == 3'd3) begin // Max 4 triangles (0,1,2,3)
                            next_tri_counter = 3'd0;
                            next_pixel_counter = pixel_counter + 1'b1;
                        end else begin
                            next_tri_counter = tri_counter + 1'b1;
                        end
                    end else begin
                        // No more triangles for this pixel (tri_counter >= count)
                        next_tri_counter = 3'd0;
                        next_pixel_counter = pixel_counter + 1'b1;
                    end
                end else begin
                    // Finished all pixels for Garry
                    if (jerry_tri_count == 0) begin
                        // If Jerry has no triangles, skip his processing
                        next_state = COMPARE;
                    end else begin
                        next_state = JERRY_PROCESS;
                    end
                    next_pixel_counter = 6'd0;
                    next_tri_counter = 3'd0;
                end
            end

            JERRY_PROCESS: begin
                // Logic is identical to GARRY_PROCESS, but using Jerry's count and updating jerry_coverage
                // To reuse combinational logic, we need to swap inputs or use a flag. 
                // However, inputs are separate signals. We need a multiplexer for the curr_tri_idx logic.
                // Re-implementing logic here to select Jerry's inputs for the test logic.
                // Actually, cleaner way: Make the 'Inside Test' block use a selector.
                // But for strict Verilog, we can just duplicate the logic inside JERRY_PROCESS state logic if needed,
                // or modify the curr_tri logic to support Jerry.
                // Let's modify the curr_tri logic to be controlled by a 'load_jerry' signal.
                // Simplification: Recalculate using Jerry inputs explicitly in this state's combinational check?
                // No, reuse. We will modify the always block for curr_x1 etc to check state.
                
                // Since we need to be synthesizable and clean, let's stick to the plan:
                // We need to use the 'curr_x1' etc wires which depend on 'curr_tri_idx'.
                // We need to make 'curr_x1' depend on a 'is_jerry' flag.
                // Let's assume I update the assignment block above to support state.
                // Wait, I can't modify the module structure now. 
                // Let's perform the check inside the combinational logic block for JERRY state.
                // Actually, to be robust, let's define the test logic to be separate.
                
                // Let's assume I use the same 'is_inside' logic but modify the input selection.
                // For the code below, I will perform the test explicitly for Jerry to avoid complex muxing in the header block.
                
                // Jerry's Pixel calculation is same.
                if (pixel_counter < 64) begin
                    if (tri_counter < jerry_tri_count) begin
                        // Manual Jerry Test
                        reg j_is_inside;
                        reg signed [6:0] j_c1, j_c2, j_c3;
                        reg signed [3:0] j_x1, j_y1, j_x2, j_y2, j_x3, j_y3;
                        
                        // Select Jerry Triangle
                        j_x1 = 3'b0; j_y1 = 3'b0; j_x2 = 3'b0; j_y2 = 3'b0; j_x3 = 3'b0; j_y3 = 3'b0;
                        case (tri_counter)
                            3'd0: begin j_x1 = jerry_tri_0_x1[2:0]; j_y1 = jerry_tri_0_y1[2:0]; j_x2 = jerry_tri_0_x2[2:0]; j_y2 = jerry_tri_0_y2[2:0]; j_x3 = jerry_tri_0_x3[2:0]; j_y3 = jerry_tri_0_y3[2:0]; end
                            3'd1: begin j_x1 = jerry_tri_1_x1[2:0]; j_y1 = jerry_tri_1_y1[2:0]; j_x2 = jerry_tri_1_x2[2:0]; j_y2 = jerry_tri_1_y2[2:0]; j_x3 = jerry_tri_1_x3[2:0]; j_y3 = jerry_tri_1_y3[2:0]; end
                            3'd2: begin j_x1 = jerry_tri_2_x1[2:0]; j_y1 = jerry_tri_2_y1[2:0]; j_x2 = jerry_tri_2_x2[2:0]; j_y2 = jerry_tri_2_y2[2:0]; j_x3 = jerry_tri_2_x3[2:0]; j_y3 = jerry_tri_2_y3[2:0]; end
                            3'd3: begin j_x1 = jerry_tri_3_x1[2:0]; j_y1 = jerry_tri_3_y1[2:0]; j_x2 = jerry_tri_3_x2[2:0]; j_y2 = jerry_tri_3_y2[2:0]; j_x3 = jerry_tri_3_x3[2:0]; j_y3 = jerry_tri_3_y3[2:0]; end
                        endcase

                        // Test
                        j_c1 = ( {1'b0, j_x2} - {1'b0, j_x1} ) * ( {1'b0, py_wire} - {1'b0, j_y1} ) - ( {1'b0, j_y2} - {1'b0, j_y1} ) * ( {1'b0, px_wire} - {1'b0, j_x1} );
                        j_c2 = ( {1'b0, j_x3} - {1'b0, j_x2} ) * ( {1'b0, py_wire} - {1'b0, j_y2} ) - ( {1'b0, j_y3} - {1'b0, j_y2} ) * ( {1'b0, px_wire} - {1'b0, j_x2} );
                        j_c3 = ( {1'b0, j_x1} - {1'b0, j_x3} ) * ( {1'b0, py_wire} - {1'b0, j_y3} ) - ( {1'b0, j_y1} - {1'b0, j_y3} ) * ( {1'b0, px_wire} - {1'b0, j_x3} );

                        j_is_inside = (j_c1[6] == 0 && j_c2[6] == 0 && j_c3[6] == 0);

                        if (j_is_inside) begin
                            next_jerry_coverage[pixel_counter] = 1'b1;
                        end
                        
                        if (tri_counter == 3'd3) begin
                            next_tri_counter = 3'd0;
                            next_pixel_counter = pixel_counter + 1'b1;
                        end else begin
                            next_tri_counter = tri_counter + 1'b1;
                        end
                    end else begin
                        next_tri_counter = 3'd0;
                        next_pixel_counter = pixel_counter + 1'b1;
                    end
                end else begin
                    next_state = COMPARE;
                    next_pixel_counter = 6'd0;
                end
            end

            COMPARE: begin
                // Compare bit by bit
                if (garry_coverage == jerry_coverage) begin
                    next_same = 1'b1;
                end else begin
                    next_same = 1'b0;
                end
                next_state = DONE;
            end

            DONE: begin
                next_done = 1'b1;
                // Hold state until reset or start
                if (start) begin // Optional: restart on start
                    next_state = GARRY_PROCESS;
                    next_done = 1'b0;
                    next_pixel_counter = 6'd0;
                    next_tri_counter = 3'd0;
                    next_garry_coverage = 64'd0;
                    next_jerry_coverage = 64'd0;
                    next_same = 1'b0;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Helper logic to select triangle for Garry Process (reusing is_inside wire)
    // Since we handle Jerry explicitly in JERRY_PROCESS state, we just need to ensure
    // curr_x1 etc are correct for GARRY_PROCESS.
    always @(*) begin
        if (state == GARRY_PROCESS) begin
            curr_tri_idx = tri_counter;
        end else begin
            curr_tri_idx = 3'b0; // Default
        end
    end

endmodule
