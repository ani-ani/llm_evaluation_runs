module cloud_compare (
    input clk,
    input rst_n,
    input [3:0] n,
    input [3:0] m,
    input garry_triangles [0:7][0:2][0:1],
    input jerry_triangles [0:7][0:2][0:1],
    output reg same,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] RESET_BITMAP = 3'd1;
    localparam [2:0] RASTERIZE_GARRY = 3'd2;
    localparam [2:0] RASTERIZE_JERRY = 3'd3;
    localparam [2:0] COMPARE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Cycle counter to prevent timeout
    reg [13:0] cycle_count;  // 0-16383
    localparam [13:0] MAX_CYCLES = 14'd12000;
    
    // Triangle counter
    reg [3:0] triangle_idx;
    
    // Vertex counter for rasterization
    reg [1:0] vertex_idx;
    
    // Grid coordinates
    reg [3:0] grid_x, grid_y;
    
    // Vertex storage (scaled Q2.4 format)
    reg [6:0] vertex_x [0:2];  // 7-bit signed
    reg [6:0] vertex_y [0:2];
    reg signed [13:0] bary_a, bary_b, bary_c;
    reg signed [6:0] cross1, cross2, cross3;
    
    // Bitmaps (16x16 = 256 bits)
    reg [0:255] garry_bitmap;
    reg [0:255] jerry_bitmap;
    reg [0:255] compare_bitmap;
    reg [7:0] bit_idx;
    reg [7:0] bitmap_word_idx;
    
    // Intermediate signals for barycentric calculation
    reg signed [13:0] dx1, dy1, dx2, dy2, dx3, dy3;
    reg signed [6:0] px, py;
    reg signed [13:0] area, ap1, ap2, ap3;
    reg signed [6:0] vp_x, vp_y;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            same <= 1'b0;
            done <= 1'b0;
            cycle_count <= 14'd0;
            triangle_idx <= 4'd0;
            vertex_idx <= 2'd0;
            grid_x <= 4'd0;
            grid_y <= 4'd0;
            bit_idx <= 8'd0;
            bitmap_word_idx <= 8'd0;
            garry_bitmap <= 256'd0;
            jerry_bitmap <= 256'd0;
            compare_bitmap <= 256'd0;
            vertex_x[0] <= 7'd0;
            vertex_x[1] <= 7'd0;
            vertex_x[2] <= 7'd0;
            vertex_y[0] <= 7'd0;
            vertex_y[1] <= 7'd0;
            vertex_y[2] <= 7'd0;
            bary_a <= 14'd0;
            bary_b <= 14'd0;
            bary_c <= 14'd0;
            cross1 <= 7'd0;
            cross2 <= 7'd0;
            cross3 <= 7'd0;
            dx1 <= 14'd0;
            dy1 <= 14'd0;
            dx2 <= 14'd0;
            dy2 <= 14'd0;
            dx3 <= 14'd0;
            dy3 <= 14'd0;
            px <= 7'd0;
            py <= 7'd0;
            area <= 14'd0;
            ap1 <= 14'd0;
            ap2 <= 14'd0;
            ap3 <= 14'd0;
            vp_x <= 7'd0;
            vp_y <= 7'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 14'd0;
                    triangle_idx <= 4'd0;
                    vertex_idx <= 2'd0;
                    grid_x <= 4'd0;
                    grid_y <= 4'd0;
                    bit_idx <= 8'd0;
                    bitmap_word_idx <= 8'd0;
                    garry_bitmap <= 256'd0;
                    jerry_bitmap <= 256'd0;
                    compare_bitmap <= 256'd0;
                end
                
                RESET_BITMAP: begin
                    cycle_count <= cycle_count + 14'd1;
                    if (bitmap_word_idx < 8'd32) begin
                        // Clear bitmap word by word
                        case (bitmap_word_idx)
                            8'd0: garry_bitmap[0:7] <= 8'd0;
                            8'd1: garry_bitmap[8:15] <= 8'd0;
                            8'd2: garry_bitmap[16:23] <= 8'd0;
                            8'd3: garry_bitmap[24:31] <= 8'd0;
                            8'd4: garry_bitmap[32:39] <= 8'd0;
                            8'd5: garry_bitmap[40:47] <= 8'd0;
                            8'd6: garry_bitmap[48:55] <= 8'd0;
                            8'd7: garry_bitmap[56:63] <= 8'd0;
                            8'd8: garry_bitmap[64:71] <= 8'd0;
                            8'd9: garry_bitmap[72:79] <= 8'd0;
                            8'd10: garry_bitmap[80:87] <= 8'd0;
                            8'd11: garry_bitmap[88:95] <= 8'd0;
                            8'd12: garry_bitmap[96:103] <= 8'd0;
                            8'd13: garry_bitmap[104:111] <= 8'd0;
                            8'd14: garry_bitmap[112:119] <= 8'd0;
                            8'd15: garry_bitmap[120:127] <= 8'd0;
                            8'd16: garry_bitmap[128:135] <= 8'd0;
                            8'd17: garry_bitmap[136:143] <= 8'd0;
                            8'd18: garry_bitmap[144:151] <= 8'd0;
                            8'd19: garry_bitmap[152:159] <= 8'd0;
                            8'd20: garry_bitmap[160:167] <= 8'd0;
                            8'd21: garry_bitmap[168:175] <= 8'd0;
                            8'd22: garry_bitmap[176:183] <= 8'd0;
                            8'd23: garry_bitmap[184:191] <= 8'd0;
                            8'd24: garry_bitmap[192:199] <= 8'd0;
                            8'd25: garry_bitmap[200:207] <= 8'd0;
                            8'd26: garry_bitmap[208:215] <= 8'd0;
                            8'd27: garry_bitmap[216:223] <= 8'd0;
                            8'd28: garry_bitmap[224:231] <= 8'd0;
                            8'd29: garry_bitmap[232:239] <= 8'd0;
                            8'd30: garry_bitmap[240:247] <= 8'd0;
                            8'd31: garry_bitmap[248:255] <= 8'd0;
                        endcase
                        bitmap_word_idx <= bitmap_word_idx + 8'd1;
                    end
                end
                
                RASTERIZE_GARRY, RASTERIZE_JERRY: begin
                    cycle_count <= cycle_count + 14'd1;
                    
                    // Store current vertex coordinates
                    if (vertex_idx == 2'd0) begin
                        if (state == RASTERIZE_GARRY) begin
                            vertex_x[0] <= {1'b0, garry_triangles[triangle_idx][0][0]};
                            vertex_y[0] <= {1'b0, garry_triangles[triangle_idx][0][1]};
                        end else begin
                            vertex_x[0] <= {1'b0, jerry_triangles[triangle_idx][0][0]};
                            vertex_y[0] <= {1'b0, jerry_triangles[triangle_idx][0][1]};
                        end
                        vertex_idx <= 2'd1;
                    end else if (vertex_idx == 2'd1) begin
                        if (state == RASTERIZE_GARRY) begin
                            vertex_x[1] <= {1'b0, garry_triangles[triangle_idx][1][0]};
                            vertex_y[1] <= {1'b0, garry_triangles[triangle_idx][1][1]};
                        end else begin
                            vertex_x[1] <= {1'b0, jerry_triangles[triangle_idx][1][0]};
                            vertex_y[1] <= {1'b0, jerry_triangles[triangle_idx][1][1]};
                        end
                        vertex_idx <= 2'd2;
                    end else if (vertex_idx == 2'd2) begin
                        if (state == RASTERIZE_GARRY) begin
                            vertex_x[2] <= {1'b0, garry_triangles[triangle_idx][2][0]};
                            vertex_y[2] <= {1'b0, garry_triangles[triangle_idx][2][1]};
                        end else begin
                            vertex_x[2] <= {1'b0, jerry_triangles[triangle_idx][2][0]};
                            vertex_y[2] <= {1'b0, jerry_triangles[triangle_idx][2][1]};
                        end
                        vertex_idx <= 2'd3;
                    end else begin
                        // Calculate barycentric parameters
                        dx1 <= {7'd0, vertex_x[1]} - {7'd0, vertex_x[0]};
                        dy1 <= {7'd0, vertex_y[1]} - {7'd0, vertex_y[0]};
                        dx2 <= {7'd0, vertex_x[2]} - {7'd0, vertex_x[0]};
                        dy2 <= {7'd0, vertex_y[2]} - {7'd0, vertex_y[0]};
                        dx3 <= {7'd0, vertex_x[2]} - {7'd0, vertex_x[1]};
                        dy3 <= {7'd0, vertex_y[2]} - {7'd0, vertex_y[1]};
                        area <= (dx1 * dy2) - (dy1 * dx2);
                        vertex_idx <= 2'd0;  // Reset for grid scan
                    end
                    
                    // Scan grid
                    if (vertex_idx == 2'd3) begin
                        if (grid_x < 4'd16) begin
                            // Calculate barycentric coordinates
                            px <= {1'b0, grid_x} + 7'd8;  // Scale to Q2.4
                            py <= {1'b0, grid_y} + 7'd8;
                            
                            // Barycentric A (for v0)
                            cross1 <= (vertex_x[1] - px) * (vertex_y[2] - py) - (vertex_y[1] - py) * (vertex_x[2] - px);
                            
                            // Barycentric B (for v1)
                            cross2 <= (vertex_x[2] - px) * (vertex_y[0] - py) - (vertex_y[2] - py) * (vertex_x[0] - px);
                            
                            // Barycentric C (for v2)
                            cross3 <= (vertex_x[0] - px) * (vertex_y[1] - py) - (vertex_y[0] - py) * (vertex_x[1] - px);
                            
                            // Check if point is inside triangle
                            if (((cross1 >= 0) && (cross2 >= 0) && (cross3 >= 0)) ||
                                ((cross1 <= 0) && (cross2 <= 0) && (cross3 <= 0))) begin
                                
                                // Set pixel in bitmap
                                bit_idx <= grid_y * 4'd16 + grid_x;
                                
                                if (state == RASTERIZE_GARRY) begin
                                    if (bit_idx < 8'd128) begin
                                        garry_bitmap[bit_idx] <= 1'b1;
                                    end else begin
                                        garry_bitmap[bit_idx] <= 1'b1;
                                    end
                                end else begin
                                    if (bit_idx < 8'd128) begin
                                        jerry_bitmap[bit_idx] <= 1'b1;
                                    end else begin
                                        jerry_bitmap[bit_idx] <= 1'b1;
                                    end
                                end
                            end
                            
                            grid_x <= grid_x + 4'd1;
                        end else begin
                            grid_x <= 4'd0;
                            if (grid_y < 4'd15) begin
                                grid_y <= grid_y + 4'd1;
                            end else begin
                                grid_y <= 4'd0;
                                vertex_idx <= 2'd0;
                                grid_x <= 4'd0;
                            end
                        end
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 14'd1;
                    // Compare bitmaps
                    if (bit_idx < 8'd255) begin
                        if (garry_bitmap[bit_idx] != jerry_bitmap[bit_idx]) begin
                            same <= 1'b0;
                        end
                        bit_idx <= bit_idx + 8'd1;
                    end else begin
                        same <= 1'b1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (n > 4'd0 || m > 4'd0) begin
                    next_state = RESET_BITMAP;
                end
            end
            
            RESET_BITMAP: begin
                if (bitmap_word_idx >= 8'd32) begin
                    next_state = RASTERIZE_GARRY;
                end
            end
            
            RASTERIZE_GARRY: begin
                if (grid_y == 4'd15 && grid_x == 4'd16 && vertex_idx == 2'd0) begin
                    if (triangle_idx < n - 4'd1) begin
                        triangle_idx = triangle_idx + 4'd1;
                        grid_x = 4'd0;
                        grid_y = 4'd0;
                        next_state = RASTERIZE_GARRY;
                    end else begin
                        triangle_idx = 4'd0;
                        grid_x = 4'd0;
                        grid_y = 4'd0;
                        next_state = RASTERIZE_JERRY;
                    end
                end
            end
            
            RASTERIZE_JERRY: begin
                if (grid_y == 4'd15 && grid_x == 4'd16 && vertex_idx == 2'd0) begin
                    if (triangle_idx < m - 4'd1) begin
                        triangle_idx = triangle_idx + 4'd1;
                        grid_x = 4'd0;
                        grid_y = 4'd0;
                        next_state = RASTERIZE_JERRY;
                    end else begin
                        bit_idx = 8'd0;
                        same = 1'b1;
                        next_state = COMPARE;
                    end
                end
            end
            
            COMPARE: begin
                if (bit_idx >= 8'd255) begin
                    next_state = FINISH;
                end
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Override for invalid input
        if (state == IDLE && n == 4'd0 && m == 4'd0) begin
            next_state = FINISH;
        end
    end
    
endmodule