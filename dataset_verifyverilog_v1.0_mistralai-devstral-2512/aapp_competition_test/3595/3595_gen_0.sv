module phaser_max_hits(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] r,
    input wire [6:0] L,
    input wire [15:0] rooms [0:7],
    output reg [3:0] max_hits,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    // Fixed-point format: Q6.8 (6 integer bits, 8 fractional bits)
    localparam [15:0] FP_SCALE = 16'd256; // 2^8
    
    // Internal registers
    reg [2:0] state;
    reg [3:0] start_room_idx;
    reg [3:0] target_room_idx;
    reg [3:0] check_room_idx;
    reg [3:0] current_hits;
    reg [3:0] max_hits_reg;
    reg [5:0] start_x, start_y;
    reg [5:0] target_x, target_y;
    reg [15:0] dx, dy; // Q6.8 format
    reg [15:0] segment_length_sq; // Q12.16 format
    reg [15:0] L_sq; // Q12.16 format
    reg [15:0] x0, y0, x1, y1; // Q6.8 format
    reg [15:0] x_min, y_min, x_max, y_max; // Q6.8 format
    reg [15:0] t0, t1, t2, t3; // Q6.8 format
    reg [15:0] t_min, t_max; // Q6.8 format
    reg hit;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10000;

    // Extract room coordinates
    function [5:0] get_x1;
        input [15:0] room;
        begin
            get_x1 = room[15:10];
        end
    endfunction

    function [5:0] get_y1;
        input [15:0] room;
        begin
            get_y1 = room[9:4];
        end
    endfunction

    function [5:0] get_x2;
        input [15:0] room;
        begin
            get_x2 = room[3:0];
        end
    endfunction

    function [5:0] get_y2;
        input [15:0] room;
        begin
            get_y2 = room[15:10];
        end
    endfunction

    // Convert to fixed-point
    function [15:0] to_fp;
        input [5:0] val;
        begin
            to_fp = {6'd0, val} << 8; // Q6.8 format
        end
    endfunction

    // Fixed-point multiplication
    function [15:0] fp_mult;
        input [15:0] a, b;
        begin
            fp_mult = (a * b) >> 8; // Q6.8 * Q6.8 = Q12.16, shift to Q6.8
        end
    endfunction

    // Fixed-point division
    function [15:0] fp_div;
        input [15:0] a, b;
        reg [31:0] temp;
        begin
            if (b == 0) begin
                fp_div = 16'd0;
            end else begin
                temp = {16'd0, a} << 8; // Q22.24
                fp_div = temp / b; // Q14.16, shift to Q6.8
            end
        end
    endfunction

    // Fixed-point square root (approximation)
    function [15:0] fp_sqrt;
        input [15:0] val;
        reg [15:0] x;
        reg [15:0] x_next;
        integer i;
        begin
            if (val == 0) begin
                fp_sqrt = 16'd0;
            end else begin
                x = val >> 1; // Initial guess
                for (i = 0; i < 8; i = i + 1) begin
                    x_next = (x + fp_div(val, x)) >> 1;
                    x = x_next;
                end
                fp_sqrt = x;
            end
        end
    endfunction

    // Check if segment intersects room
    function hit_room;
        input [15:0] x0, y0, x1, y1;
        input [15:0] x_min, y_min, x_max, y_max;
        reg [15:0] dx, dy;
        reg [15:0] t0, t1, t2, t3;
        reg [15:0] t_min, t_max;
        begin
            dx = x1 - x0;
            dy = y1 - y0;
            
            // Check if segment is a point
            if (dx == 0 && dy == 0) begin
                hit_room = (x0 >= x_min && x0 <= x_max && y0 >= y_min && y0 <= y_max);
            end else begin
                // Calculate intersection parameters
                if (dx != 0) begin
                    t0 = fp_div((x_min - x0), dx);
                    t1 = fp_div((x_max - x0), dx);
                end else begin
                    t0 = 16'd0;
                    t1 = 16'd0;
                end
                
                if (dy != 0) begin
                    t2 = fp_div((y_min - y0), dy);
                    t3 = fp_div((y_max - y0), dy);
                end else begin
                    t2 = 16'd0;
                    t3 = 16'd0;
                end
                
                // Determine valid t range
                t_min = (t0 < t1) ? t0 : t1;
                t_max = (t0 < t1) ? t1 : t0;
                
                if (t2 < t3) begin
                    t_min = (t_min > t2) ? t_min : t2;
                    t_max = (t_max < t3) ? t_max : t3;
                end else begin
                    t_min = (t_min > t3) ? t_min : t3;
                    t_max = (t_max < t2) ? t_max : t2;
                end
                
                // Check if valid intersection exists
                hit_room = (t_min <= t_max && t_max >= 16'd0 && t_min <= 16'd256);
            end
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            start_room_idx <= 4'd0;
            target_room_idx <= 4'd0;
            check_room_idx <= 4'd0;
            current_hits <= 4'd0;
            max_hits_reg <= 4'd0;
            start_x <= 6'd0;
            start_y <= 6'd0;
            target_x <= 6'd0;
            target_y <= 6'd0;
            dx <= 16'd0;
            dy <= 16'd0;
            segment_length_sq <= 16'd0;
            L_sq <= 16'd0;
            x0 <= 16'd0;
            y0 <= 16'd0;
            x1 <= 16'd0;
            y1 <= 16'd0;
            x_min <= 16'd0;
            y_min <= 16'd0;
            x_max <= 16'd0;
            y_max <= 16'd0;
            t0 <= 16'd0;
            t1 <= 16'd0;
            t2 <= 16'd0;
            t3 <= 16'd0;
            t_min <= 16'd0;
            t_max <= 16'd0;
            hit <= 1'b0;
            cycle_count <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        start_room_idx <= 4'd0;
                        target_room_idx <= 4'd0;
                        check_room_idx <= 4'd0;
                        current_hits <= 4'd0;
                        max_hits_reg <= 4'd0;
                        L_sq <= fp_mult(L, L); // Q6.8 * Q6.8 = Q12.16
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get start point
                    if (start_room_idx < r) begin
                        start_x = get_x1(rooms[start_room_idx]);
                        start_y = get_y1(rooms[start_room_idx]);
                        
                        // Get target point
                        if (target_room_idx < r) begin
                            target_x = get_x1(rooms[target_room_idx]);
                            target_y = get_y1(rooms[target_room_idx]);
                            
                            // Skip if same point
                            if (start_x == target_x && start_y == target_y) begin
                                target_room_idx <= target_room_idx + 4'd1;
                            end else begin
                                // Calculate direction vector
                                dx = to_fp(target_x) - to_fp(start_x);
                                dy = to_fp(target_y) - to_fp(start_y);
                                
                                // Calculate segment length squared
                                segment_length_sq = fp_mult(dx, dx) + fp_mult(dy, dy);
                                
                                // Check if segment length <= L
                                if (segment_length_sq <= L_sq) begin
                                    // Construct segment from start point extending length L
                                    x0 = to_fp(start_x);
                                    y0 = to_fp(start_y);
                                    
                                    // Normalize direction vector
                                    if (segment_length_sq != 0) begin
                                        x1 = x0 + fp_mult(dx, fp_sqrt(L_sq)) / fp_sqrt(segment_length_sq);
                                        y1 = y0 + fp_mult(dy, fp_sqrt(L_sq)) / fp_sqrt(segment_length_sq);
                                    end else begin
                                        x1 = x0;
                                        y1 = y0;
                                    end
                                    
                                    // Check intersection with all rooms
                                    current_hits <= 4'd0;
                                    check_room_idx <= 4'd0;
                                    state <= COMPUTE;
                                end else begin
                                    target_room_idx <= target_room_idx + 4'd1;
                                end
                            end
                        end else begin
                            target_room_idx <= 4'd0;
                            start_room_idx <= start_room_idx + 4'd1;
                        end
                    end else begin
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

    // Check room intersection
    always @(posedge clk) begin
        if (state == COMPUTE && check_room_idx < r) begin
            // Get room boundaries
            x_min = to_fp(get_x1(rooms[check_room_idx]));
            y_min = to_fp(get_y1(rooms[check_room_idx]));
            x_max = to_fp(get_x2(rooms[check_room_idx]));
            y_max = to_fp(get_y2(rooms[check_room_idx]));
            
            // Check intersection
            hit = hit_room(x0, y0, x1, y1, x_min, y_min, x_max, y_max);
            
            if (hit) begin
                current_hits <= current_hits + 4'd1;
            end
            
            check_room_idx <= check_room_idx + 4'd1;
            
            // Update max hits
            if (check_room_idx == r) begin
                if (current_hits > max_hits_reg) begin
                    max_hits_reg <= current_hits;
                end
                target_room_idx <= target_room_idx + 4'd1;
            end
        end
    end

    // Output max hits
    always @(posedge clk) begin
        if (state == FINISH) begin
            max_hits <= max_hits_reg;
        end
    end

    // Safety: prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            state <= FINISH;
        end
    end

endmodule