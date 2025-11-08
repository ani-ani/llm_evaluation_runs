module TopModule (
    input clk,
    input load,
    input [511:0] data,
    output [511:0] q
);

    logic [511:0] state_reg;
    logic [511:0] next_state;

    function automatic logic rule110(input logic l, input logic c, input logic r);
        case ({l, c, r})
            3'b111: return 1'b0;
            3'b110: return 1'b1;
            3'b101: return 1'b1;
            3'b100: return 1'b0;
            3'b011: return 1'b1;
            3'b010: return 1'b1;
            3'b001: return 1'b1;
            3'b000: return 1'b0;
            default: return 1'b0;
        endcase
    endfunction

    always_comb begin
        for (int i = 0; i < 512; i++) begin
            logic left, center, right;
            center = state_reg[i];
            left = (i == 511) ? 1'b0 : state_reg[i+1];
            right = (i == 0) ? 1'b0 : state_reg[i-1];
            next_state[i] = rule110(left, center, right);
        end
    end

    always_ff @(posedge clk) begin
        if (load) state_reg <= data;
        else state_reg <= next_state;
    end

    assign q = state_reg;

endmodule