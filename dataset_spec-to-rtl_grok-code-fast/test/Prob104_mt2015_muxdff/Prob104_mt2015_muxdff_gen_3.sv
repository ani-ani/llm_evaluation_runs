module TopModule (
    input clk,
    input L,
    input q_in,
    input r_in,
    output reg Q
);

    always @(posedge clk) begin
        Q <= L ? r_in : q_in;
    end
endmodule

module full_module (
    input clk,
    input [2:0] r,
    input L,
    output reg [2:0] q
);

    wire q2_xor_q1 = q[1] ^ q[2];
    wire shift0 = q[2];
    wire shift1 = q[0];
    wire shift2 = q2_xor_q1;

    TopModule inst0 (.clk(clk), .L(L), .q_in(shift0), .r_in(r[0]), .Q(q[0]));
    TopModule inst1 (.clk(clk), .L(L), .q_in(shift1), .r_in(r[1]), .Q(q[1]));
    TopModule inst2 (.clk(clk), .L(L), .q_in(shift2), .r_in(r[2]), .Q(q[2]));
endmodule