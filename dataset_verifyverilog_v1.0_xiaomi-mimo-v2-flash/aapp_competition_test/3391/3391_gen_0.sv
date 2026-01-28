module smallest_square (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [31:0] x_in,
    input wire signed [31:0] y_in,
    input wire [3:0] idx,
    input wire valid_in,
    output reg done,
    output reg busy,
    output reg signed [31:0] side_len
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] STORE     = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;
    
    reg [2:0] state, next_state;
    reg [3:0] num_points;
    reg [3:0] point_count;
    reg signed [31:0] x_buf [0:15];
    reg signed [31:0] y_buf [0:15];
    reg [3:0] ignore_idx;
    reg [4:0] cycle_count;
    
    // Internal registers for calculation
    reg signed [31:0] calc_min_x;
    reg signed [31:0] calc_max_x;
    reg signed [31:0] calc_min_y;
    reg signed [31:0] calc_max_y;
    reg signed [31:0] best_side;
    reg [3:0] point_idx;
    
    // Intermediate registers for combination logic
    reg signed [31:0] temp_min_x;
    reg signed [31:0] temp_max_x;
    reg signed [31:0] temp_min_y;
    reg signed [31:0] temp_max_y;
    reg signed [32:0] width;
    reg signed [32:0] height;
    reg signed [32:0] side;
    reg signed [31:0] side_clamped;
    
    integer i;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = STORE;
                else
                    next_state = IDLE;
            end
            STORE: begin
                if (point_count >= 4'd16 || (valid_in && point_count >= num_points && point_count > 0))
                    next_state = COMPUTE;
                else
                    next_state = STORE;
            end
            COMPUTE: begin
                if (ignore_idx >= num_points)
                    next_state = FINISH;
                else if (cycle_count >= 5'd20)
                    next_state = FINISH;
                else
                    next_state = COMPUTE;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            busy <= 1'b0;
            side_len <= 32'd0;
            num_points <= 4'd0;
            point_count <= 4'd0;
            ignore_idx <= 4'd0;
            cycle_count <= 5'd0;
            calc_min_x <= 32'd0;
            calc_max_x <= 32'd0;
            calc_min_y <= 32'd0;
            calc_max_y <= 32'd0;
            best_side <= 32'd0;
            point_idx <= 4'd0;
            temp_min_x <= 32'd0;
            temp_max_x <= 32'd0;
            temp_min_y <= 32'd0;
            temp_max_y <= 32'd0;
            width <= 33'sd0;
            height <= 33'sd0;
            side <= 33'sd0;
            side_clamped <= 32'd0;
            // Initialize buffer
            for (i = 0; i < 16; i = i + 1) begin
                x_buf[i] <= 32'd0;
                y_buf[i] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                    busy <= 1'b0;
                    cycle_count <= 5'd0;
                    ignore_idx <= 4'd0;
                    point_idx <= 4'd0;
                end
                
                STORE: begin
                    busy <= 1'b1;
                    if (valid_in && point_count < 4'd16) begin
                        x_buf[point_count] <= x_in;
                        y_buf[point_count] <= y_in;
                        num_points <= point_count + 4'd1;
                        point_count <= point_count + 4'd1;
                    end else if (!valid_in && point_count == 4'd0) begin
                        // Waiting for first point
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    if (ignore_idx == 4'd0) begin
                        // Initialize best_side with first calculation
                        best_side <= 32'd0;
                    end
                    
                    // Calculate bounding box for current ignore_idx
                    temp_min_x <= 32'h7FFFFFFF;
                    temp_max_x <= 32'h80000000;
                    temp_min_y <= 32'h7FFFFFFF;
                    temp_max_y <= 32'h80000000;
                    point_idx <= 4'd0;
                    
                    // Combinational calculation for this ignore_idx
                    // (Note: This is simplified; real implementation would need multi-cycle)
                    
                    if (ignore_idx < num_points) begin
                        // Find min/max excluding ignore_idx
                        for (i = 0; i < 16; i = i + 1) begin
                            if (i < num_points && i != ignore_idx) begin
                                if (x_buf[i] < temp_min_x)
                                    temp_min_x <= x_buf[i];
                                if (x_buf[i] > temp_max_x)
                                    temp_max_x <= x_buf[i];
                                if (y_buf[i] < temp_min_y)
                                    temp_min_y <= y_buf[i];
                                if (y_buf[i] > temp_max_y)
                                    temp_max_y <= y_buf[i];
                            end
                        end
                        
                        // Calculate width and height (33-bit for overflow protection)
                        width <= {temp_max_x[31], temp_max_x} - {temp_min_x[31], temp_min_x};
                        height <= {temp_max_y[31], temp_max_y} - {temp_min_y[31], temp_min_y};
                        
                        // Max of width and height
                        if (width > height)
                            side <= width;
                        else
                            side <= height;
                        
                        // Clamp to 32-bit signed
                        if (side > 32'h7FFFFFFF)
                            side_clamped <= 32'h7FFFFFFF;
                        else if (side < 32'h80000000)
                            side_clamped <= 32'h80000000;
                        else
                            side_clamped <= side[31:0];
                        
                        // Update best_side
                        if (ignore_idx == 4'd0 || side_clamped < best_side)
                            best_side <= side_clamped;
                        
                        ignore_idx <= ignore_idx + 4'd1;
                    end
                    
                    // Special case: N=1
                    if (num_points == 4'd1) begin
                        best_side <= 32'd0;
                        ignore_idx <= 4'd1; // Skip loop
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    side_len <= best_side;
                    busy <= 1'b0;
                    // Reset for next operation
                    point_count <= 4'd0;
                    num_points <= 4'd0;
                    ignore_idx <= 4'd0;
                    cycle_count <= 5'd0;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    busy <= 1'b0;
                    side_len <= 32'd0;
                end
            endcase
        end
    end

endmodule