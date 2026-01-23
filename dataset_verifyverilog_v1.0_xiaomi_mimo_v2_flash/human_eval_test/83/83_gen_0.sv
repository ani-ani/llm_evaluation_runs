module starts_one_ends(
    input [2:0] n,
    output reg [15:0] count
);
    // Combinational logic for n from 1 to 5
    always @(*) begin
        case (n)
            3'd1: count = 16'd1;      // Only number 1
            3'd2: count = 16'd18;     // 2*10^1 - 10^0 = 20 - 1 = 19, but 11 counted twice: 19 - 1 = 18
            3'd3: count = 16'd180;    // 2*10^2 - 10^1 = 200 - 10 = 190, but 101,111,121,...,191 (11 numbers) counted twice: 190 - 10 = 180
            3'd4: count = 16'd1800;   // 2*10^3 - 10^2 = 2000 - 100 = 1900, but 1001,1111,... (101 numbers) counted twice: 1900 - 100 = 1800
            3'd5: count = 16'd18000;  // 2*10^4 - 10^3 = 20000 - 1000 = 19000, but 10001,11111,... (1001 numbers) counted twice: 19000 - 1000 = 18000
            default: count = 16'd0;   // Default case
        endcase
    end
endmodule