module gcd_distinct_counter(
    input [3:0] n,
    input [15:0] a [0:3],
    output reg [3:0] distinct_count
);

    // GCD function using combinational Euclidean algorithm
    function automatic [15:0] gcd;
        input [15:0] aa;
        input [15:0] bb;
        integer i;
        reg [15:0] a_temp;
        reg [15:0] b_temp;
        reg [15:0] temp;
    begin
        a_temp = aa;
        b_temp = bb;
        // Fixed 16 iterations max for 16-bit numbers
        for (i = 0; i < 16; i = i + 1) begin
            if (b_temp != 16'd0) begin
                temp = a_temp % b_temp;
                a_temp = b_temp;
                b_temp = temp;
            end
        end
        gcd = a_temp;
    end
    endfunction

    // Combinational logic for GCD computation of subarrays
    reg [15:0] gcd_00, gcd_01, gcd_02, gcd_03;
    reg [15:0] gcd_11, gcd_12, gcd_13;
    reg [15:0] gcd_22, gcd_23;
    reg [15:0] gcd_33;
    
    reg [15:0] gcd_buffer [0:9]; // 10 elements buffer
    reg [9:0] valid_gcd; // Indicates valid GCDs based on n
    
    always @(*) begin
        // Compute GCDs based on valid n (1-4)
        // Initialize buffer to avoid latch
        gcd_00 = 16'd0; gcd_01 = 16'd0; gcd_02 = 16'd0; gcd_03 = 16'd0;
        gcd_11 = 16'd0; gcd_12 = 16'd0; gcd_13 = 16'd0;
        gcd_22 = 16'd0; gcd_23 = 16'd0;
        gcd_33 = 16'd0;
        
        valid_gcd = 10'b0;
        
        // n=1: only [0:0]
        if (n >= 1) begin
            gcd_00 = a[0];
            valid_gcd[0] = 1'b1;
        end
        
        // n=2: add [0:1], [1:1]
        if (n >= 2) begin
            gcd_01 = gcd(a[0], a[1]);
            gcd_11 = a[1];
            valid_gcd[1] = 1'b1;
            valid_gcd[4] = 1'b1;
        end
        
        // n=3: add [0:2], [1:2], [2:2]
        if (n >= 3) begin
            gcd_02 = gcd(a[0], gcd(a[1], a[2]));
            gcd_12 = gcd(a[1], a[2]);
            gcd_22 = a[2];
            valid_gcd[2] = 1'b1;
            valid_gcd[5] = 1'b1;
            valid_gcd[7] = 1'b1;
        end
        
        // n=4: add [0:3], [1:3], [2:3], [3:3]
        if (n >= 4) begin
            gcd_03 = gcd(a[0], gcd(a[1], gcd(a[2], a[3])));
            gcd_13 = gcd(a[1], gcd(a[2], a[3]));
            gcd_23 = gcd(a[2], a[3]);
            gcd_33 = a[3];
            valid_gcd[3] = 1'b1;
            valid_gcd[6] = 1'b1;
            valid_gcd[8] = 1'b1;
            valid_gcd[9] = 1'b1;
        end
        
        // Fill buffer
        gcd_buffer[0] = gcd_00;
        gcd_buffer[1] = gcd_01;
        gcd_buffer[2] = gcd_02;
        gcd_buffer[3] = gcd_03;
        gcd_buffer[4] = gcd_11;
        gcd_buffer[5] = gcd_12;
        gcd_buffer[6] = gcd_13;
        gcd_buffer[7] = gcd_22;
        gcd_buffer[8] = gcd_23;
        gcd_buffer[9] = gcd_33;
    end
    
    // Distinct count logic
    reg [3:0] count;
    reg [0:9] is_unique; // 1 if element at index is unique
    integer i, j;
    
    always @(*) begin
        is_unique = 10'b0;
        
        // For each valid GCD, check if it's unique
        for (i = 0; i < 10; i = i + 1) begin
            if (valid_gcd[i]) begin
                // Check if same value exists in any previous valid index
                is_unique[i] = 1'b1;
                for (j = 0; j < i; j = j + 1) begin
                    if (valid_gcd[j] && (gcd_buffer[j] == gcd_buffer[i])) begin
                        is_unique[i] = 1'b0;
                    end
                end
            end
        end
        
        // Count unique values
        count = 4'd0;
        for (i = 0; i < 10; i = i + 1) begin
            if (is_unique[i]) begin
                count = count + 4'd1;
            end
        end
    end
    
    assign distinct_count = count;

endmodule