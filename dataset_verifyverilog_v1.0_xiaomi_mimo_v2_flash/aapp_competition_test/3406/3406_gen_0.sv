module castle_danger (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    input wire [7:0] p0_x, p0_y,
    input wire [7:0] p1_x, p1_y,
    input wire [7:0] p2_x, p2_y,
    input wire [7:0] p3_x, p3_y,
    
    input wire [7:0] castle_x, castle_y,
    
    output reg danger,
    output reg done
);

localparam [1:0] IDLE = 2'd0;
localparam [1:0] CHECK = 2'd1;
localparam [1:0] DONE = 2'd2;

reg [1:0] state;
reg [1:0] edge_idx;
reg signed [15:0] cross;
reg is_inside;
reg first_sign;
reg degenerate;
reg signed [15:0] dx1, dy1, dx2, dy2;
reg signed [15:0] edge_dx, edge_dy;
reg signed [15:0] castle_dx, castle_dy;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        danger <= 1'b0;
        done <= 1'b0;
        is_inside <= 1'b0;
        degenerate <= 1'b0;
        edge_idx <= 2'd0;
        dx1 <= 16'd0;
        dy1 <= 16'd0;
        dx2 <= 16'd0;
        dy2 <= 16'd0;
        edge_dx <= 16'd0;
        edge_dy <= 16'd0;
        castle_dx <= 16'd0;
        castle_dy <= 16'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                danger <= 1'b0;
                if (start) begin
                    state <= CHECK;
                    edge_idx <= 2'd0;
                    is_inside <= 1'b1;
                    degenerate <= 1'b0;
                end
            end
            
            CHECK: begin
                case (edge_idx)
                    2'd0: begin
                        edge_dx <= {8'd0, p1_x} - {8'd0, p0_x};
                        edge_dy <= {8'd0, p1_y} - {8'd0, p0_y};
                        castle_dx <= {8'd0, castle_x} - {8'd0, p0_x};
                        castle_dy <= {8'd0, castle_y} - {8'd0, p0_y};
                    end
                    2'd1: begin
                        edge_dx <= {8'd0, p2_x} - {8'd0, p1_x};
                        edge_dy <= {8'd0, p2_y} - {8'd0, p1_y};
                        castle_dx <= {8'd0, castle_x} - {8'd0, p1_x};
                        castle_dy <= {8'd0, castle_y} - {8'd0, p1_y};
                    end
                    2'd2: begin
                        edge_dx <= {8'd0, p3_x} - {8'd0, p2_x};
                        edge_dy <= {8'd0, p3_y} - {8'd0, p2_y};
                        castle_dx <= {8'd0, castle_x} - {8'd0, p2_x};
                        castle_dy <= {8'd0, castle_y} - {8'd0, p2_y};
                    end
                    2'd3: begin
                        edge_dx <= {8'd0, p0_x} - {8'd0, p3_x};
                        edge_dy <= {8'd0, p0_y} - {8'd0, p3_y};
                        castle_dx <= {8'd0, castle_x} - {8'd0, p3_x};
                        castle_dy <= {8'd0, castle_y} - {8'd0, p3_y};
                    end
                endcase
                state <= 2'd2;
            end
            
            2'd2: begin
                cross <= (edge_dx * castle_dy) - (edge_dy * castle_dx);
                
                if (edge_idx == 2'd0) begin
                    dx1 <= edge_dx;
                    dy1 <= edge_dy;
                end else if (edge_idx == 2'd1) begin
                    dx2 <= edge_dx;
                    dy2 <= edge_dy;
                end
                
                state <= 2'd3;
            end
            
            2'd3: begin
                if (edge_idx == 2'd0) begin
                    if (cross != 16'd0) first_sign <= cross[15];
                    
                    if (((dx1 * dy2) - (dy1 * dx2)) == 16'd0) begin
                        degenerate <= 1'b1;
                    end
                end else begin
                    if (cross != 16'd0 && cross[15] != first_sign) begin
                        is_inside <= 1'b0;
                    end
                end
                
                if (edge_idx < 2'd3) begin
                    edge_idx <= edge_idx + 1'd1;
                    state <= CHECK;
                end else begin
                    if (degenerate) begin
                        danger <= 1'b0;
                    end else begin
                        danger <= is_inside;
                    end
                    state <= DONE;
                end
            end
            
            DONE: begin
                done <= 1'b1;
                if (!start) state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule