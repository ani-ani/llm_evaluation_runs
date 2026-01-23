module geometric_sum(input clk, input rst_n, input start, input [3:0] n, output reg [31:0] result, output reg done);
localparam IDLE = 2'b00;
localparam COMPUTING = 2'b01;
localparam DONE = 2'b10;

reg [31:0] sum;
reg [31:0] term;
reg [3:0] iteration_count;
reg [1:0] state;

always @(posedge clk) begin
    if (!rst_n) begin
        sum <= 32'd0;
        term <= 32'h00010000;
        iteration_count <=4'd0;
        state <= IDLE;
        done <=1'b0;
    end else begin
        if (state == COMPUTING) begin
            if (iteration_count < n) begin
                sum <= sum + term;
                term <= term >> 1;
                iteration_count <= iteration_count + 1;
                done <= 1'b0;
            end else begin
                state <= DONE;
                done <= 1'b1;
            end
        end else if (state == DONE) begin
            sum <= sum;
            term <= term;
            iteration_count <= iteration_count;
            done <= 1'b1;
        end else if (state == IDLE) begin
            if (start) begin
                sum <= 32'd0;
                term <= 32'h00010000;
                iteration_count <=4'd0;
                state <= COMPUTING;
                done <= 1'b0;
            end
        end
    end
end

assign result = sum;

endmodule