module HalloweenCostumes #(
    parameter MAX_N = 8
) (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [MAX_N-1:0] mask_0, mask_1, mask_2, mask_3,
                      mask_4, mask_5, mask_6, mask_7,
    input x_0, x_1, x_2, x_3, x_4, x_5, x_6, x_7,
    output reg [31:0] result,
    output reg done
);
    
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] NEXT = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;
    
    reg [1:0] state, next_state;
    reg [MAX_N-1:0] assignment;
    reg [31:0] count;
    reg [3:0] i;
    reg [MAX_N-1:0] masks [0:MAX_N-1];
    reg x_vals [0:MAX_N-1];
    
    reg [3:0] popcount [0:255];
    integer k, b;
    
    initial begin
        for (k = 0; k < 256; k = k + 1) begin
            integer c = 0;
            for (b = 0; b < 8; b = b + 1)
                if (k[b]) c = c + 1;
            popcount[k] = c;
        end
    end
    
    always @(posedge clk) begin
        masks[0] <= mask_0; x_vals[0] <= x_0;
        masks[1] <= mask_1; x_vals[1] <= x_1;
        masks[2] <= mask_2; x_vals[2] <= x_2;
        masks[3] <= mask_3; x_vals[3] <= x_3;
        masks[4] <= mask_4; x_vals[4] <= x_4;
        masks[5] <= mask_5; x_vals[5] <= x_5;
        masks[6] <= mask_6; x_vals[6] <= x_6;
        masks[7] <= mask_7; x_vals[7] <= x_7;
    end
    
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK;
                end else begin
                    next_state = IDLE;
                end
            end
            CHECK: begin
                if (assignment >= (1 << n)) begin
                    next_state = DONE_STATE;
                end else if (i >= n) begin
                    next_state = NEXT;
                end else begin
                    if (popcount[assignment & masks[i]] & 1 != x_vals[i]) begin
                        next_state = NEXT;
                    end else begin
                        next_state = CHECK;
                    end
                end
            end
            NEXT: begin
                next_state = CHECK;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            count <= 32'd0;
            assignment <= {MAX_N{1'b0}};
            i <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                CHECK: begin
                    if (assignment >= (1 << n)) begin
                        result <= count;
                    end else if (i >= n) begin
                        count <= count + 32'd1;
                    end
                end
                NEXT: begin
                    assignment <= assignment + 1'b1;
                    i <= 4'd0;
                end
                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule