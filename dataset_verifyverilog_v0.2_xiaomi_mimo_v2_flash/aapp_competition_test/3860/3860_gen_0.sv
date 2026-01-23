module badge_decks (
    input [5:0] b,
    input [5:0] g,
    input [5:0] n,
    output [5:0] count
);

    wire [63:0] valid;
    wire [63:0] red_needed;
    wire [63:0] b_ge_k;
    wire [63:0] g_ge_red;
    wire [63:0] valid_temp;

    assign red_needed = ~n + 1; // 2's complement to represent 64 - n logic if needed, 
                                // but we need (n-k). We will compute (n-k) explicitly per bit.
    
    // To avoid wide subtraction in generate, we use helper logic.
    // Since n <= 63, we can use a generate block to iterate k from 0 to 63.
    // We only care about k <= 63.

    // We need to calculate (n - k) for each k. 
    // n - k = n + (-k). 
    // We can pre-calculate the subtraction or do it in the loop.
    
    // Let's calculate (n - k) for k in [0, 63].
    // Since k varies, we can't easily vectorize subtraction.
    // However, we can iterate.

    // Optimized approach: 
    // Valid if (k <= b) AND (n - k <= g).
    // (n - k) <= g  =>  n - g <= k.
    // So we need b >= k >= n - g.
    // Since k must also be between 0 and n.
    // So the range of valid k is [max(0, n-g), min(n, b)].
    // Count is max(0, min(n, b) - max(0, n-g) + 1).
    // This is purely combinational without loops.

    // Let's implement the mathematical solution directly.
    // Since inputs are 6 bits, we need to handle 7 bits for subtraction to avoid underflow.
    
    wire signed [6:0] b_s;
    wire signed [6:0] n_s;
    wire signed [6:0] g_s;
    wire signed [6:0] diff1;
    wire signed [6:0] diff2;
    wire signed [6:0] lower;
    wire signed [6:0] upper;
    wire signed [6:0] range;
    wire signed [6:0] count_s;

    assign b_s = {1'b0, b};
    assign n_s = {1'b0, n};
    assign g_s = {1'b0, g};

    // lower bound = max(0, n - g)
    assign diff1 = n_s - g_s; // Can be negative
    assign lower = (diff1 > 0) ? diff1 : 0;

    // upper bound = min(n, b)
    // We know n and b are non-negative, so min(n,b) is just less than.
    assign upper = (b_s < n_s) ? b_s : n_s;

    // range = upper - lower + 1
    assign range = upper - lower + 1;

    // count = range > 0 ? range : 0
    assign count_s = (range > 0) ? range : 0;

    // Clamp to 0 and 64. The logic above naturally handles negative range.
    // However, 'range' might be wider than 6 bits if we use signed arithmetic.
    // We cast back to 6 bits. The problem guarantees valid deck count <= n+1 <= 64.
    // So 6 bits [5:0] is sufficient.
    
    assign count = count_s[5:0];

endmodule