module goat_rope #(
    parameter N = 2,
    parameter COORD_WIDTH = 10,
    parameter DATA_WIDTH = 20,
    parameter RESULT_WIDTH = 32
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [COORD_WIDTH-1:0] x0,
    input wire [COORD_WIDTH-1:0] y0,
    input wire [COORD_WIDTH-1:0] x1,
    input wire [COORD_WIDTH-1:0] y1,
    input wire [COORD_WIDTH-1:0] x2,
    input wire [COORD_WIDTH-1:0] y2,
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd50;

    // Distance calculation registers
    reg [DATA_WIDTH-1:0] dx01, dy01, dist_sq01;
    reg [DATA_WIDTH-1:0] dx12, dy12, dist_sq12;
    reg [DATA_WIDTH-1:0] dx02, dy02, dist_sq02;
    reg [RESULT_WIDTH-1:0] dist01, dist12, dist02;
    reg [RESULT_WIDTH-1:0] sum_dist;

    // Integer square root function
    function [RESULT_WIDTH-1:0] int_sqrt(input [DATA_WIDTH*2-1:0] val);
        reg [RESULT_WIDTH-1:0] result;
        reg [RESULT_WIDTH-1:0] low, high, mid;
        reg [RESULT_WIDTH-1:0] mid_sq;
        
        begin
            low = 32'd0;
            high = val[DATA_WIDTH*2-1:DATA_WIDTH];
            result = 32'd0;
            
            while (low <= high) begin
                mid = (low + high) >> 1;
                mid_sq = mid * mid;
                
                if (mid_sq <= val) begin
                    result = mid;
                    low = mid + 32'd1;
                end else begin
                    high = mid - 32'd1;
                end
            end
            
            int_sqrt = result;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            dx01 <= 20'd0;
            dy01 <= 20'd0;
            dist_sq01 <= 20'd0;
            dx12 <= 20'd0;
            dy12 <= 20'd0;
            dist_sq12 <= 20'd0;
            dx02 <= 20'd0;
            dy02 <= 20'd0;
            dist_sq02 <= 20'd0;
            dist01 <= 32'd0;
            dist12 <= 32'd0;
            dist02 <= 32'd0;
            sum_dist <= 32'd0;
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
                    
                    // Calculate dx and dy for all pairs
                    dx01 <= (x0 > x1) ? (x0 - x1) : (x1 - x0);
                    dy01 <= (y0 > y1) ? (y0 - y1) : (y1 - y0);
                    dist_sq01 <= (dx01 * dx01) + (dy01 * dy01);
                    
                    if (N == 3) begin
                        dx12 <= (x1 > x2) ? (x1 - x2) : (x2 - x1);
                        dy12 <= (y1 > y2) ? (y1 - y2) : (y2 - y1);
                        dist_sq12 <= (dx12 * dx12) + (dy12 * dy12);
                        
                        dx02 <= (x0 > x2) ? (x0 - x2) : (x2 - x0);
                        dy02 <= (y0 > y2) ? (y0 - y2) : (y2 - y0);
                        dist_sq02 <= (dx02 * dx02) + (dy02 * dy02);
                    end
                    
                    // Calculate distances
                    dist01 <= int_sqrt({dist_sq01, 20'd0});
                    
                    if (N == 3) begin
                        dist12 <= int_sqrt({dist_sq12, 20'd0});
                        dist02 <= int_sqrt({dist_sq02, 20'd0});
                        sum_dist <= dist01 + dist12 + dist02;
                        result <= sum_dist / 2;
                    end else begin
                        result <= dist01;
                    end
                    
                    // Exit conditions
                    if (cycle_count >= MAX_CYCLES || (N == 2 && dist01 != 0) || (N == 3 && sum_dist != 0)) begin
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