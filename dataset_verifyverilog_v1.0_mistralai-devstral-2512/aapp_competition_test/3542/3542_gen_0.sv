module WireLengthCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] ax1, ay1, ax2, ay2,
    input wire [3:0] bx1, by1, bx2, by2,
    output reg [15:0] result,
    output reg done,
    output reg possible
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // State register
    reg [1:0] state;

    // Cycle counter to prevent infinite loops
    reg [6:0] cycle_count;
    localparam [6:0] MAX_CYCLES = 7'd100;

    // Path tracking arrays (9x9 grid)
    reg [8:0] path_a_x [0:80];
    reg [8:0] path_a_y [0:80];
    reg [8:0] path_b_x [0:80];
    reg [8:0] path_b_y [0:80];
    reg [7:0] path_a_len;
    reg [7:0] path_b_len;

    // Temporary registers for computation
    reg [7:0] i, j;
    reg [3:0] x, y;
    reg [3:0] min_x, max_x, min_y, max_y;
    reg [3:0] temp_x, temp_y;
    reg intersection_found;

    // Manhattan distance calculation
    reg [7:0] dA, dB;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            possible <= 1'b1;
            cycle_count <= 7'd0;
            
            // Initialize path arrays
            for (i = 0; i < 81; i = i + 1) begin
                path_a_x[i] <= 9'd0;
                path_a_y[i] <= 9'd0;
                path_b_x[i] <= 9'd0;
                path_b_y[i] <= 9'd0;
            end
            path_a_len <= 8'd0;
            path_b_len <= 8'd0;
            
            i <= 8'd0;
            j <= 8'd0;
            x <= 4'd0;
            y <= 4'd0;
            min_x <= 4'd0;
            max_x <= 4'd0;
            min_y <= 4'd0;
            max_y <= 4'd0;
            temp_x <= 4'd0;
            temp_y <= 4'd0;
            intersection_found <= 1'b0;
            dA <= 8'd0;
            dB <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 7'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 7'd1;
                    
                    // Calculate Manhattan distances
                    if (ax1 > ax2) begin
                        dA <= (ax1 - ax2) + (ay1 > ay2 ? (ay1 - ay2) : (ay2 - ay1));
                    end else begin
                        dA <= (ax2 - ax1) + (ay1 > ay2 ? (ay1 - ay2) : (ay2 - ay1));
                    end
                    
                    if (bx1 > bx2) begin
                        dB <= (bx1 - bx2) + (by1 > by2 ? (by1 - by2) : (by2 - by1));
                    end else begin
                        dB <= (bx2 - bx1) + (by1 > by2 ? (by1 - by2) : (by2 - by1));
                    end
                    
                    // Generate path A (horizontal then vertical)
                    path_a_len <= 8'd0;
                    temp_x <= ax1;
                    temp_y <= ay1;
                    
                    // Horizontal segment
                    if (ax1 < ax2) begin
                        for (i = 0; i < (ax2 - ax1); i = i + 1) begin
                            path_a_x[path_a_len] <= temp_x;
                            path_a_y[path_a_len] <= temp_y;
                            path_a_len <= path_a_len + 8'd1;
                            temp_x <= temp_x + 4'd1;
                        end
                    end else if (ax1 > ax2) begin
                        for (i = 0; i < (ax1 - ax2); i = i + 1) begin
                            path_a_x[path_a_len] <= temp_x;
                            path_a_y[path_a_len] <= temp_y;
                            path_a_len <= path_a_len + 8'd1;
                            temp_x <= temp_x - 4'd1;
                        end
                    end
                    
                    // Vertical segment
                    if (ay1 < ay2) begin
                        for (i = 0; i < (ay2 - ay1); i = i + 1) begin
                            path_a_x[path_a_len] <= temp_x;
                            path_a_y[path_a_len] <= temp_y;
                            path_a_len <= path_a_len + 8'd1;
                            temp_y <= temp_y + 4'd1;
                        end
                    end else if (ay1 > ay2) begin
                        for (i = 0; i < (ay1 - ay2); i = i + 1) begin
                            path_a_x[path_a_len] <= temp_x;
                            path_a_y[path_a_len] <= temp_y;
                            path_a_len <= path_a_len + 8'd1;
                            temp_y <= temp_y - 4'd1;
                        end
                    end
                    
                    // Add final point
                    path_a_x[path_a_len] <= ax2;
                    path_a_y[path_a_len] <= ay2;
                    path_a_len <= path_a_len + 8'd1;
                    
                    // Generate path B (horizontal then vertical)
                    path_b_len <= 8'd0;
                    temp_x <= bx1;
                    temp_y <= by1;
                    
                    // Horizontal segment
                    if (bx1 < bx2) begin
                        for (i = 0; i < (bx2 - bx1); i = i + 1) begin
                            path_b_x[path_b_len] <= temp_x;
                            path_b_y[path_b_len] <= temp_y;
                            path_b_len <= path_b_len + 8'd1;
                            temp_x <= temp_x + 4'd1;
                        end
                    end else if (bx1 > bx2) begin
                        for (i = 0; i < (bx1 - bx2); i = i + 1) begin
                            path_b_x[path_b_len] <= temp_x;
                            path_b_y[path_b_len] <= temp_y;
                            path_b_len <= path_b_len + 8'd1;
                            temp_x <= temp_x - 4'd1;
                        end
                    end
                    
                    // Vertical segment
                    if (by1 < by2) begin
                        for (i = 0; i < (by2 - by1); i = i + 1) begin
                            path_b_x[path_b_len] <= temp_x;
                            path_b_y[path_b_len] <= temp_y;
                            path_b_len <= path_b_len + 8'd1;
                            temp_y <= temp_y + 4'd1;
                        end
                    end else if (by1 > by2) begin
                        for (i = 0; i < (by1 - by2); i = i + 1) begin
                            path_b_x[path_b_len] <= temp_x;
                            path_b_y[path_b_len] <= temp_y;
                            path_b_len <= path_b_len + 8'd1;
                            temp_y <= temp_y - 4'd1;
                        end
                    end
                    
                    // Add final point
                    path_b_x[path_b_len] <= bx2;
                    path_b_y[path_b_len] <= by2;
                    path_b_len <= path_b_len + 8'd1;
                    
                    // Check for intersection
                    intersection_found <= 1'b0;
                    for (i = 0; i < path_a_len; i = i + 1) begin
                        for (j = 0; j < path_b_len; j = j + 1) begin
                            if (path_a_x[i] == path_b_x[j] && path_a_y[i] == path_b_y[j]) begin
                                intersection_found <= 1'b1;
                            end
                        end
                    end
                    
                    // Determine result
                    if (intersection_found) begin
                        possible <= 1'b0;
                        result <= 16'd0;
                    end else begin
                        possible <= 1'b1;
                        result <= dA + dB;
                    end
                    
                    state <= FINISH;
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