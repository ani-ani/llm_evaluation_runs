module square_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [15:0] result,
    output reg done
);

// Combinational formula: 2*n*(n+1)*(2*n+1)/3
// Supports n from 0 to 8 (max result: 120 for n=4, fits in 16 bits)
// All operations use unsigned integer arithmetic

localparam [1:0] IDLE = 2'd0;
localparam [1:0] COMPUTE = 2'd1;
localparam [1:0] FINISH = 2'd2;

reg [1:0] state;
reg [15:0] temp1, temp2, temp3;
reg [15:0] result_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 16'd0;
        result_reg <= 16'd0;
        done <= 1'b0;
        temp1 <= 16'd0;
        temp2 <= 16'd0;
        temp3 <= 16'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= COMPUTE;
                end
            end
            
            COMPUTE: begin
                // Combinational computation
                // temp1 = n + 1
                temp1 <= {8'd0, n} + 16'd1;
                // temp2 = 2*n + 1
                temp2 <= ({8'd0, n} << 1) + 16'd1;
                // temp3 = 2*n*(n+1)
                temp3 <= ({8'd0, n} << 1) * ({8'd0, n} + 16'd1);
                state <= FINISH;
            end
            
            FINISH: begin
                // result = temp3 * temp2 / 3
                result_reg <= (temp3 * temp2) / 3;
                result <= (temp3 * temp2) / 3;
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule