module prime_minister_happiness (
    input clk,
    input rst_n,
    input start,
    input [5:0] N,
    input [5:0] K,
    input [31:0] x [0:11],
    input [31:0] y [0:11],
    input [31:0] residents [0:11],
    output reg [31:0] min_D,
    output reg done
);

reg [31:0] min_D_reg;
reg done_reg;
reg [2:0] state;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'd0;
        min_D_reg <= 32'd0;
        done_reg <= 1'b0;
    end else begin
        case (state)
            3'd0: begin
                if (start) begin
                    state <= 3'd1;
                end
            end
            default: state <= 3'd0;
        endcase
    end
end

assign min_D = min_D_reg;
assign done = done_reg;

endmodule