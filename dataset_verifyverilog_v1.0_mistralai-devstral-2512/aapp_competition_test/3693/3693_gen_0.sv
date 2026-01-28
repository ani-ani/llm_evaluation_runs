module SquareIntersectionDetector(
    input clk,
    input rst_n,
    input start,
    input signed [8:0] sq_a_x [0:3],
    input signed [8:0] sq_a_y [0:3],
    input signed [8:0] sq_b_x [0:3],
    input signed [8:0] sq_b_y [0:3],
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_EXTREMES = 3'd1;
    localparam [2:0] CHECK_POINTS = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Bounding box for axis-aligned square (A)
    reg signed [8:0] a_x_min, a_x_max, a_y_min, a_y_max;
    
    // Bounding box for rotated square (B) in (u, v) space
    reg signed [9:0] b_u_min, b_u_max;  // u range: [0, 400]
    reg signed [9:0] b_v_min, b_v_max;  // v range: [-200, 200]
    
    // Point checking variables
    reg [3:0] point_index;
    reg signed [8:0] current_x, current_y;
    reg signed [9:0] current_u, current_v;
    reg point_in_rotated;
    
    // Scaled coordinates (x_scaled = x_orig + 100, y_scaled = y_orig + 100)
    reg signed [8:0] x_scaled, y_scaled;
    
    // Temporary variables for min/max calculations
    reg signed [8:0] temp_x, temp_y;
    reg signed [9:0] temp_u, temp_v;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            
            // Initialize all registers
            a_x_min <= 9'd0;
            a_x_max <= 9'd0;
            a_y_min <= 9'd0;
            a_y_max <= 9'd0;
            
            b_u_min <= 10'd0;
            b_u_max <= 10'd0;
            b_v_min <= 10'd0;
            b_v_max <= 10'd0;
            
            point_index <= 4'd0;
            current_x <= 9'd0;
            current_y <= 9'd0;
            current_u <= 10'd0;
            current_v <= 10'd0;
            point_in_rotated <= 1'b0;
            
            x_scaled <= 9'd0;
            y_scaled <= 9'd0;
            temp_x <= 9'd0;
            temp_y <= 9'd0;
            temp_u <= 10'd0;
            temp_v <= 10'd0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_EXTREMES;
                end
            end
            
            CALC_EXTREMES: begin
                next_state = CHECK_POINTS;
            end
            
            CHECK_POINTS: begin
                if (point_index == 4'd4) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Calculate bounding boxes for both squares
    always @(posedge clk) begin
        if (state == CALC_EXTREMES) begin
            // Initialize min/max values
            a_x_min <= sq_a_x[0];
            a_x_max <= sq_a_x[0];
            a_y_min <= sq_a_y[0];
            a_y_max <= sq_a_y[0];
            
            // Find min/max for axis-aligned square
            for (i = 0; i < 4; i = i + 1) begin
                temp_x <= sq_a_x[i];
                temp_y <= sq_a_y[i];
                
                if (temp_x < a_x_min) begin
                    a_x_min <= temp_x;
                end
                if (temp_x > a_x_max) begin
                    a_x_max <= temp_x;
                end
                
                if (temp_y < a_y_min) begin
                    a_y_min <= temp_y;
                end
                if (temp_y > a_y_max) begin
                    a_y_max <= temp_y;
                end
            end
            
            // Initialize min/max for rotated square in (u, v) space
            // First vertex
            temp_x <= sq_b_x[0];
            temp_y <= sq_b_y[0];
            x_scaled <= temp_x + 9'd100;
            y_scaled <= temp_y + 9'd100;
            temp_u <= x_scaled + y_scaled;
            temp_v <= x_scaled - y_scaled;
            
            b_u_min <= temp_u;
            b_u_max <= temp_u;
            b_v_min <= temp_v;
            b_v_max <= temp_v;
            
            // Check remaining vertices
            for (i = 1; i < 4; i = i + 1) begin
                temp_x <= sq_b_x[i];
                temp_y <= sq_b_y[i];
                x_scaled <= temp_x + 9'd100;
                y_scaled <= temp_y + 9'd100;
                temp_u <= x_scaled + y_scaled;
                temp_v <= x_scaled - y_scaled;
                
                if (temp_u < b_u_min) begin
                    b_u_min <= temp_u;
                end
                if (temp_u > b_u_max) begin
                    b_u_max <= temp_u;
                end
                
                if (temp_v < b_v_min) begin
                    b_v_min <= temp_v;
                end
                if (temp_v > b_v_max) begin
                    b_v_max <= temp_v;
                end
            end
        end
    end

    // Check points (5 points: 4 corners and center)
    always @(posedge clk) begin
        if (state == CHECK_POINTS) begin
            case (point_index)
                4'd0: begin  // Bottom-left corner
                    current_x <= a_x_min;
                    current_y <= a_y_min;
                end
                4'd1: begin  // Bottom-right corner
                    current_x <= a_x_max;
                    current_y <= a_y_min;
                end
                4'd2: begin  // Top-right corner
                    current_x <= a_x_max;
                    current_y <= a_y_max;
                end
                4'd3: begin  // Top-left corner
                    current_x <= a_x_min;
                    current_y <= a_y_max;
                end
                4'd4: begin  // Center point
                    current_x <= (a_x_min + a_x_max) / 2;
                    current_y <= (a_y_min + a_y_max) / 2;
                end
            endcase
            
            // Scale coordinates
            x_scaled <= current_x + 9'd100;
            y_scaled <= current_y + 9'd100;
            
            // Calculate u and v
            current_u <= x_scaled + y_scaled;
            current_v <= x_scaled - y_scaled;
            
            // Check if point is in rotated square
            point_in_rotated <= (current_u >= b_u_min) && (current_u <= b_u_max) &&
                               (current_v >= b_v_min) && (current_v <= b_v_max);
            
            // If any point is in the rotated square, set result
            if (point_in_rotated) begin
                result <= 1'b1;
            end
            
            // Increment point index
            point_index <= point_index + 4'd1;
        end
    end

    // Done signal and result handling
    always @(posedge clk) begin
        if (state == FINISH) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule