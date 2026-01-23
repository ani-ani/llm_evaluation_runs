module domino_cover (
    input [7:0] cell_0_0, cell_0_1, cell_0_2,
    input [7:0] cell_1_0, cell_1_1, cell_1_2,
    input [1:0] K,
    output reg [15:0] result
);

// Weights and masks for each placement (weight = sum of two cells, mask = covered cells).
wire signed [15:0] weight[0:6];
wire [5:0] mask[0:6];

assign weight[0] = $signed(cell_0_0) + $signed(cell_0_1);
assign mask[0] = 6'b000011;
assign weight[1] = $signed(cell_0_1) + $signed(cell_0_2);
assign mask[1] = 6'b000110;
assign weight[2] = $signed(cell_1_0) + $signed(cell_1_1);
assign mask[2] = 6'b001100;
assign weight[3] = $signed(cell_1_1) + $signed(cell_1_2);
assign mask[3] = 6'b011000;
assign weight[4] = $signed(cell_0_0) + $signed(cell_1_0);
assign mask[4] = 6'b001001;
assign weight[5] = $signed(cell_0_1) + $signed(cell_1_1);
assign mask[5] = 6'b010010;
assign weight[6] = $signed(cell_0_2) + $signed(cell_1_2);
assign mask[6] = 6'b100100;

