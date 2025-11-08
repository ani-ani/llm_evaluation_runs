module TopModule(
    input clk,
    input reset,
    input x,
    output reg z
);
    reg [2:0] state;
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= 3'b000;
        end else begin
            case (state)
                3'b000: state <= x ? 3'b001 : 3'b000;
                3'b001: state <= x ? 3'b100 : 3'b001;
                3'b010: state <= x ? 3'b001 : 3'b010;
                3'b011: state <= x ? 3'b010 : 3'b001;
                3'b100: state <= x ? 3'b100 : 3'b011;
            endcase
        end
    end
    always_comb begin
        case (state)
            3'b011: z = 1;
            3'b100: z = 1;
            default: z = 0;
        endcase
    end
endmodule