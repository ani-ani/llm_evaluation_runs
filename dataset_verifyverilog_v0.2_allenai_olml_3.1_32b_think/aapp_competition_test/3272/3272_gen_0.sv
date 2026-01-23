module tomb_solver ( input clk, input rst_n, input start, input [7:0] grid [0:15], output reg [7:0] min_rotations, output reg [7:0] status, output reg done );
reg [7:0] min_rot;
reg [2:0] state;
reg done_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        min_rot <= 8'hFF;
        state <= 3'b000;
        done_reg <= 0;
    end else begin
        if (state == 3'b000) begin
            if (start) begin
                state <= 3'b001;
            end
        end else if (state == 3'b001) begin
            state <= 3'b010;
        end else if (state == 3'b010) begin
            state <= 3'b011;
        end else if (state == 3'b011) begin
            state <= 3'b100;
        end else if (state == 3'b100) begin
            state <= 3'b101;
        end else if (state == 3'b101) begin
            state <= 3'b110;
        end else if (state == 3'b110) begin
        end else if (state == 3'b111) begin
            min_rot <= 8'hFF;
            state <= 3'b111;
        end
    end
end

assign done = done_reg;
assign status = (state == 3'b110) ? 1 : (state == 3'b111 ? 2 : 0);
assign min_rotations = min_rot;

endmodule