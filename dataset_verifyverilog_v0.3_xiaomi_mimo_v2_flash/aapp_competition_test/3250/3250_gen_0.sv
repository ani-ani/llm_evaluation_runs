module divisibility_hack_checker(
    input [3:0] b,
    input [3:0] d,
    output reg yes_no
);
    always @(*) begin
        // Initialize output
        yes_no = 1'b0;
        
        // Case statement based on b value (small primes: 2,3,5,7,11,13)
        // Using precomputed divisibility results for each b
        case (b)
            4'd2: begin  // Check divisibility by 2
                if (d % 2 == 0) yes_no = 1'b1;
            end
            4'd3: begin  // Check divisibility by 3
                if (d % 3 == 0) yes_no = 1'b1;
            end
            4'd5: begin  // Check divisibility by 5
                if (d % 5 == 0) yes_no = 1'b1;
            end
            4'd7: begin  // Check divisibility by 7
                if (d % 7 == 0) yes_no = 1'b1;
            end
            4'd11: begin // Check divisibility by 11
                if (d % 11 == 0) yes_no = 1'b1;
            end
            4'd13: begin // Check divisibility by 13
                if (d % 13 == 0) yes_no = 1'b1;
            end
            default: yes_no = 1'b0;  // For any other b value
        endcase
    end
endmodule