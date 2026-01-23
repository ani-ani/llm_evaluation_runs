module cookie_wall (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [31:0] omega,
    input wire [31:0] v0,
    input wire [31:0] theta,
    input wire [31:0] w,
    input wire [31:0] x0, x1, x2, x3, x4, x5, x6, x7,
    input wire [31:0] y0, y1, y2, y3, y4, y5, y6, y7,
    output reg [3:0] result_index,
    output reg [31:0] result_time,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] vertex_counter;
    reg [31:0] time_reg;
    reg [31:0] best_time;
    reg [3:0] best_index;
    reg found;
    
    reg [31:0] com_x, com_y;
    reg [31:0] v0x, v0y;
    reg [31:0] dx [0:7];
    reg [31:0] dy [0:7];
    reg [31:0] angle;
    reg [31:0] cos_phi, sin_phi;
    reg [31:0] x_com_pos;
    reg [31:0] y_com_pos;
    reg [31:0] x_vertex;
    
    localparam [31:0] MAX_TIME = 32'd600 * 65536;
    localparam [31:0] TIME_STEP = 32'd100 * 65536 / 1000;
    localparam [31:0] G = 32'd981 * 65536 / 100;
    localparam [31:0] PI_TIMES_2 = 32'd62831853 / 1000000;
    
    function automatic [31:0] mul_fp;
        input [31:0] a, b;
        begin
            mul_fp = (a * b) >> 16;
        end
    endfunction
    
    function automatic [31:0] div_fp;
        input [31:0] a, b;
        begin
            div_fp = (a << 16) / b;
        end
    endfunction
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            found <= 1'b0;
            time_reg <= 32'd0;
            best_time <= 32'h7FFFFFFF;
            best_index <= 4'd0;
            vertex_counter <= 4'd0;
            com_x <= 32'd0;
            com_y <= 32'd0;
            v0x <= 32'd0;
            v0y <= 32'd0;
            angle <= 32'd0;
            cos_phi <= 32'd0;
            sin_phi <= 32'd0;
            x_com_pos <= 32'd0;
            y_com_pos <= 32'd0;
            x_vertex <= 32'd0;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                found <= 1'b0;
                if (start) begin
                    next_state = COMPUTE;
                    vertex_counter = 4'd0;
                    com_x = 32'd0;
                    com_y = 32'd0;
                end else begin
                    next_state = IDLE;
                end
            end
            
            COMPUTE: begin
                if (vertex_counter == n - 1) begin
                    com_x = div_fp(com_x, {n, 16'h0});
                    com_y = div_fp(com_y, {n, 16'h0});
                    vertex_counter = 4'd0;
                    next_state = COMPUTE;
                end else begin
                    case (vertex_counter)
                        4'd0: begin com_x = x0; com_y = y0; end
                        4'd1: begin com_x = com_x + x1; com_y = com_y + y1; end
                        4'd2: begin com_x = com_x + x2; com_y = com_y + y2; end
                        4'd3: begin com_x = com_x + x3; com_y = com_y + y3; end
                        4'd4: begin com_x = com_x + x4; com_y = com_y + y4; end
                        4'd5: begin com_x = com_x + x5; com_y = com_y + y5; end
                        4'd6: begin com_x = com_x + x6; com_y = com_y + y6; end
                        4'd7: begin com_x = com_x + x7; com_y = com_y + y7; end
                    endcase
                    vertex_counter = vertex_counter + 4'd1;
                    next_state = COMPUTE;
                end
            end
            
            DONE_STATE: begin
                result_index = best_index;
                result_time = best_time;
                done = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
endmodule