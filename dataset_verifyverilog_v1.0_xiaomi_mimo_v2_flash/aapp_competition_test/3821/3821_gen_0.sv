module optimize_friends (
    input clk,
    input rst_n,
    input start,
    input [2:0] n,
    input [15:0] p0, p1, p2, p3, p4, p5, p6, p7,
    output reg [31:0] result,
    output reg done
);

// State declarations
localparam [2:0] IDLE  = 3'd0;
localparam [2:0] CHECK = 3'd1;
localparam [2:0] SORT  = 3'd2;
localparam [2:0] INIT  = 3'd3;
localparam [2:0] LOOP  = 3'd4;
localparam [2:0] DONE  = 3'd5;

reg [2:0] state;

// Registers for computation
reg [31:0] prob [0:7];
reg [31:0] s;
reg [31:0] p;
reg [31:0] a;
reg [2:0] i;  // Outer loop counter
reg [2:0] j;  // Bubble sort outer counter
reg [2:0] k;  // Bubble sort inner counter

// Constants
localparam [31:0] ONE = 32'h00010000;  // 1.0 in Q16.16
localparam [31:0] MAX_VAL = 32'hFFFFFFFF;

// Multiplier outputs (64-bit)
wire [63:0] product1;  // s * (one - a)
wire [63:0] product2;  // a * p
wire [63:0] product3;  // p * (one - a)

// Multiplier operations
assign product1 = s * (ONE - a);
assign product2 = a * p;
assign product3 = p * (ONE - a);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 32'd0;
        done <= 1'b0;
        i <= 3'd0;
        j <= 3'd0;
        k <= 3'd0;
        s <= 32'd0;
        p <= 32'd0;
        a <= 32'd0;
        // Initialize prob array
        prob[0] <= 32'd0;
        prob[1] <= 32'd0;
        prob[2] <= 32'd0;
        prob[3] <= 32'd0;
        prob[4] <= 32'd0;
        prob[5] <= 32'd0;
        prob[6] <= 32'd0;
        prob[7] <= 32'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Load inputs into Q16.16 format
                    prob[0] <= {p0, 16'b0};
                    prob[1] <= {p1, 16'b0};
                    prob[2] <= {p2, 16'b0};
                    prob[3] <= {p3, 16'b0};
                    prob[4] <= {p4, 16'b0};
                    prob[5] <= {p5, 16'b0};
                    prob[6] <= {p6, 16'b0};
                    prob[7] <= {p7, 16'b0};
                    state <= CHECK;
                end
            end
            
            CHECK: begin
                // Check if any probability is 1.0
                if ((p0 == 16'hFFFF) || (p1 == 16'hFFFF) || (p2 == 16'hFFFF) || (p3 == 16'hFFFF) ||
                    (p4 == 16'hFFFF) || (p5 == 16'hFFFF) || (p6 == 16'hFFFF) || (p7 == 16'hFFFF)) begin
                    result <= MAX_VAL;
                    done <= 1'b1;
                    state <= IDLE;
                end else begin
                    state <= SORT;
                    j <= 3'd0;
                    k <= 3'd0;
                end
            end
            
            SORT: begin
                // Bubble sort to sort probabilities descending
                if (j < n) begin
                    if (k < (n - j - 3'd1)) begin
                        if (prob[k] < prob[k + 3'd1]) begin
                            // Swap
                            prob[k] <= prob[k + 3'd1];
                            prob[k + 3'd1] <= prob[k];
                        end
                        k <= k + 3'd1;
                    end else begin
                        k <= 3'd0;
                        j <= j + 3'd1;
                    end
                end else begin
                    state <= INIT;
                    i <= n - 3'd2;  // Start with second-to-last element
                end
            end
            
            INIT: begin
                s <= prob[n - 3'd1];  // s = min(p)
                p <= ONE - prob[n - 3'd1];  // p = 1 - min(p)
                state <= LOOP;
            end
            
            LOOP: begin
                if (i >= 3'd0) begin
                    a <= prob[i];
                    // Update if s < (one - a) + a*p
                    // product1 = s * (one - a), take upper 32 bits for division by ONE
                    // product2 = a * p, take upper 32 bits
                    if (((product1 + product2) >> 32) > s) begin
                        s <= (product1 + product2) >> 32;
                        p <= product3 >> 32;
                    end
                    i <= i - 3'd1;
                end else begin
                    state <= DONE;
                    result <= s;
                    done <= 1'b1;
                end
            end
            
            DONE: begin
                // Return to idle after one cycle
                state <= IDLE;
                done <= 1'b0;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule