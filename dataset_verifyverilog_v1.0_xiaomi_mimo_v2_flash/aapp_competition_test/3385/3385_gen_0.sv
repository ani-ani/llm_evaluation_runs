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
    localparam [1:0] DONE = 2'd3;
    
    reg [1:0] state;
    reg [MAX_N-1:0] assignment;
    reg [31:0] count;
    reg [3:0] i;
    reg [MAX_N-1:0] masks [0:MAX_N-1];
    reg x_vals [0:MAX_N-1];
    wire [MAX_N-1:0] masked;
    assign masked = assignment & masks[i];
    
    // Precompute popcount for all 256 possible 8-bit values
    reg [3:0] popcount [0:255];
    integer k;
    integer b;
    integer c;
    
    initial begin
        for (k = 0; k < 256; k = k + 1) begin
            c = 0;
            for (b = 0; b < 8; b = b + 1) begin
                if (k[b]) c = c + 1;
            end
            popcount[k] = c;
        end
    end
    
    // Register the inputs
    always @(posedge clk) begin
        masks[0] <= mask_0;
        x_vals[0] <= x_0;
        masks[1] <= mask_1;
        x_vals[1] <= x_1;
        masks[2] <= mask_2;
        x_vals[2] <= x_2;
        masks[3] <= mask_3;
        x_vals[3] <= x_3;
        masks[4] <= mask_4;
        x_vals[4] <= x_4;
        masks[5] <= mask_5;
        x_vals[5] <= x_5;
        masks[6] <= mask_6;
        x_vals[6] <= x_6;
        masks[7] <= mask_7;
        x_vals[7] <= x_7;
    end
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            count <= 32'd0;
            assignment <= {MAX_N{1'b0}};
            i <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        count <= 32'd0;
                        assignment <= {MAX_N{1'b0}};
                        i <= 4'd0;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    // Check if we've tried all assignments
                    if (assignment >= (1 << n)) begin
                        result <= count;
                        state <= DONE;
                    end
                    // Check if we've validated all constraints for this assignment
                    else if (i >= n) begin
                        count <= count + 32'd1;
                        state <= NEXT;
                    end
                    // Check current constraint
                    else begin
                        if (popcount[masked] & 1 != x_vals[i]) begin
                            state <= NEXT; // Skip this assignment
                        end else begin
                            i <= i + 4'd1; // Continue to next constraint
                        end
                    end
                end
                
                NEXT: begin
                    assignment <= assignment + {{(MAX_N-1){1'b0}}, 1'b1};
                    i <= 4'd0;
                    state <= CHECK;
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule