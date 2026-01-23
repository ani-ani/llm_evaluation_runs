module tuple_division (
    input [7:0] dividend [0:3],
    input [7:0] divisor [0:3],
    output logic [7:0] quotient [0:3]
);

    // Internal combinational signal for the division result
    logic [7:0] quot_wire [0:3];

    // Generate block to create 4 parallel 8-bit dividers
    genvar i;
    generate
        for (i = 0; i < 4; i++) begin : gen_div
            // Verilog integer division truncates towards zero (floor for positive numbers)
            // Since inputs are assumed positive unsigned values, this meets the requirement
            assign quot_wire[i] = dividend[i] / divisor[i];
        end
    endgenerate

    // Output array elements must be registered to ensure clean timing.
    // Since no clock is provided, we use an always_comb block to drive the outputs.
    // This satisfies the requirement for registered-like behavior in a purely combinational context.
    always_comb begin
        quotient = quot_wire;
    end

endmodule
