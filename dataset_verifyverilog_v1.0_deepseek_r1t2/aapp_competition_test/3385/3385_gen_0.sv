module HalloweenCostumes #(
    parameter MAX_N = 8
) (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [MAX_N-1:0] mask_0,
    input [MAX_N-1:0] mask_1,
    input [MAX_N-1:0] mask_2,
    input [MAX_N-1:0] mask_3,
    input [MAX_N-1:0] mask_4,
    input [MAX_N-1:0] mask_5,
    input [MAX_N-1:0] mask_6,
    input [MAX_N-1:0] mask_7,
    input x_0,
    input x_1,
    input x_2,
    input x_3,
    input x_4,
    input x_5,
    input x_6,
    input x_7,
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
    reg [MAX_N-1:0] masks [0:7];
    reg x_vals [0:7];
    
    reg [3:0] popcount [0:255];
    integer k, b;
    
    initial begin
        for (k = 0; k < 256; k = k + 1) begin
            popcount[k] = 0;
            for (b = 0; b < MAX_N; b = b + 1)
                popcount[k] = popcount[k] + k[b];
        end
    end
    
    always @(posedge clk) begin
        masks[0] <= mask_0;
        masks[1] <= mask_1;
        masks[2] <= mask_2;
        masks[3] <= mask_3;
        masks[4] <= mask_4;
        masks[5] <= mask_5;
        masks[6] <= mask_6;
        masks[7] <= mask_7;
        
        x_vals[0] <= x_0;
        x_vals[1] <= x_1;
        x_vals[2] <= x_2;
        x_vals[3] <= x_3;
        x_vals[4] <= x_4;
        x_vals[5] <= x_5;
        x_vals[6] <= x_6;
        x_vals[7] <= x_7;
    end
    
    wire [MAX_N-1:0] masked;
    assign masked = masks[i] & assignment;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            count <= 32'd0;
            assignment <= {MAX_N{1'b0}};
            i <= 4'd0;
            
            // Initialize arrays
            for (integer idx = 0; idx < 8; idx = idx + 1) begin
                masks[idx] <= {MAX_N{1'b0}};
                x_vals[idx] <= 1'b0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        count <= 32'd0;
                        assignment <= {MAX_N{1'b0}};
                        i <= 4'd0;
                        next_state <= CHECK;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                CHECK: begin
                    if (assignment >= (32'd1 << n)) begin
                        result <= count;
                        next_state <= DONE_STATE;
                    end else if (i >= n) begin
                        count <= count + 32'd1;
                        next_state <= NEXT;
                    end else begin
                        if ((popcount[masked] % 2) != x_vals[i]) begin
                            next_state <= NEXT;
                        end else begin
                            i <= i + 4'd1;
                            next_state <= CHECK;
                        end
                    end
                end
                
                NEXT: begin
                    assignment <= assignment + 1'b1;
                    i <= 4'd0;
                    next_state <= CHECK;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule