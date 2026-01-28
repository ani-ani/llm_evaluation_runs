module oven_decision (
    input [9:0] n,   // Number of cakes needed (1-1000)
    input [9:0] t,   // Time to bake k cakes (1-1000)
    input [9:0] k,   // Cakes per batch (1-1000)
    input [9:0] d,   // Time to build second oven (1-1000)
    output reg reason // 1 if building oven is reasonable, 0 otherwise
);

    // Calculate number of batches needed: ceil(n/k)
    wire [9:0] batches = (n + k - 1) / k;
    
    // Calculate threshold time: (batches - 1) * t
    wire [19:0] threshold = (batches - 1) * t;
    
    // Decision logic: YES if d < threshold
    always @(*) begin
        reason = (d < threshold) ? 1'b1 : 1'b0;
    end

endmodule