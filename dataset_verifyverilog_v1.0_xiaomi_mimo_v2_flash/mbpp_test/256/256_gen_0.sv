module prime_counter (
    input [5:0] n,
    output reg [7:0] result,
    output reg valid
);

    // Pre-computed prime count lookup table
    // For n = 0 to 64, count of primes strictly less than n
    // For n > 64, we clamp to n = 64
    // All values calculated offline for simplicity
    always @(*) begin
        valid = 1'b1;  // Always valid for this design
        
        // Clamp n to 64 if input is larger
        case (n)
            6'd0: result = 8'd0;   // No primes < 0
            6'd1: result = 8'd0;   // No primes < 1
            6'd2: result = 8'd0;   // No primes < 2
            6'd3: result = 8'd1;   // Prime 2 < 3
            6'd4: result = 8'd1;   // Prime 2 < 4
            6'd5: result = 8'd2;   // Primes 2,3 < 5
            6'd6: result = 8'd2;   // Primes 2,3 < 6
            6'd7: result = 8'd3;   // Primes 2,3,5 < 7
            6'd8: result = 8'd3;   // Primes 2,3,5 < 8
            6'd9: result = 8'd3;   // Primes 2,3,5 < 9
            6'd10: result = 8'd4;  // Primes 2,3,5,7 < 10
            6'd11: result = 8'd4;  // Primes 2,3,5,7 < 11
            6'd12: result = 8'd4;  // Primes 2,3,5,7 < 12
            6'd13: result = 8'd5;  // Primes 2,3,5,7,11 < 13
            6'd14: result = 8'd5;  // Primes 2,3,5,7,11 < 14
            6'd15: result = 8'd5;  // Primes 2,3,5,7,11 < 15
            6'd16: result = 8'd5;  // Primes 2,3,5,7,11 < 16
            6'd17: result = 8'd6;  // Primes 2,3,5,7,11,13 < 17
            6'd18: result = 8'd6;  // Primes 2,3,5,7,11,13 < 18
            6'd19: result = 8'd7;  // Primes 2,3,5,7,11,13,17 < 19
            6'd20: result = 8'd7;  // Primes 2,3,5,7,11,13,17 < 20
            6'd21: result = 8'd7;  // Primes 2,3,5,7,11,13,17 < 21
            6'd22: result = 8'd7;  // Primes 2,3,5,7,11,13,17 < 22
            6'd23: result = 8'd8;  // Primes 2,3,5,7,11,13,17,19 < 23
            6'd24: result = 8'd8;  // Primes 2,3,5,7,11,13,17,19 < 24
            6'd25: result = 8'd8;  // Primes 2,3,5,7,11,13,17,19 < 25
            6'd26: result = 8'd8;  // Primes 2,3,5,7,11,13,17,19 < 26
            6'd27: result = 8'd8;  // Primes 2,3,5,7,11,13,17,19 < 27
            6'd28: result = 8'd8;  // Primes 2,3,5,7,11,13,17,19 < 28
            6'd29: result = 8'd9;  // Primes 2,3,5,7,11,13,17,19,23 < 29
            6'd30: result = 8'd9;  // Primes 2,3,5,7,11,13,17,19,23 < 30
            6'd31: result = 8'd10; // Primes 2,3,5,7,11,13,17,19,23,29 < 31
            6'd32: result = 8'd10; // Primes 2,3,5,7,11,13,17,19,23,29 < 32
            6'd33: result = 8'd10; // Primes 2,3,5,7,11,13,17,19,23,29 < 33
            6'd34: result = 8'd10; // Primes 2,3,5,7,11,13,17,19,23,29 < 34
            6'd35: result = 8'd10; // Primes 2,3,5,7,11,13,17,19,23,29 < 35
            6'd36: result = 8'd10; // Primes 2,3,5,7,11,13,17,19,23,29 < 36
            6'd37: result = 8'd11; // Primes 2,3,5,7,11,13,17,19,23,29,31 < 37
            6'd38: result = 8'd11; // Primes 2,3,5,7,11,13,17,19,23,29,31 < 38
            6'd39: result = 8'd11; // Primes 2,3,5,7,11,13,17,19,23,29,31 < 39
            6'd40: result = 8'd11; // Primes 2,3,5,7,11,13,17,19,23,29,31 < 40
            6'd41: result = 8'd12; // Primes 2,3,5,7,11,13,17,19,23,29,31,37 < 41
            6'd42: result = 8'd12; // Primes 2,3,5,7,11,13,17,19,23,29,31,37 < 42
            6'd43: result = 8'd13; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41 < 43
            6'd44: result = 8'd13; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41 < 44
            6'd45: result = 8'd13; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41 < 45
            6'd46: result = 8'd13; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41 < 46
            6'd47: result = 8'd14; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43 < 47
            6'd48: result = 8'd14; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43 < 48
            6'd49: result = 8'd14; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43 < 49
            6'd50: result = 8'd14; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43 < 50
            6'd51: result = 8'd14; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43 < 51
            6'd52: result = 8'd14; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43 < 52
            6'd53: result = 8'd15; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43,47 < 53
            6'd54: result = 8'd15; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43,47 < 54
            6'd55: result = 8'd15; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43,47 < 55
            6'd56: result = 8'd15; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43,47 < 56
            6'd57: result = 8'd15; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43,47 < 57
            6'd58: result = 8'd15; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43,47 < 58
            6'd59: result = 8'd16; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53 < 59
            6'd60: result = 8'd16; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53 < 60
            6'd61: result = 8'd17; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59 < 61
            6'd62: result = 8'd17; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59 < 62
            6'd63: result = 8'd17; // Primes 2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59 < 63
            default: result = 8'd18; // For n > 63, clamp to 64 (primes 2..61)
        endcase
    end

endmodule