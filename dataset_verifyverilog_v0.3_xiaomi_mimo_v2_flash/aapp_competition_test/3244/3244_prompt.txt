module reconstruct (
    input clk,
    input rst_n,
    input start,
    input [7:0] B0, B1, B2, B3,
    output reg [15:0] A0, A1, A2, A3,
    output reg done
);

    // For N=4 only
    wire [15:0] A0_temp;
    wire [15:0] A1_temp;
    wire [15:0] A2_temp;
    wire [15:0] A3_temp;

    // Compute A0 = (B0 + B1 + B3 - 2*B2) / 3
    assign A0_temp = (B0 + B1 + B3 - (B2 << 1)) / 3;
    // Compute A1 = (B0 + B1 - B2) - 2*A0
    assign A1_temp = (B0 + B1 - B2) - (A0_temp << 1);
    // Compute A2 = B1 - A0 - A1
    assign A2_temp = B1 - A0_temp - A1_temp;
    // Compute A3 = B2 - A1 - A2 (equivalent to B2 - B1 + A0)
    assign A3_temp = B2 - A1_temp - A2_temp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            A0 <= 16'd0;
            A1 <= 16'd0;
            A2 <= 16'd0;
            A3 <= 16'd0;
            done <= 1'b0;
        end else begin
            if (start) begin
                A0 <= A0_temp;
                A1 <= A1_temp;
                A2 <= A2_temp;
                A3 <= A3_temp;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end
endmodule