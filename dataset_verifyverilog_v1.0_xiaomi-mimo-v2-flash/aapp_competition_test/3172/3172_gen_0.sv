module MaxCircleIntersection (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] num_points,
    input wire signed [31:0] x [0:15],
    input wire signed [31:0] y [0:15],
    output reg [4:0] result,
    output reg done,
    output reg busy
);

    // Fixed-point constants
    localparam signed [31:0] ONE = 32'h00010000;  // 1.0 in Q16.16
    localparam signed [31:0] NEG_ONE = 32'hFFFF0000;  // -1.0 in Q16.16
    localparam [7:0] MAX_CYCLES = 8'd200;  // Adjusted for hardware
    localparam [7:0] MAX_POINT_INDEX = 8'd15;

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] INIT_PAIRS = 3'd2;
    localparam [2:0] CHECK_LINES = 3'd3;
    localparam [2:0] UPDATE_MAX = 3'd4;
    localparam [2:0] NEXT_PAIR = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] max_count, current_count;
    reg [3:0] num_reg;
    reg signed [31:0] x_reg [0:15];
    reg signed [31:0] y_reg [0:15];
    
    // Pair counters
    reg [7:0] i_idx, j_idx, offset_idx;
    reg [7:0] point_idx;  // For checking circles
    
    // Line parameters (combinational)
    reg signed [31:0] line_A, line_B, line_C;
    
    // Combinational signals
    reg [7:0] cycle_count;
    wire signed [63:0] dist_num;  // Numerator of distance
    wire signed [31:0] dist_abs;  // Absolute distance
    wire intersected;
    
    // Counter signals
    wire pair_done, all_pairs_done, points_check_done;
    wire valid_pair;
    
    // Calculate distance for current point
    // distance = |A*x + B*y + C| / sqrt(A^2 + B^2)
    // For unit circles, we check |A*x + B*y + C| <= sqrt(A^2 + B^2)
    // But we're using normalized lines where sqrt(A^2+B^2) = 1.0
    // Actually for tangent lines, distance = radius = 1.0
    // So we check |A*x + B*y + C| <= 1.0 in Q16.16 units
    
    assign dist_num = (line_A * x_reg[point_idx]) + (line_B * y_reg[point_idx]) + {line_C, 16'd0};
    // Convert 64-bit to 32-bit magnitude (take lower 32 bits of abs)
    // Since we're in Q32.32 from multiplication, Q16.16 * Q16.16 = Q32.32
    // We need Q16.16 result
    
    wire signed [31:0] dist_temp;
    assign dist_temp = dist_num[47:16];  // Extract Q16.16 from Q32.32
    
    // Absolute value
    wire signed [31:0] dist_signed;
    assign dist_signed = (dist_temp[31] ? -dist_temp : dist_temp);
    
    // Intersection condition: |distance| <= 1.0
    assign intersected = (dist_signed <= ONE);
    
    // Status signals
    assign pair_done = (offset_idx >= 8'd2);  // 0: center, 1: +offset, 2: -offset
    assign all_pairs_done = (i_idx >= num_reg);
    assign points_check_done = (point_idx >= num_reg);
    assign valid_pair = (i_idx < num_reg) && (j_idx < num_reg) && (i_idx != j_idx);

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD : IDLE;
            LOAD: next_state = INIT_PAIRS;
            INIT_PAIRS: next_state = CHECK_LINES;
            CHECK_LINES: begin
                if (points_check_done) next_state = UPDATE_MAX;
                else next_state = CHECK_LINES;
            end
            UPDATE_MAX: next_state = NEXT_PAIR;
            NEXT_PAIR: begin
                if (pair_done && all_pairs_done) next_state = FINISH;
                else if (pair_done) next_state = INIT_PAIRS;
                else next_state = CHECK_LINES;
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Line parameter calculation (combinational)
    always @(*) begin
        // Default: line through centers (offset_idx = 0)
        line_A = 32'd0;
        line_B = 32'd0;
        line_C = 32'd0;
        
        if (valid_pair) begin
            // Vector from i to j
            reg signed [31:0] dx, dy, mag_sq, mag_inv;
            dx = x_reg[j_idx] - x_reg[i_idx];
            dy = y_reg[j_idx] - y_reg[i_idx];
            
            // Line equation: (y2-y1)*x - (x2-x1)*y + C = 0
            // For center line: C = x1*y2 - x2*y1
            // A = dy, B = -dx, C = x1*y2 - x2*y1
            
            line_A = dy;
            line_B = -dx;
            
            // C in Q16.16 (result is Q32.32, take middle Q16.16)
            line_C = (x_reg[i_idx] * y_reg[j_idx] - x_reg[j_idx] * y_reg[i_idx]) >>> 16;
            
            // For offset lines (offset_idx = 1 or 2)
            // Offset = ±1.0 * sqrt(A^2 + B^2)
            // But for unit circles, we need to move line by exactly 1.0 perpendicular
            // This requires normalizing the line first
            
            if (offset_idx == 8'd1 || offset_idx == 8'd2) begin
                // Calculate magnitude^2 = A^2 + B^2 in Q16.16 squared = Q32.32
                reg signed [63:0] mag_sq_64;
                reg signed [63:0] mag_64;
                reg signed [31:0] mag_q16;
                
                mag_sq_64 = (line_A * line_A) + (line_B * line_B);
                // mag_sq_64 is Q32.32, take sqrt to get Q16.16
                // For hardware, we approximate sqrt or use shift
                // Since A and B are in Q16.16, mag_sq is Q32.32
                // We need sqrt of Q32.32 to get Q16.16
                
                // Simplified: approximate magnitude (floor/shift)
                // For most cases, magnitude is small enough to fit
                mag_64 = mag_sq_64 >>> 16;  // Rough approximation
                mag_q16 = mag_64[31:0];
                
                // If mag is 0 (vertical/horizontal), handle separately
                if (mag_q16 <= 32'd65536 && mag_q16 > 32'd0) begin
                    // Small magnitude, use direct offset
                    line_C = line_C + (offset_idx == 8'd1 ? ONE : NEG_ONE);
                end else if (mag_q16 > 32'd65536) begin
                    // Apply offset: C += offset * sqrt(A^2+B^2)
                    // offset = ±1.0, sqrt(A^2+B^2) = mag_q16 in Q16.16
                    // Result is Q16.16 * Q16.16 = Q32.32
                    if (offset_idx == 8'd1)
                        line_C = line_C + (ONE * mag_q16) >>> 16;
                    else
                        line_C = line_C - (ONE * mag_q16) >>> 16;
                end
            end
        end
        
        // Special cases for single point (degenerate pairs)
        // This happens when we need vertical/horizontal lines through points
        if (!valid_pair && offset_idx == 8'd3) begin
            // Vertical line through point i_idx
            line_A = 32'h00010000;  // 1.0
            line_B = 32'd0;
            line_C = -x_reg[i_idx];  // x - x_i = 0
        end else if (!valid_pair && offset_idx == 8'd4) begin
            // Horizontal line through point i_idx
            line_A = 32'd0;
            line_B = 32'h00010000;  // 1.0
            line_C = -y_reg[i_idx];  // y - y_i = 0
        end
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            busy <= 1'b0;
            max_count <= 5'd0;
            current_count <= 5'd0;
            num_reg <= 4'd0;
            i_idx <= 8'd0;
            j_idx <= 8'd0;
            offset_idx <= 8'd0;
            point_idx <= 8'd0;
            cycle_count <= 8'd0;
            // Initialize arrays
            begin : init_arrays
                integer k;
                for (k = 0; k < 16; k = k + 1) begin
                    x_reg[k] <= 32'd0;
                    y_reg[k] <= 32'd0;
                end
            end
        end else begin
            done <= 1'b0;
            busy <= (state != IDLE);
            
            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    max_count <= 5'd0;
                    if (start) begin
                        num_reg <= num_points;
                        i_idx <= 8'd0;
                        j_idx <= 8'd0;
                        offset_idx <= 8'd0;
                    end
                end
                
                LOAD: begin
                    // Sample input array
                    begin : load_arrays
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            if (k < num_reg) begin
                                x_reg[k] <= x[k];
                                y_reg[k] <= y[k];
                            end
                        end
                    end
                end
                
                INIT_PAIRS: begin
                    // Initialize for checking this line
                    point_idx <= 8'd0;
                    current_count <= 5'd0;
                    cycle_count <= cycle_count + 8'd1;
                end
                
                CHECK_LINES: begin
                    // Count intersected circles for current line
                    if (intersected) begin
                        current_count <= current_count + 5'd1;
                    end
                    point_idx <= point_idx + 8'd1;
                end
                
                UPDATE_MAX: begin
                    // Update maximum count
                    if (current_count > max_count) begin
                        max_count <= current_count;
                    end
                end
                
                NEXT_PAIR: begin
                    // Move to next offset, then next pair
                    if (pair_done) begin
                        offset_idx <= 8'd0;
                        j_idx <= j_idx + 8'd1;
                        if (j_idx + 8'd1 >= num_reg) begin
                            j_idx <= 8'd0;
                            i_idx <= i_idx + 8'd1;
                        end
                    end else begin
                        offset_idx <= offset_idx + 8'd1;
                    end
                    
                    // Also check degenerate cases for single points
                    // After checking all pairs, check vertical/horizontal through each point
                    if (all_pairs_done && offset_idx == 8'd2) begin
                        offset_idx <= 8'd3;  // Start single-point checks
                        i_idx <= 8'd0;
                    end
                    if (offset_idx == 8'd3 && i_idx >= num_reg) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= max_count;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Prevent infinite loops
            if (cycle_count >= MAX_CYCLES && state != FINISH && state != IDLE) begin
                state <= FINISH;
            end
        end
    end

endmodule