module expected_area(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [3:0] k,
    input [15:0] x0, y0,
    input [15:0] x1, y1,
    input [15:0] x2, y2,
    input [15:0] x3, y3,
    input [15:0] x4, y4,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam CALC_TRIANGLES = 3'b001;
    localparam ACCUMULATE = 3'b010;
    localparam DIVIDE = 3'b011;
    localparam DONE = 3'b100;

    // Registers for state and control
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Vertex storage (combinational inputs stored in registers for pipeline)
    reg [15:0] v_x [0:4];
    reg [15:0] v_y [0:4];
    
    // Combination counter
    reg [3:0] combo_idx;
    reg [3:0] i_idx, j_idx, l_idx;
    
    // Accumulator for sum of areas
    reg signed [47:0] area_sum;
    reg signed [47:0] next_area_sum;
    
    // Multiplier registers
    reg signed [31:0] op1, op2;
    wire signed [63:0] mul_result;
    
    // Intermediate calculation registers
    reg signed [63:0] cross_sum;
    reg signed [63:0] next_cross_sum;
    reg signed [31:0] area_temp;
    reg signed [31:0] next_area_temp;
    
    // Division registers
    reg signed [63:0] dividend;
    reg signed [63:0] div_quotient;
    reg signed [63:0] next_div_quotient;
    reg [5:0] div_count;
    reg [5:0] next_div_count;
    
    // Division state machine
    reg div_done;
    reg div_start;
    
    // Multiplication (combinational) - Q16.16 * Q16.16 = Q32.32, truncate to Q32.32
    // Using 32x32 signed multiplication resulting in 64 bits
    assign mul_result = op1 * op2;
    
    // Vertex indexing logic
    always @(*) begin
        case(i_idx)
            4'd0: begin v_x[0] = x0; v_y[0] = y0; end
            4'd1: begin v_x[1] = x1; v_y[1] = y1; end
            4'd2: begin v_x[2] = x2; v_y[2] = y2; end
            4'd3: begin v_x[3] = x3; v_y[3] = y3; end
            4'd4: begin v_x[4] = x4; v_y[4] = y4; end
        endcase
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case(state)
            IDLE: begin
                if (start && n <= 5 && k == 3) next_state = CALC_TRIANGLES;
            end
            CALC_TRIANGLES: begin
                if (combo_idx < 10) next_state = ACCUMULATE;
                else next_state = DIVIDE;
            end
            ACCUMULATE: begin
                next_state = CALC_TRIANGLES;
            end
            DIVIDE: begin
                if (div_done) next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Combination counter logic
    always @(*) begin
        case(combo_idx)
            4'd0: begin i_idx = 0; j_idx = 1; l_idx = 2; end
            4'd1: begin i_idx = 0; j_idx = 1; l_idx = 3; end
            4'd2: begin i_idx = 0; j_idx = 1; l_idx = 4; end
            4'd3: begin i_idx = 0; j_idx = 2; l_idx = 3; end
            4'd4: begin i_idx = 0; j_idx = 2; l_idx = 4; end
            4'd5: begin i_idx = 0; j_idx = 3; l_idx = 4; end
            4'd6: begin i_idx = 1; j_idx = 2; l_idx = 3; end
            4'd7: begin i_idx = 1; j_idx = 2; l_idx = 4; end
            4'd8: begin i_idx = 1; j_idx = 3; l_idx = 4; end
            4'd9: begin i_idx = 2; j_idx = 3; l_idx = 4; end
            default: begin i_idx = 0; j_idx = 0; l_idx = 0; end
        endcase
    end

    // Area calculation and accumulation
    always @(*) begin
        // Default assignments
        next_cross_sum = cross_sum;
        next_area_temp = area_temp;
        next_area_sum = area_sum;
        next_div_quotient = div_quotient;
        next_div_count = div_count;
        div_start = 1'b0;
        div_done = 1'b0;
        
        case(state)
            IDLE: begin
                next_cross_sum = 0;
                next_area_temp = 0;
                next_area_sum = 0;
                next_div_quotient = 0;
                next_div_count = 0;
            end
            
            CALC_TRIANGLES: begin
                // Calculate cross products for shoelace
                // x_i*y_j + x_j*y_l + x_l*y_i - x_j*y_i - x_l*y_j - x_i*y_l
                // We'll compute this in ACCUMULATE state to use pipelining
            end
            
            ACCUMULATE: begin
                // Use stored vertex values (combinational from case statement above)
                // However, since we need registers, we need to access them properly
                // Since vertex selection is combinational, we need to re-read
                // This is a limitation - let's use direct indexing
                
                // Compute: x_i*y_j
                // We need to handle the actual vertex values here
                // For synthesis, we'll use a combinational block that evaluates
                // the current indices against the inputs
                
                // Actually, let's compute step by step
                // To avoid complex combinational logic, we'll do it in stages
                // But for simplicity in this single always block, we compute full result
                
                // Since we can't use arrays in combinational logic easily here,
                // we'll compute based on combo_idx directly
                
                // Compute signed area: |cross| / 2
                // Cross product terms:
                // This requires reading x0..x4 based on i,j,l
                // We'll use separate combinational logic for vertex selection
                
                // For now, assume we can compute here
                // x_i*y_j term
                // Let's compute: (x_i * y_j) + (x_j * y_l) + (x_l * y_i) - ...
                // This needs 3 multiplies, then adds/subtracts
                
                // Area sum accumulation
                // Area_temp holds the signed area from previous cycle
                next_area_sum = area_sum + {{16{area_temp[31]}}, area_temp};
            end
            
            DIVIDE: begin
                // Divide by 10 using iterative subtraction
                // Multiply by 0.1 (0x1999 in Q16.16) instead
                // But we need to handle the division properly
                
                if (div_count < 6'd32) begin
                    // Use long division or multiplication
                    // Let's use multiplication by reciprocal
                    // Reciprocal of 10 in Q16.16 = 6553.6 = 0x1999.999A, approx 0x199A
                    // Or use shift and add: divide by 10 = (divide by 8) - (divide by 40)
                    // area_sum / 10 = area_sum * 0.1
                    // 0.1 in Q32.32 = 0x19999999
                    
                    // Start multiplication of area_sum * 0x19999999
                    // Actually, let's use iterative subtraction for exact division
                    // Since we're in Q16.16, divide by 10 means shift right 3 bits then adjust
                    
                    // Let's use simple iterative division
                    if (div_count == 0) begin
                        div_start = 1'b1;
                        next_div_quotient = area_sum >>> 3; // Approximate
                        next_div_count = 1;
                    end else begin
                        // Refine: quotient = (area_sum / 10)
                        // Using multiplication by 0x1999 (Q16.16) on upper 32 bits
                        next_div_count = div_count + 1;
                        if (div_count == 31) div_done = 1'b1;
                    end
                end else begin
                    div_done = 1'b1;
                end
            end
            
            DONE: begin
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            combo_idx <= 0;
            area_sum <= 0;
            cross_sum <= 0;
            area_temp <= 0;
            div_quotient <= 0;
            div_count <= 0;
            result <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            area_sum <= next_area_sum;
            cross_sum <= next_cross_sum;
            area_temp <= next_area_temp;
            div_quotient <= next_div_quotient;
            div_count <= next_div_count;
            
            case(state)
                IDLE: begin
                    if (start) combo_idx <= 0;
                    done <= 0;
                end
                
                CALC_TRIANGLES: begin
                    // Setup multiplication for cross products
                    // We'll compute one triangle per cycle, using pipelined multipliers
                    // Triangle: i,j,l based on combo_idx
                    
                    // We need to get the actual vertex coordinates
                    // Since this is combinational per index, we need helper logic
                    // Let's do it directly here with case statements
                    
                    case(combo_idx)
                        4'd0: begin // (0,1,2)
                            op1 <= x0; op2 <= y1; // x0*y1
                        end
                        4'd1: begin // (0,1,3)
                            op1 <= x0; op2 <= y1;
                        end
                        4'd2: begin // (0,1,4)
                            op1 <= x0; op2 <= y1;
                        end
                        4'd3: begin // (0,2,3)
                            op1 <= x0; op2 <= y2;
                        end
                        4'd4: begin // (0,2,4)
                            op1 <= x0; op2 <= y2;
                        end
                        4'd5: begin // (0,3,4)
                            op1 <= x0; op2 <= y3;
                        end
                        4'd6: begin // (1,2,3)
                            op1 <= x1; op2 <= y2;
                        end
                        4'd7: begin // (1,2,4)
                            op1 <= x1; op2 <= y2;
                        end
                        4'd8: begin // (1,3,4)
                            op1 <= x1; op2 <= y3;
                        end
                        4'd9: begin // (2,3,4)
                            op1 <= x2; op2 <= y3;
                        end
                    endcase
                end
                
                ACCUMULATE: begin
                    // Compute full shoelace for current triangle
                    // This requires multiple stages, so we'll accumulate step by step
                    // For single cycle per triangle, we need combinational logic
                    
                    // Let's compute the triangle area directly using combinational logic
                    // We'll use the multiplier mul_result which gives 64-bit result
                    // The calculation needs 3 multiplies and adds
                    
                    // For this implementation, we compute area in ACCUMULATE state
                    // using the previously computed product from CALC_TRIANGLES
                    // Then add to sum
                    
                    // Actually, to make it work in single cycle per triangle,
                    // we need to compute the full area. Let's use a separate combinational
                    // area computation block.
                    
                    // Since the multiplier is combinational, we can compute:
                    // cross = (x_i*y_j + x_j*y_l + x_l*y_i) - (x_j*y_i + x_l*y_j + x_i*y_l)
                    
                    // We'll compute this using the mul_result from current op1/op2
                    // and additional products in the next cycle
                    
                    // For now, let's accumulate the partial product
                    // This is getting complex for a single cycle
                    // Let's use a simpler approach: 3 cycles per triangle
                    
                    // Actually, let's implement it properly:
                    // Cycle 1: Compute x_i*y_j and store in cross_sum[63:32]
                    // But we need 3 products. 
                    // Let's use cross_sum as accumulator for the signed sum
                    
                    // We'll do a simplified accumulation:
                    // cross_sum accumulates the signed shoelace sum
                    // But we need to handle 3 products per triangle
                    
                    // Let's restart the approach for ACCUMULATE:
                    // Use the multiplier to compute products one by one
                    // cross_sum stores intermediate sum
                    
                    if (combo_idx < 10) begin
                        // Get current vertex indices
                        // Compute term by term
                        // We'll use cross_sum to store the running total for this triangle
                        // And area_temp to store final area
                        
                        // For correct implementation, we need to know what phase we're in
                        // Since this is a complex state, let's use a phase counter
                        // But to keep it simple, we'll do it differently
                        
                        // Let's use the fact that we're in CALC_TRIANGLES->ACCUMULATE
                        // We'll compute the area of one triangle in these two states
                        // using the multiplier which is available
                        
                        // Actually, let's make CALC_TRIANGLES compute all 3 products
                        // by iterating through phases
                    end
                end
            endcase
        end
    end

    // Revised implementation using a cleaner approach
    // We'll compute areas using a small FSM per triangle
    reg [1:0] tri_phase;
    reg signed [63:0] tri_sum;
    reg [3:0] current_i, current_j, current_l;
    
    // Wire up current vertices
    wire [15:0] curr_xi, curr_yi, curr_xj, curr_yj, curr_xl, curr_yl;
    
    assign curr_xi = (current_i == 0) ? x0 : (current_i == 1) ? x1 : (current_i == 2) ? x2 : (current_i == 3) ? x3 : x4;
    assign curr_yi = (current_i == 0) ? y0 : (current_i == 1) ? y1 : (current_i == 2) ? y2 : (current_i == 3) ? y3 : y4;
    assign curr_xj = (current_j == 0) ? x0 : (current_j == 1) ? x1 : (current_j == 2) ? x2 : (current_j == 3) ? x3 : x4;
    assign curr_yj = (current_j == 0) ? y0 : (current_j == 1) ? y1 : (current_j == 2) ? y2 : (current_j == 3) ? y3 : y4;
    assign curr_xl = (current_l == 0) ? x0 : (current_l == 1) ? x1 : (current_l == 2) ? x2 : (current_l == 3) ? x3 : x4;
    assign curr_yl = (current_l == 0) ? y0 : (current_l == 1) ? y1 : (current_l == 2) ? y2 : (current_l == 3) ? y3 : y4;

    // Main state machine with proper pipeline
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            combo_idx <= 0;
            area_sum <= 0;
            result <= 0;
            done <= 0;
            tri_phase <= 0;
            tri_sum <= 0;
            current_i <= 0;
            current_j <= 0;
            current_l <= 0;
            div_count <= 0;
        end else begin
            case(state)
                IDLE: begin
                    done <= 0;
                    if (start && k == 3) begin
                        state <= CALC_TRIANGLES;
                        combo_idx <= 0;
                        area_sum <= 0;
                        tri_phase <= 0;
                        // Load first combination
                        current_i <= 0; current_j <= 1; current_l <= 2;
                    end
                end
                
                CALC_TRIANGLES: begin
                    // Compute cross product terms for current triangle
                    // This state handles the multi-cycle computation of one triangle area
                    case(tri_phase)
                        2'b00: begin
                            // Start x_i * y_j
                            op1 <= curr_xi;
                            op2 <= curr_yj;
                            tri_sum <= 0;
                            tri_phase <= 2'b01;
                        end
                        2'b01: begin
                            // x_i * y_j computed, accumulate: + x_i*y_j
                            // Also start x_j * y_l
                            tri_sum <= tri_sum + mul_result[47:16]; // Take upper 32 bits, shift Q32.32 to Q16.16
                            op1 <= curr_xj;
                            op2 <= curr_yl;
                            tri_phase <= 2'b10;
                        end
                        2'b10: begin
                            // x_j * y_l computed, accumulate: + x_j*y_l
                            // Also start x_l * y_i
                            tri_sum <= tri_sum + mul_result[47:16];
                            op1 <= curr_xl;
                            op2 <= curr_yi;
                            tri_phase <= 2'b11;
                        end
                        2'b11: begin
                            // x_l * y_i computed, accumulate: + x_l*y_i
                            // Now need to subtract the other terms
                            tri_sum <= tri_sum + mul_result[47:16];
                            // Start subtracting: - x_j*y_i
                            op1 <= curr_xj;
                            op2 <= curr_yi;
                            tri_phase <= 2'b00; // Will change state
                            // We need another state for subtraction, let's use a helper state
                        end
                    endcase
                end
                
                ACCUMULATE: begin
                    // Continue subtraction terms and finalize area
                    case(tri_phase)
                        2'b00: begin
                            // Subtract x_j*y_i (computed in CALC_TRIANGLES last cycle)
                            // Actually, mul_result is from the previous op1/op2 which was x_j*y_i
                            tri_sum <= tri_sum - mul_result[47:16];
                            op1 <= curr_xl;
                            op2 <= curr_yj;
                            tri_phase <= 2'b01;
                        end
                        2'b01: begin
                            // Subtract x_l*y_j
                            tri_sum <= tri_sum - mul_result[47:16];
                            op1 <= curr_xi;
                            op2 <= curr_yl;
                            tri_phase <= 2'b10;
                        end
                        2'b10: begin
                            // Subtract x_i*y_l
                            tri_sum <= tri_sum - mul_result[47:16];
                            tri_phase <= 2'b11;
                        end
                        2'b11: begin
                            // Finalize: take absolute value and divide by 2
                            // tri_sum now has the signed shoelace sum in Q16.16 (or Q20.12 approx)
                            // Area = |cross_sum| / 2
                            if (tri_sum[63]) begin
                                tri_sum <= -tri_sum;
                            end
                            // Divide by 2 (shift right 1)
                            // But we need to handle the fractional part correctly
                            // In Q16.16, divide by 2 = right shift 1 bit
                            tri_sum <= tri_sum >>> 1;
                            tri_phase <= 2'b00;
                            // Add to accumulator
                            area_sum <= area_sum + tri_sum[63:16]; // Extract Q16.16 part
                            
                            // Move to next triangle
                            if (combo_idx < 10) begin
                                combo_idx <= combo_idx + 1;
                                state <= CALC_TRIANGLES;
                                // Load next combination
                                case(combo_idx + 1)
                                    4'd0: begin current_i <= 0; current_j <= 1; current_l <= 2; end
                                    4'd1: begin current_i <= 0; current_j <= 1; current_l <= 3; end
                                    4'd2: begin current_i <= 0; current_j <= 1; current_l <= 4; end
                                    4'd3: begin current_i <= 0; current_j <= 2; current_l <= 3; end
                                    4'd4: begin current_i <= 0; current_j <= 2; current_l <= 4; end
                                    4'd5: begin current_i <= 0; current_j <= 3; current_l <= 4; end
                                    4'd6: begin current_i <= 1; current_j <= 2; current_l <= 3; end
                                    4'd7: begin current_i <= 1; current_j <= 2; current_l <= 4; end
                                    4'd8: begin current_i <= 1; current_j <= 3; current_l <= 4; end
                                    4'd9: begin current_i <= 2; current_j <= 3; current_l <= 4; end
                                endcase
                            end else begin
                                state <= DIVIDE;
                                div_count <= 0;
                                // Initialize division: multiply by 0.1 (0x1999 in Q16.16)
                                // Or use area_sum * 0x1999 then right shift 16
                                // Let's use the multiplier
                                op1 <= area_sum[47:16]; // Upper 32 bits (Q16.16 part)
                                op2 <= 16'h1999; // 1/10 in Q16.16 = 6553.6 ≈ 0x1999
                            end
                        end
                    endcase
                end
                
                DIVIDE: begin
                    // Result of multiplication is in mul_result
                    // area * 1/10 = area * 0x1999 >> 16
                    // mul_result is Q32.32, we want Q16.16
                    // result = mul_result[47:16] gives us Q16.16
                    result <= mul_result[47:16];
                    state <= DONE;
                    done <= 1'b1;
                end
                
                DONE: begin
                    done <= 1'b0;
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end

endmodule

// Helper module for vertex selection (optional)
// Not needed as we used inline selection
