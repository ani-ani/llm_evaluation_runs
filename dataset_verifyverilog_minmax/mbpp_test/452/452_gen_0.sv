module shift_register #(parameter WIDTH = 8)(
    input wire clk,
    input wire reset,
    input wire [WIDTH-1:0] data_in,
    output reg [WIDTH-1:0] data_out
);

    reg [WIDTH-1:0] shift_reg;

    always @(posedge clk or posedge reset) begin
        if (reset)
            shift_reg <= {WIDTH{1'b0}};
        else
            shift_reg <= {shift_reg[WIDTH-2:0], data_in[0]};
    end

    assign data_out = shift_reg;

endmodule