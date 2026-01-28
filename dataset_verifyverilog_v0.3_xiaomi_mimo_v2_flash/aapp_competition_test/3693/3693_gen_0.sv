module square_intersection(
    input clk,
    input rst_n,
    input start,
    input [31:0] square1_coords,
    input [31:0] square2_coords,
    output reg result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] EXTRACT = 4'd1;
    localparam [3:0] BOUND1 = 4'd2;
    localparam [3:0] BOUND2 = 4'd3;
    localparam [3:0] CHECK_V1 = 4'd4;
    localparam [3:0] CHECK_V2 = 4'd5;
    localparam [3:0] CHECK_V3 = 4'd6;
    localparam [3:0] CHECK_V4 = 4'd7;
    localparam [3:0] CHECK_UV = 4'd8;
    localparam [3:0] FINISH = 4'd9;

    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    // Extracted vertices (8-bit signed)
    reg signed [7:0] s1x0, s1y0, s1x1, s1y1, s1x2, s1y2, s1x3, s1y3;
    reg signed [7:0] s2x0, s2y0, s2x1, s2y1, s2x2, s2y2, s2x3, s2y3;
    
    // Bounding boxes (16-bit to prevent overflow)
    reg signed [15:0] s1_min_x, s1_max_x, s1_min_y, s1_max_y;
    reg signed [15:0] s2_min_x, s2_max_x, s2_min_y, s2_max_y;
    reg signed [15:0] s2_u0, s2_v0, s2_u1, s2_v1, s2_u2, s2_v2, s2_u3, s2_v3;
    reg signed [15:0] s2_min_u, s2_max_u, s2_min_v, s2_max_v;
    
    // Vertex check flags
    reg inside_s1, inside_s2, edge_intersect;
    reg [3:0] check_idx;
    reg signed [15:0] temp_u, temp_v;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize all registers
            s1x0 <= 8'sd0; s1y0 <= 8'sd0; s1x1 <= 8'sd0; s1y1 <= 8'sd0;
            s1x2 <= 8'sd0; s1y2 <= 8'sd0; s1x3 <= 8'sd0; s1y3 <= 8'sd0;
            s2x0 <= 8'sd0; s2y0 <= 8'sd0; s2x1 <= 8'sd0; s2y1 <= 8'sd0;
            s2x2 <= 8'sd0; s2y2 <= 8'sd0; s2x3 <= 8'sd0; s2y3 <= 8'sd0;
            s1_min_x <= 16'sd0; s1_max_x <= 16'sd0;
            s1_min_y <= 16'sd0; s1_max_y <= 16'sd0;
            s2_min_x <= 16'sd0; s2_max_x <= 16'sd0;
            s2_min_y <= 16'sd0; s2_max_y <= 16'sd0;
            s2_min_u <= 16'sd0; s2_max_u <= 16'sd0;
            s2_min_v <= 16'sd0; s2_max_v <= 16'sd0;
            s2_u0 <= 16'sd0; s2_v0 <= 16'sd0;
            s2_u1 <= 16'sd0; s2_v1 <= 16'sd0;
            s2_u2 <= 16'sd0; s2_v2 <= 16'sd0;
            s2_u3 <= 16'sd0; s2_v3 <= 16'sd0;
            inside_s1 <= 1'b0; inside_s2 <= 1'b0; edge_intersect <= 1'b0;
            check_idx <= 4'd0;
            temp_u <= 16'sd0; temp_v <= 16'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= EXTRACT;
                    end
                end
                
                EXTRACT: begin
                    // Extract square1 vertices from lower 16 bits
                    s1x0 <= square1_coords[7:0];
                    s1y0 <= square1_coords[15:8];
                    s1x1 <= square1_coords[23:16];
                    s1y1 <= square1_coords[31:24];
                    // Extract square2 vertices from upper 16 bits
                    s2x0 <= square2_coords[7:0];
                    s2y0 <= square2_coords[15:8];
                    s2x1 <= square2_coords[23:16];
                    s2y1 <= square2_coords[31:24];
                    state <= BOUND1;
                end
                
                BOUND1: begin
                    // Compute bounding box for square1
                    s1_min_x <= (s1x0 < s1x1) ? {8'd0, s1x0} : {8'd0, s1x1};
                    s1_max_x <= (s1x0 > s1x1) ? {8'd0, s1x0} : {8'd0, s1x1};
                    s1_min_y <= (s1y0 < s1y1) ? {8'd0, s1y0} : {8'd0, s1y1};
                    s1_max_y <= (s1y0 > s1y1) ? {8'd0, s1y0} : {8'd0, s1y1};
                    state <= BOUND2;
                end
                
                BOUND2: begin
                    // Compute bounding box for square2 and UV transformation
                    s2_min_x <= (s2x0 < s2x1) ? {8'd0, s2x0} : {8'd0, s2x1};
                    s2_max_x <= (s2x0 > s2x1) ? {8'd0, s2x0} : {8'd0, s2x1};
                    s2_min_y <= (s2y0 < s2y1) ? {8'd0, s2y0} : {8'd0, s2y1};
                    s2_max_y <= (s2y0 > s2y1) ? {8'd0, s2y0} : {8'd0, s2y1};
                    // UV transformation: u = x + y, v = x - y
                    s2_u0 <= {8'd0, s2x0} + {8'd0, s2y0};
                    s2_v0 <= {8'd0, s2x0} - {8'd0, s2y0};
                    s2_u1 <= {8'd0, s2x1} + {8'd0, s2y1};
                    s2_v1 <= {8'd0, s2x1} - {8'd0, s2y1};
                    s2_u2 <= {8'd0, s2x2} + {8'd0, s2y2};
                    s2_v2 <= {8'd0, s2x2} - {8'd0, s2y2};
                    s2_u3 <= {8'd0, s2x3} + {8'd0, s2y3};
                    s2_v3 <= {8'd0, s2x3} - {8'd0, s2y3};
                    check_idx <= 4'd0;
                    state <= CHECK_V1;
                end
                
                CHECK_V1: begin
                    // Check if any square1 vertex is inside square2's bounding box
                    if (check_idx == 4'd0) begin
                        if ({8'd0, s1x0} >= s2_min_x && {8'd0, s1x0} <= s2_max_x &&
                            {8'd0, s1y0} >= s2_min_y && {8'd0, s1y0} <= s2_max_y) begin
                            inside_s2 <= 1'b1;
                        end
                        check_idx <= 4'd1;
                    end
                    if (check_idx == 4'd1) begin
                        if ({8'd0, s1x1} >= s2_min_x && {8'd0, s1x1} <= s2_max_x &&
                            {8'd0, s1y1} >= s2_min_y && {8'd0, s1y1} <= s2_max_y) begin
                            inside_s2 <= 1'b1;
                        end
                        check_idx <= 4'd2;
                    end
                    if (check_idx == 4'd2) begin
                        if ({8'd0, s1x2} >= s2_min_x && {8'd0, s1x2} <= s2_max_x &&
                            {8'd0, s1y2} >= s2_min_y && {8'd0, s1y2} <= s2_max_y) begin
                            inside_s2 <= 1'b1;
                        end
                        check_idx <= 4'd3;
                    end
                    if (check_idx == 4'd3) begin
                        if ({8'd0, s1x3} >= s2_min_x && {8'd0, s1x3} <= s2_max_x &&
                            {8'd0, s1y3} >= s2_min_y && {8'd0, s1y3} <= s2_max_y) begin
                            inside_s2 <= 1'b1;
                        end
                        check_idx <= 4'd4;
                    end
                    if (check_idx == 4'd4) begin
                        state <= CHECK_V2;
                    end
                end
                
                CHECK_V2: begin
                    // Check if any square2 vertex is inside square1's bounding box
                    if (check_idx == 4'd4) begin
                        if ({8'd0, s2x0} >= s1_min_x && {8'd0, s2x0} <= s1_max_x &&
                            {8'd0, s2y0} >= s1_min_y && {8'd0, s2y0} <= s1_max_y) begin
                            inside_s1 <= 1'b1;
                        end
                        check_idx <= 4'd5;
                    end
                    if (check_idx == 4'd5) begin
                        if ({8'd0, s2x1} >= s1_min_x && {8'd0, s2x1} <= s1_max_x &&
                            {8'd0, s2y1} >= s1_min_y && {8'd0, s2y1} <= s1_max_y) begin
                            inside_s1 <= 1'b1;
                        end
                        check_idx <= 4'd6;
                    end
                    if (check_idx == 4'd6) begin
                        if ({8'd0, s2x2} >= s1_min_x && {8'd0, s2x2} <= s1_max_x &&
                            {8'd0, s2y2} >= s1_min_y && {8'd0, s2y2} <= s1_max_y) begin
                            inside_s1 <= 1'b1;
                        end
                        check_idx <= 4'd7;
                    end
                    if (check_idx == 4'd7) begin
                        if ({8'd0, s2x3} >= s1_min_x && {8'd0, s2x3} <= s1_max_x &&
                            {8'd0, s2y3} >= s1_min_y && {8'd0, s2y3} <= s1_max_y) begin
                            inside_s1 <= 1'b1;
                        end
                        check_idx <= 4'd8;
                    end
                    if (check_idx == 4'd8) begin
                        state <= CHECK_V3;
                    end
                end
                
                CHECK_V3: begin
                    // Compute UV bounds for square2
                    s2_min_u <= (s2_u0 < s2_u1) ? s2_u0 : s2_u1;
                    s2_max_u <= (s2_u0 > s2_u1) ? s2_u0 : s2_u1;
                    s2_min_v <= (s2_v0 < s2_v1) ? s2_v0 : s2_v1;
                    s2_max_v <= (s2_v0 > s2_v1) ? s2_v0 : s2_v1;
                    check_idx <= 4'd9;
                    state <= CHECK_UV;
                end
                
                CHECK_UV: begin
                    // Check if square1 vertices are inside square2 using UV
                    if (check_idx == 4'd9) begin
                        temp_u <= {8'd0, s1x0} + {8'd0, s1y0};
                        temp_v <= {8'd0, s1x0} - {8'd0, s1y0};
                        if (temp_u >= s2_min_u && temp_u <= s2_max_u &&
                            temp_v >= s2_min_v && temp_v <= s2_max_v) begin
                            inside_s2 <= 1'b1;
                        end
                        check_idx <= 4'd10;
                    end
                    if (check_idx == 4'd10) begin
                        temp_u <= {8'd0, s1x1} + {8'd0, s1y1};
                        temp_v <= {8'd0, s1x1} - {8'd0, s1y1};
                        if (temp_u >= s2_min_u && temp_u <= s2_max_u &&
                            temp_v >= s2_min_v && temp_v <= s2_max_v) begin
                            inside_s2 <= 1'b1;
                        end
                        check_idx <= 4'd11;
                    end
                    if (check_idx == 4'd11) begin
                        temp_u <= {8'd0, s1x2} + {8'd0, s1y2};
                        temp_v <= {8'd0, s1x2} - {8'd0, s1y2};
                        if (temp_u >= s2_min_u && temp_u <= s2_max_u &&
                            temp_v >= s2_min_v && temp_v <= s2_max_v) begin
                            inside_s2 <= 1'b1;
                        end
                        check_idx <= 4'd12;
                    end
                    if (check_idx == 4'd12) begin
                        temp_u <= {8'd0, s1x3} + {8'd0, s1y3};
                        temp_v <= {8'd0, s1x3} - {8'd0, s1y3};
                        if (temp_u >= s2_min_u && temp_u <= s2_max_u &&
                            temp_v >= s2_min_v && temp_v <= s2_max_v) begin
                            inside_s2 <= 1'b1;
                        end
                        check_idx <= 4'd13;
                    end
                    if (check_idx == 4'd13) begin
                        // Edge intersection check (simplified)
                        // Check if bounding boxes overlap
                        if (s1_min_x <= s2_max_x && s1_max_x >= s2_min_x &&
                            s1_min_y <= s2_max_y && s1_max_y >= s2_min_y) begin
                            edge_intersect <= 1'b1;
                        end
                        state <= CHECK_V4;
                    end
                end
                
                CHECK_V4: begin
                    // Final intersection decision
                    if (inside_s1 || inside_s2 || edge_intersect) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 8'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= FINISH;
                    done <= 1'b1;
                    result <= 1'b0;
                end
            end
        end
    end

endmodule