module convex_scoring (
input clk,
input rst_n,
input start,
input [7:0] N,
input [15:0] points_x [0:15],
input [15:0] points_y [0:15],
output reg [31:0] result,
output reg done
);

reg [15:0] i, j, k;
reg [15:0] processed [0:15][0:15];
reg [31:0] total;
reg [2:0] state;

always @(posedge clk) begin
    if (!rst_n) begin
        i <= 0;
        j <= 0;
        k <= 0;
        processed <= 0;
        total <= 0;
        state <= 0;
        done <= 0;
        result <= 0;
    end else begin
        case (state)
            0: begin
                if (start) state <= 1;
                done <= 0;
                result <= 0;
            endcase
        end
    end
end
endmodule