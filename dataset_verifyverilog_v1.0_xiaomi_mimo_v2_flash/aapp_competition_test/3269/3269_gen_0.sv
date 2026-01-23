module distance_calculator (
    input [3:0] a0, a1, a2, a3,
    input [3:0] b0, b1, b2, b3,
    output [7:0] dist
);

    wire [3:0] diff0;
    wire [3:0] diff1;
    wire [3:0] diff2;
    wire [3:0] diff3;
    wire [7:0] temp_sum;

    // Calculate absolute differences for each digit pair
    assign diff0 = (a0 >= b0) ? (a0 - b0) : (b0 - a0);
    assign diff1 = (a1 >= b1) ? (a1 - b1) : (b1 - a1);
    assign diff2 = (a2 >= b2) ? (a2 - b2) : (b2 - a2);
    assign diff3 = (a3 >= b3) ? (a3 - b3) : (b3 - a3);

    // Sum all differences
    assign temp_sum = {4'd0, diff0} + {4'd0, diff1} + {4'd0, diff2} + {4'd0, diff3};
    
    // Output the sum (max value: 9*4 = 36, fits in 8 bits)
    assign dist = temp_sum;

endmodule