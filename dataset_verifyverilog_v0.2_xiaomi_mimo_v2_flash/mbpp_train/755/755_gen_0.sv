module second_smallest(
    input [15:0] in0,
    input [15:0] in1,
    input [15:0] in2,
    input [15:0] in3,
    input [15:0] in4,
    input [15:0] in5,
    input [15:0] in6,
    input [15:0] in7,
    output reg [15:0] result
);
    // Intermediate sorted values
    reg [15:0] s0, s1, s2, s3, s4, s5, s6, s7;
    // Comparator-swap helper function
    function automatic void cmp_swap;
        inout [15:0] a;
        inout [15:0] b;
        begin
            if ($signed(a) > $signed(b)) begin
                cmp_swap = a;
                a = b;
                b = cmp_swap;
            end
        end
    endfunction

    always @(*) begin
        // Initialize stage 0
        s0 = in0;
        s1 = in1;
        s2 = in2;
        s3 = in3;
        s4 = in4;
        s5 = in5;
        s6 = in6;
        s7 = in7;

        // Odd-Even Transposition Sort Network (4 passes for 8 elements)
        // Pass 1 (Odd indices)
        cmp_swap(s1, s2);
        cmp_swap(s3, s4);
        cmp_swap(s5, s6);
        // Pass 2 (Even indices)
        cmp_swap(s0, s1);
        cmp_swap(s2, s3);
        cmp_swap(s4, s5);
        cmp_swap(s6, s7);
        // Pass 3 (Odd indices)
        cmp_swap(s1, s2);
        cmp_swap(s3, s4);
        cmp_swap(s5, s6);
        // Pass 4 (Even indices)
        cmp_swap(s0, s1);
        cmp_swap(s2, s3);
        cmp_swap(s4, s5);
        cmp_swap(s6, s7);

        // Logic to find second smallest unique value
        result = 16'hFFFF; // Default: not found
        
        // Check S[1]
        if ($signed(s1) > $signed(s0)) result = s1;
        // Check S[2] if result not found
        else if ($signed(s2) > $signed(s0)) result = s2;
        // Check S[3]
        else if ($signed(s3) > $signed(s0)) result = s3;
        // Check S[4]
        else if ($signed(s4) > $signed(s0)) result = s4;
        // Check S[5]
        else if ($signed(s5) > $signed(s0)) result = s5;
        // Check S[6]
        else if ($signed(s6) > $signed(s0)) result = s6;
        // Check S[7]
        else if ($signed(s7) > $signed(s0)) result = s7;
    end

endmodule