always @(*) begin
    case (K)
        2'b00: result = 16'sd0;
        2'b01: begin
            result = weight[0];
            if (weight[1] > result) result = weight[1];
            if (weight[2] > result) result = weight[2];
            if (weight[3] > result) result = weight[3];
            if (weight[4] > result) result = weight[4];
            if (weight[5] > result) result = weight[5];
            if (weight[6] > result) result = weight[6];
        end
        2'b10: begin
            result = -16'sd32768;
            if ((mask[0] & mask[1]) == 6'b0 && weight[0] + weight[1] > result) result = weight[0] + weight[1];
            if ((mask[0] & mask[2]) == 6'b0 && weight[0] + weight[2] > result) result = weight[0] + weight[2];
            if ((mask[0] & mask[3]) == 6'b0 && weight[0] + weight[3] > result) result = weight[0] + weight[3];
            if ((mask[0] & mask[4]) == 6'b0 && weight[0] + weight[4] > result) result = weight[0] + weight[4];
            if ((mask[0] & mask[5]) == 6'b0 && weight[0] + weight[5] > result) result = weight[0] + weight[5];
            if ((mask[0] & mask[6]) == 6'b0 && weight[0] + weight[6] > result) result = weight[0] + weight[6];
            if ((mask[1] & mask[2]) == 6'b0 && weight[1] + weight[2] > result) result = weight[1] + weight[2];
            if ((mask[1] & mask[3]) == 6'b0 && weight[1] + weight[3] > result) result = weight[1] + weight[3];
            if ((mask[1] & mask[4]) == 6'b0 && weight[1] + weight[4] > result) result = weight[1] + weight[4];
            if ((mask[1] & mask[5]) == 6'b0 && weight[1] + weight[5] > result) result = weight[1] + weight[5];
            if ((mask[1] & mask[6]) == 6'b0 && weight[1] + weight[6] > result) result = weight[1] + weight[6];
            if ((mask[2] & mask[3]) == 6'b0 && weight[2] + weight[3] > result) result = weight[2] + weight[3];
            if ((mask[2] & mask[4]) == 6'b0 && weight[2] + weight[4] > result) result = weight[2] + weight[4];
            if ((mask[2] & mask[5]) == 6'b0 && weight[2] + weight[5] > result) result = weight[2] + weight[5];
            if ((mask[2] & mask[6]) == 6'b0 && weight[2] + weight[6] > result) result = weight[2] + weight[6];
            if ((mask[3] & mask[4]) == 6'b0 && weight[3] + weight[4] > result) result = weight[3] + weight[4];
            if ((mask[3] & mask[5]) == 6'b0 && weight[3] + weight[5] > result) result = weight[3] + weight[5];
            if ((mask[3] & mask[6]) == 6'b0 && weight[3] + weight[6] > result) result = weight[3] + weight[6];
            if ((mask[4] & mask[5]) == 6'b0 && weight[4] + weight[5] > result) result = weight[4] + weight[5];
            if ((mask[4] & mask[6]) == 6'b0 && weight[4] + weight[6] > result) result = weight[4] + weight[6];
            if ((mask[5] & mask[6]) == 6'b0 && weight[5] + weight[6] > result) result = weight[5] + weight[6];
        end
        2'b11: begin
            result = -16'sd32768;
            if ((mask[0] & mask[1]) == 6'b0 && (mask[0] & mask[2]) == 6'b0 && (mask[1] & mask[2]) == 6'b0 && weight[0] + weight[1] + weight[2] > result) result = weight[0] + weight[1] + weight[2];
            if ((mask[0] & mask[1]) == 6'b0 && (mask[0] & mask[3]) == 6'b0 && (mask[1] & mask[3]) == 6'b0 && weight[0] + weight[1] + weight[3] > result) result = weight[0] + weight[1] + weight[3];
            if ((mask[0] & mask[1]) == 6'b0 && (mask[0] & mask[4]) == 6'b0 && (mask[1] & mask[4]) == 6'b0 && weight[0] + weight[1] + weight[4] > result) result = weight[0] + weight[1] + weight[4];
            if ((mask[0] & mask[1]) == 6'b0 && (mask[0] & mask[5]) == 6'b0 && (mask[1] & mask[5]) == 6'b0 && weight[0] + weight[1] + weight[5] > result) result = weight[0] + weight[1] + weight[5];
            if ((mask[0] & mask[1]) == 6'b0 && (mask[0] & mask[6]) == 6'b0 && (mask[1] & mask[6]) == 6'b0 && weight[0] + weight[1] + weight[6] > result) result = weight[0] + weight[1] + weight[6];
            if ((mask[0] & mask[2]) == 6'b0 && (mask[0] & mask[3]) == 6'b0 && (mask[2] & mask[3]) == 6'b0 && weight[0] + weight[2] + weight[3] > result) result = weight[0] + weight[2] + weight[3];
            if ((mask[0] & mask[2]) == 6'b0 && (mask[0] & mask[4]) == 6'b0 && (mask[2] & mask[4]) == 6'b0 && weight[0] + weight[2] + weight[4] > result) result = weight[0] + weight[2] + weight[4];
            if ((mask[0] & mask[2]) == 6'b0 && (mask[0] & mask[5]) == 6'b0 && (mask[2] & mask[5]) == 6'b0 && weight[0] + weight[2] + weight[5] > result) result = weight[0] + weight[2] + weight[5];
            if ((mask[0] & mask[2]) == 6'b0 && (mask[0] & mask[6]) == 6'b0 && (mask[2] & mask[6]) == 6'b0 && weight[0] + weight[2] + weight[6] > result) result = weight[0] + weight[2] + weight[6];
            if ((mask[0] & mask[3]) == 6'b0 && (mask[0] & mask[4]) == 6'b0 && (mask[3] & mask[4]) == 6'b0 && weight[0] + weight[3] + weight[4] > result) result = weight[0] + weight[3] + weight[4];
            if ((mask[0] & mask[3]) == 6'b0 && (mask[0] & mask[5]) == 6'b0 && (mask[3] & mask[5]) == 6'b0 && weight[0] + weight[3] + weight[5] > result) result = weight[0] + weight[3] + weight[5];
            if ((mask[0] & mask[3]) == 6'b0 && (mask[0] & mask[6]) == 6'b0 && (mask[3] & mask[6]) == 6'b0 && weight[0] + weight[3] + weight[6] > result) result = weight[0] + weight[3] + weight[6];
            if ((mask[0] & mask[4]) == 6'b0 && (mask[0] & mask[5]) == 6'b0 && (mask[4] & mask[5]) == 6'b0 && weight[0] + weight[4] + weight[5] > result) result = weight[0] + weight[4] + weight[5];
            if ((mask[0] & mask[4]) == 6'b0 && (mask[0] & mask[6]) == 6'b0 && (mask[4] & mask[6]) == 6'b0 && weight[0] + weight[4] + weight[6] > result) result = weight[0] + weight[4] + weight[6];
            if ((mask[0] & mask[5]) == 6'b0 && (mask[0] & mask[6]) == 6'b0 && (mask[5] & mask[6]) == 6'b0 && weight[0] + weight[5] + weight[6] > result) result = weight[0] + weight[5] + weight[6];
            if ((mask[1] & mask[2]) == 6'b0 && (mask[1] & mask[3]) == 6'b0 && (mask[2] & mask[3]) == 6'b0 && weight[1] + weight[2] + weight[3] > result) result = weight[1] + weight[2] + weight[3];
            if ((mask[1] & mask[2]) == 6'b0 && (mask[1] & mask[4]) == 6'b0 && (mask[2] & mask[4]) == 6'b0 && weight[1] + weight[2] + weight[4] > result) result = weight[1] + weight[2] + weight[4];
            if ((mask[1] & mask[2]) == 6'b0 && (mask[1] & mask[5]) == 6'b0 && (mask[2] & mask[5]) == 6'b0 && weight[1] + weight[2] + weight[5] > result) result = weight[1] + weight[2] + weight[5];
            if ((mask[1] & mask[2]) == 6'b0 && (mask[1] & mask[6]) == 6'b0 && (mask[2] & mask[6]) == 6'b0 && weight[1] + weight[2] + weight[6] > result) result = weight[1] + weight[2] + weight[6];
            if ((mask[1] & mask[3]) == 6'b0 && (mask[1] & mask[4]) == 6'b0 && (mask[3] & mask[4]) == 6'b0 && weight[1] + weight[3] + weight[4] > result) result = weight[1] + weight[3] + weight[4];
            if ((mask[1] & mask[3]) == 6'b0 && (mask[1] & mask[5]) == 6'b0 && (mask[3] & mask[5]) == 6'b0 && weight[1] + weight[3] + weight[5] > result) result = weight[1] + weight[3] + weight[5];
            if ((mask[1] & mask[3]) == 6'b0 && (mask[1] & mask[6]) == 6'b0 && (mask[3] & mask[6]) == 6'b0 && weight[1] + weight[3] + weight[6] > result) result = weight[1] + weight[3] + weight[6];
            if ((mask[1] & mask[4]) == 6'b0 && (mask[1] & mask[5]) == 6'b0 && (mask[4] & mask[5]) == 6'b0 && weight[1] + weight[4] + weight[5] > result) result = weight[1] + weight[4] + weight[5];
            if ((mask[1] & mask[4]) == 6'b0 && (mask[1] & mask[6]) == 6'b0 && (mask[4] & mask[6]) == 6'b0 && weight[1] + weight[4] + weight[6] > result) result = weight[1] + weight[4] + weight[6];
            if ((mask[1] & mask[5]) == 6'b0 && (mask[1] & mask[6]) == 6'b0 && (mask[5] & mask[6]) == 6'b0 && weight[1] + weight[5] + weight[6] > result) result = weight[1] + weight[5] + weight[6];
            if ((mask[2] & mask[3]) == 6'b0 && (mask[2] & mask[4]) == 6'b0 && (mask[3] & mask[4]) == 6'b0 && weight[2] + weight[3] + weight[4] > result) result = weight[2] + weight[3] + weight[4];
            if ((mask[2] & mask[3]) == 6'b0 && (mask[2] & mask[5]) == 6'b0 && (mask[3] & mask[5]) == 6'b0 && weight[2] + weight[3] + weight[5] > result) result = weight[2] + weight[3] + weight[5];
            if ((mask[2] & mask[3]) == 6'b0 && (mask[2] & mask[6]) == 6'b0 && (mask[3] & mask[6]) == 6'b0 && weight[2] + weight[3] + weight[6] > result) result = weight[2] + weight[3] + weight[6];
            if ((mask[2] & mask[4]) == 6'b0 && (mask[2] & mask[5]) == 6'b0 && (mask[4] & mask[5]) == 6'b0 && weight[2] + weight[4] + weight[5] > result) result = weight[2] + weight[4] + weight[5];
            if ((mask[2] & mask[4]) == 6'b0 && (mask[2] & mask[6]) == 6'b0 && (mask[4] & mask[6]) == 6'b0 && weight[2] + weight[4] + weight[6] > result) result = weight[2] + weight[4] + weight[6];
            if ((mask[2] & mask[5]) == 6'b0 && (mask[2] & mask[6]) == 6'b0 && (mask[5] & mask[6]) == 6'b0 && weight[2] + weight[5] + weight[6] > result) result = weight[2] + weight[5] + weight[6];
            if ((mask[3] & mask[4]) == 6'b0 && (mask[3] & mask[5]) == 6'b0 && (mask[4] & mask[5]) == 6'b0 && weight[3] + weight[4] + weight[5] > result) result = weight[3] + weight[4] + weight[5];
            if ((mask[3] & mask[4]) == 6'b0 && (mask[3] & mask[6]) == 6'b0 && (mask[4] & mask[6]) == 6'b0 && weight[3] + weight[4] + weight[6] > result) result = weight[3] + weight[4] + weight[6];
            if ((mask[3] & mask[5]) == 6'b0 && (mask[3] & mask[6]) == 6'b0 && (mask[5] & mask[6]) == 6'b0 && weight[3] + weight[5] + weight[6] > result) result = weight[3] + weight[5] + weight[6];
            if ((mask[4] & mask[5]) == 6'b0 && (mask[4] & mask[6]) == 6'b0 && (mask[5] & mask[6]) == 6'b0 && weight[4] + weight[5] + weight[6] > result) result = weight[4] + weight[5] + weight[6];
        end
        default: result = 16'sd0;
    endcase
end
endmodule