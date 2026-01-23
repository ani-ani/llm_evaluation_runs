module goat_rope #(
    parameter N = 2,
    COORD_WIDTH = 10,
    DATA_WIDTH = 20,
    RESULT_WIDTH = 32
) (
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
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] INIT         = 4'd1;
    localparam [3:0] CALC_DX_DY   = 4'd2;
    localparam [3:0] CALC_SQ      = 4'd3;
    localparam [3:0] CALC_SCALE   = 4'd4;
    localparam [3:0] CALC_SQRT    = 4'd5;
    localparam [3:0] STORE        = 4'd6;
    localparam [3:0] POST_PROCESS = 4'd7;
    localparam [3:0] FINISH       = 4'd8;

    reg [3:0] state, next_state;
    reg [1:0] pair_index;
    reg [COORD_WIDTH-1:0] dx, dy;
    reg [DATA_WIDTH-1:0] sq_dist;
    wire [33:0] scaled_sq;
    reg [31:0] current_dist;
    reg [31:0] dist01;
    reg [31:0] dist12;
    reg [31:0] dist02;

    // Integer sqrt function
    function automatic [31:0] integer_sqrt;
        input [33:0] num;
        reg [31:0] res;
        reg [31:0] bit;
        reg [33:0] temp1, temp2;
        integer i;
        begin
            res = 32'd0;
            bit = 32'd1 << 31;
            temp1 = num;
            
            for (i = 0; i < 32; i = i + 1) begin
                temp2 = res | bit;
                if (temp2 <= temp1) begin
                    temp1 = temp1 - temp2;
                    res = res + (bit << 1);
                end
                res = res >> 1;
                bit = bit >> 2;
            end
            integer_sqrt = res;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            pair_index <= 2'd0;
            dist01 <= 32'd0;
            dist12 <= 32'd0;
            dist02 <= 32'd0;
            dx <= 10'd0;
            dy <= 10'd0;
            sq_dist <= 20'd0;
            current_dist <= 32'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= result;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                INIT: begin
                    pair_index <= 2'd0;
                    next_state <= CALC_DX_DY;
                end
                
                CALC_DX_DY: begin
                    case (pair_index)
                        2'd0: begin
                            dx <= (x0 >= x1) ? (x0 - x1) : (x1 - x0);
                            dy <= (y0 >= y1) ? (y0 - y1) : (y1 - y0);    
                        end
                        2'd1: begin
                            dx <= (x1 >= x2) ? (x1 - x2) : (x2 - x1);
                            dy <= (y1 >= y2) ? (y1 - y2) : (y2 - y1);
                        end
                        2'd2: begin
                            dx <= (x0 >= x2) ? (x0 - x2) : (x2 - x0);
                            dy <= (y0 >= y2) ? (y0 - y2) : (y2 - y0);
                        end
                        default: begin
                            dx <= 10'd0;
                            dy <= 10'd0;
                        end
                    endcase
                    next_state <= CALC_SQ;
                end
                
                CALC_SQ: begin
                    sq_dist <= (dx * dx) + (dy * dy);
                    next_state <= CALC_SCALE;
                end
                
                CALC_SCALE: begin
                    scaled_sq = sq_dist * 20'd10000;
                    next_state <= CALC_SQRT;
                end
                
                CALC_SQRT: begin
                    current_dist <= integer_sqrt(scaled_sq);
                    next_state <= STORE;
                end
                
                STORE: begin
                    case (pair_index)
                        2'd0: dist01 <= current_dist;
                        2'd1: dist12 <= current_dist;
                        2'd2: dist02 <= current_dist;
                    endcase
                    
                    if ((N == 2 && pair_index == 2'd0) || (N == 3 && pair_index == 2'd2)) begin
                        next_state <= POST_PROCESS;
                    end else begin
                        pair_index <= pair_index + 2'd1;
                        next_state <= CALC_DX_DY;
                    end
                end
                
                POST_PROCESS: begin
                    if (N == 2) begin
                        result <= dist01;
                    end else begin
                        result <= (dist01 + dist12 + dist02) >> 1;
                    end
                    next_state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

    always @(*) begin
        case (state)
            IDLE:         next_state = start ? INIT : IDLE;
            INIT:         next_state = CALC_DX_DY;
            CALC_DX_DY:   next_state = CALC_SQ;
            CALC_SQ:      next_state = CALC_SCALE;
            CALC_SCALE:   next_state = CALC_SQRT;
            CALC_SQRT:    next_state = STORE;
            STORE:        next_state = ((N == 2 && pair_index == 2'd0) || (N == 3 && pair_index == 2'd2)) ? POST_PROCESS : CALC_DX_DY;
            POST_PROCESS: next_state = FINISH;
            FINISH:       next_state = IDLE;
            default:      next_state = IDLE;
        endcase
    end
endmodule