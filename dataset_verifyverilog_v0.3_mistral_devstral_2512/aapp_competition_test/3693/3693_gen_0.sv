module square_intersection(
    input clk,
    input rst_n,
    input start,
    input [31:0] square1_coords,
    input [31:0] square2_coords,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    // Extract square1 coordinates (axis-aligned)
    reg signed [7:0] s1_x0, s1_y0, s1_x1, s1_y1, s1_x2, s1_y2, s1_x3, s1_y3;
    reg signed [7:0] s1_min_x, s1_max_x, s1_min_y, s1_max_y;

    // Extract square2 coordinates (rotated)
    reg signed [7:0] s2_a0, s2_b0, s2_a1, s2_b1, s2_a2, s2_b2, s2_a3, s2_b3;
    reg signed [7:0] s2_min_u, s2_max_u, s2_min_v, s2_max_v;

    // Intermediate results
    reg signed [15:0] u0, v0, u1, v1, u2, v2, u3, v3;
    reg signed [15:0] temp_u, temp_v;
    reg [3:0] i, j;
    reg check1, check2, check3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize all registers
            s1_x0 <= 8'd0; s1_y0 <= 8'd0;
            s1_x1 <= 8'd0; s1_y1 <= 8'd0;
            s1_x2 <= 8'd0; s1_y2 <= 8'd0;
            s1_x3 <= 8'd0; s1_y3 <= 8'd0;
            s1_min_x <= 8'd0; s1_max_x <= 8'd0;
            s1_min_y <= 8'd0; s1_max_y <= 8'd0;
            
            s2_a0 <= 8'd0; s2_b0 <= 8'd0;
            s2_a1 <= 8'd0; s2_b1 <= 8'd0;
            s2_a2 <= 8'd0; s2_b2 <= 8'd0;
            s2_a3 <= 8'd0; s2_b3 <= 8'd0;
            s2_min_u <= 8'd0; s2_max_u <= 8'd0;
            s2_min_v <= 8'd0; s2_max_v <= 8'd0;
            
            u0 <= 16'd0; v0 <= 16'd0;
            u1 <= 16'd0; v1 <= 16'd0;
            u2 <= 16'd0; v2 <= 16'd0;
            u3 <= 16'd0; v3 <= 16'd0;
            temp_u <= 16'd0; temp_v <= 16'd0;
            i <= 4'd0; j <= 4'd0;
            check1 <= 1'b0; check2 <= 1'b0; check3 <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Step 1: Extract square1 coordinates
                    if (cycle_count == 8'd1) begin
                        s1_x0 <= $signed(square1_coords[7:0]);
                        s1_y0 <= $signed(square1_coords[15:8]);
                        s1_x1 <= $signed(square1_coords[23:16]);
                        s1_y1 <= $signed(square1_coords[31:24]);
                        s1_x2 <= $signed(square1_coords[39:32]);
                        s1_y2 <= $signed(square1_coords[47:40]);
                        s1_x3 <= $signed(square1_coords[55:48]);
                        s1_y3 <= $signed(square1_coords[63:56]);
                    end
                    
                    // Step 2: Compute square1 bounding box
                    if (cycle_count == 8'd2) begin
                        s1_min_x <= s1_x0;
                        s1_max_x <= s1_x0;
                        s1_min_y <= s1_y0;
                        s1_max_y <= s1_y0;
                    end
                    if (cycle_count == 8'd3) begin
                        if (s1_x1 < s1_min_x) s1_min_x <= s1_x1;
                        if (s1_x1 > s1_max_x) s1_max_x <= s1_x1;
                        if (s1_y1 < s1_min_y) s1_min_y <= s1_y1;
                        if (s1_y1 > s1_max_y) s1_max_y <= s1_y1;
                    end
                    if (cycle_count == 8'd4) begin
                        if (s1_x2 < s1_min_x) s1_min_x <= s1_x2;
                        if (s1_x2 > s1_max_x) s1_max_x <= s1_x2;
                        if (s1_y2 < s1_min_y) s1_min_y <= s1_y2;
                        if (s1_y2 > s1_max_y) s1_max_y <= s1_y2;
                    end
                    if (cycle_count == 8'd5) begin
                        if (s1_x3 < s1_min_x) s1_min_x <= s1_x3;
                        if (s1_x3 > s1_max_x) s1_max_x <= s1_x3;
                        if (s1_y3 < s1_min_y) s1_min_y <= s1_y3;
                        if (s1_y3 > s1_max_y) s1_max_y <= s1_y3;
                    end
                    
                    // Step 3: Extract square2 coordinates
                    if (cycle_count == 8'd6) begin
                        s2_a0 <= $signed(square2_coords[7:0]);
                        s2_b0 <= $signed(square2_coords[15:8]);
                        s2_a1 <= $signed(square2_coords[23:16]);
                        s2_b1 <= $signed(square2_coords[31:24]);
                        s2_a2 <= $signed(square2_coords[39:32]);
                        s2_b2 <= $signed(square2_coords[47:40]);
                        s2_a3 <= $signed(square2_coords[55:48]);
                        s2_b3 <= $signed(square2_coords[63:56]);
                    end
                    
                    // Step 4: Transform square2 to UV space
                    if (cycle_count == 8'd7) begin
                        u0 <= $signed(s2_a0) + $signed(s2_b0);
                        v0 <= $signed(s2_a0) - $signed(s2_b0);
                        u1 <= $signed(s2_a1) + $signed(s2_b1);
                        v1 <= $signed(s2_a1) - $signed(s2_b1);
                        u2 <= $signed(s2_a2) + $signed(s2_b2);
                        v2 <= $signed(s2_a2) - $signed(s2_b2);
                        u3 <= $signed(s2_a3) + $signed(s2_b3);
                        v3 <= $signed(s2_a3) - $signed(s2_b3);
                    end
                    
                    // Step 5: Compute square2 UV bounds
                    if (cycle_count == 8'd8) begin
                        s2_min_u <= $signed(u0);
                        s2_max_u <= $signed(u0);
                        s2_min_v <= $signed(v0);
                        s2_max_v <= $signed(v0);
                    end
                    if (cycle_count == 8'd9) begin
                        if (u1 < s2_min_u) s2_min_u <= $signed(u1);
                        if (u1 > s2_max_u) s2_max_u <= $signed(u1);
                        if (v1 < s2_min_v) s2_min_v <= $signed(v1);
                        if (v1 > s2_max_v) s2_max_v <= $signed(v1);
                    end
                    if (cycle_count == 8'd10) begin
                        if (u2 < s2_min_u) s2_min_u <= $signed(u2);
                        if (u2 > s2_max_u) s2_max_u <= $signed(u2);
                        if (v2 < s2_min_v) s2_min_v <= $signed(v2);
                        if (v2 > s2_max_v) s2_max_v <= $signed(v2);
                    end
                    if (cycle_count == 8'd11) begin
                        if (u3 < s2_min_u) s2_min_u <= $signed(u3);
                        if (u3 > s2_max_u) s2_max_u <= $signed(u3);
                        if (v3 < s2_min_v) s2_min_v <= $signed(v3);
                        if (v3 > s2_max_v) s2_max_v <= $signed(v3);
                    end
                    
                    // Step 6: Check if any square1 vertex is inside square2
                    if (cycle_count == 8'd12) begin
                        check1 <= 1'b0;
                        i <= 4'd0;
                    end
                    if (cycle_count == 8'd13) begin
                        temp_u <= $signed(s1_x0) + $signed(s1_y0);
                        temp_v <= $signed(s1_x0) - $signed(s1_y0);
                        if (temp_u >= s2_min_u && temp_u <= s2_max_u && 
                            temp_v >= s2_min_v && temp_v <= s2_max_v) begin
                            check1 <= 1'b1;
                        end
                    end
                    if (cycle_count == 8'd14) begin
                        temp_u <= $signed(s1_x1) + $signed(s1_y1);
                        temp_v <= $signed(s1_x1) - $signed(s1_y1);
                        if (temp_u >= s2_min_u && temp_u <= s2_max_u && 
                            temp_v >= s2_min_v && temp_v <= s2_max_v) begin
                            check1 <= 1'b1;
                        end
                    end
                    if (cycle_count == 8'd15) begin
                        temp_u <= $signed(s1_x2) + $signed(s1_y2);
                        temp_v <= $signed(s1_x2) - $signed(s1_y2);
                        if (temp_u >= s2_min_u && temp_u <= s2_max_u && 
                            temp_v >= s2_min_v && temp_v <= s2_max_v) begin
                            check1 <= 1'b1;
                        end
                    end
                    if (cycle_count == 8'd16) begin
                        temp_u <= $signed(s1_x3) + $signed(s1_y3);
                        temp_v <= $signed(s1_x3) - $signed(s1_y3);
                        if (temp_u >= s2_min_u && temp_u <= s2_max_u && 
                            temp_v >= s2_min_v && temp_v <= s2_max_v) begin
                            check1 <= 1'b1;
                        end
                    end
                    
                    // Step 7: Check if any square2 vertex is inside square1
                    if (cycle_count == 8'd17) begin
                        check2 <= 1'b0;
                        i <= 4'd0;
                    end
                    if (cycle_count == 8'd18) begin
                        if (s2_a0 >= s1_min_x && s2_a0 <= s1_max_x && 
                            s2_b0 >= s1_min_y && s2_b0 <= s1_max_y) begin
                            check2 <= 1'b1;
                        end
                    end
                    if (cycle_count == 8'd19) begin
                        if (s2_a1 >= s1_min_x && s2_a1 <= s1_max_x && 
                            s2_b1 >= s1_min_y && s2_b1 <= s1_max_y) begin
                            check2 <= 1'b1;
                        end
                    end
                    if (cycle_count == 8'd20) begin
                        if (s2_a2 >= s1_min_x && s2_a2 <= s1_max_x && 
                            s2_b2 >= s1_min_y && s2_b2 <= s1_max_y) begin
                            check2 <= 1'b1;
                        end
                    end
                    if (cycle_count == 8'd21) begin
                        if (s2_a3 >= s1_min_x && s2_a3 <= s1_max_x && 
                            s2_b3 >= s1_min_y && s2_b3 <= s1_max_y) begin
                            check2 <= 1'b1;
                        end
                    end
                    
                    // Step 8: Check edge intersections (simplified)
                    if (cycle_count == 8'd22) begin
                        check3 <= 1'b0;
                        // Simple overlap check for demonstration
                        // In a real implementation, this would check all edge pairs
                        if ((s1_max_x >= s2_min_u && s1_min_x <= s2_max_u) &&
                            (s1_max_y >= s2_min_v && s1_min_y <= s2_max_v)) begin
                            check3 <= 1'b1;
                        end
                    end
                    
                    // Final result
                    if (cycle_count == 8'd23) begin
                        result <= check1 || check2 || check3;
                        state <= FINISH;
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES) begin
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