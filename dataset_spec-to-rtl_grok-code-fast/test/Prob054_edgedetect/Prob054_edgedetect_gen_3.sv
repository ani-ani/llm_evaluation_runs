module TopModule(
    input clk,
    input [7:0] in,
    output logic [7:0] pedge
);

    logic [7:0] prev_in = 8'b0;
    logic [7:0] pedge_reg = 8'b0;

    assign pedge = pedge_reg;

    always_ff @(posedge clk) begin
        pedge_reg <= 8'b0;
        for(int i=0; i<8; i++) begin
            if(prev_in[i] == 0 && in[i] == 1) begin
                pedge_reg[i] <= 1'b1;
            end
        end
        prev_in <= in;
    end

endmodule