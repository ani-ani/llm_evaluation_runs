module divisibility_hack (
    input [63:0] b,
    input [63:0] d,
    output valid
);
localparam WIDTH = 64;
function [WIDTH-1:0] mod_mult;
    input [WIDTH-1:0] a, b;
    input [WIDTH-1:0] mod;
    begin
        reg [WIDTH*2-1:0] product;
        product = a * b;

        reg [WIDTH-1:0] high = product[WIDTH*2-1 : WIDTH];
        reg [WIDTH-1:0] low = product[WIDTH-1 : 0];

        reg [WIDTH-1:0] pow2_32 = (1 << 32) % mod;
        reg [WIDTH-1:0] pow_64;
        if (mod == 1) begin
            pow_64 = 0;
        end else begin
            pow_64 = (pow2_32 * pow2_32) % mod;
        end

        reg [WIDTH-1:0] term1 = (high % mod) * pow_64;
        term1 = term1 % mod;

        mod_mult = (term1 + low) % mod;
    endfunction

function [WIDTH-1:0] modular_pow;
    input [WIDTH-1:0] base, exponent, modulus;
    begin
        reg [WIDTH-1:0] result = 1;
        reg [WIDTH-1:0] current_base = base;

        for (int i=0; i<WIDTH; i++) begin
            if (exponent & (1 << i)) begin
                result = mod_mult(result, current_base, modulus);
            end
            current_base = mod_mult(current_base, current_base, modulus);
        end
        modular_pow = result;
    endfunction

reg valid;

always @(*) begin
    reg [WIDTH-1:0] remainder = b % d;

    if (remainder == 0) begin
        valid = 0;
    end else begin
        reg [WIDTH-1:0] exponent_val = (d - 1) >> 1;
        reg [WIDTH-1:0] result;
        result = modular_pow(remainder, exponent_val, d);
        valid = (result == 1) ? 1 : 0;
    end
end

endmodule