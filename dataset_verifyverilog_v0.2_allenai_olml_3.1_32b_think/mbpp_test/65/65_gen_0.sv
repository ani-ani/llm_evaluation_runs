module recursive_list_sum (
input clk,
input rst_n,
input start,
input [15:0] data [0:3][0:3],
output reg [31:0] total_sum,
output reg done
);

reg [1:0] state;
reg [31:0] total_sum;
reg [3:0] counter;
reg done;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 2'b00;
        total_sum <= 32'd0;
        counter <= 4'd0;
        done <= 1'b0;
    end else begin
        case (state)
            2'b00: begin
                if (start) begin
                    state <= 2'b01;
                end
            end
            2'b01: begin
                int row, col;
                row = counter / 4;
                col = counter % 4;
                total_sum <= total_sum + data[row][col];
                if (counter == 4'd15) begin
                    state <= 2'b10;
                    done <= 1'b1;
                end else begin
                    counter <= counter + 1;
                end
            end
            2'b10: begin
            end
            default: state <= 2'b00;
        endcase
    end
end

endmodule