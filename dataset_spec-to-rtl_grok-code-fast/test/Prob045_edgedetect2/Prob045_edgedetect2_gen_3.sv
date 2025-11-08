module TopModule(
    input clk,
    input [7:0] in,
    output logic [7:0] anyedge
);
    logic [7:0] prev_in;
    logic [7:0] change_reg;
    always_ff @(posedge clk) begin
        change_reg <= in ^ prev_in;
        prev_in <= in;
        anyedge <= change_reg;
    end
endmodule