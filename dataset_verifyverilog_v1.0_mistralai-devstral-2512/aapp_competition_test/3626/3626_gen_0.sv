module rectangle_intersection(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire signed [31:0] rect_x1 [0:7],
    input wire signed [31:0] rect_y1 [0:7],
    input wire signed [31:0] rect_x2 [0:7],
    input wire signed [31:0] rect_y2 [0:7],
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECKING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state, next_state;
    
    // Counters for rectangle indices
    reg [3:0] i, j;
    reg [3:0] next_i, next_j;
    
    // Internal signals
    reg intersection_found;
    reg next_intersection_found;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 4'd0;
            j <= 4'd0;
            intersection_found <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            i <= next_i;
            j <= next_j;
            intersection_found <= next_intersection_found;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        next_i = i;
        next_j = j;
        next_intersection_found = intersection_found;
        done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECKING;
                    next_i = 4'd0;
                    next_j = 4'd1;
                    next_intersection_found = 1'b0;
                end
            end
            
            CHECKING: begin
                // Check if current pair intersects
                wire signed [31:0] x1_i = rect_x1[i];
                wire signed [31:0] y1_i = rect_y1[i];
                wire signed [31:0] x2_i = rect_x2[i];
                wire signed [31:0] y2_i = rect_y2[i];
                wire signed [31:0] x1_j = rect_x1[j];
                wire signed [31:0] y1_j = rect_y1[j];
                wire signed [31:0] x2_j = rect_x2[j];
                wire signed [31:0] y2_j = rect_y2[j];
                
                wire no_intersect = (x2_i <= x1_j) | (x1_i >= x2_j) | (y2_i <= y1_j) | (y1_i >= y2_j);
                wire current_intersect = ~no_intersect;
                
                // Update intersection flag
                next_intersection_found = intersection_found | current_intersect;
                
                // Move to next pair
                if (j == n - 4'd1) begin
                    if (i == n - 4'd2) begin
                        next_state = DONE_STATE;
                    end else begin
                        next_i = i + 4'd1;
                        next_j = next_i + 4'd1;
                    end
                end else begin
                    next_j = j + 4'd1;
                end
            end
            
            DONE_STATE: begin
                result = intersection_found;
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
                next_i = 4'd0;
                next_j = 4'd0;
                next_intersection_found = 1'b0;
            end
        endcase
    end
    
    // Default assignments for outputs
    always @(*) begin
        if (state == DONE_STATE) begin
            result = intersection_found;
            done = 1'b1;
        end else begin
            done = 1'b0;
        end
    end

endmodule