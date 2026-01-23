module array_reconstructor (input clk, input rst_n, input start, input [4:0] data_in, input valid_in, output reg [4:0] result_out, output reg valid_out, output reg done, output reg error);
parameter N =16;
parameter Q =32;
reg [15:0] index;
reg [4:0] current_max;
reg [4:0] global_max;
reg zero_encountered;
reg [4:0] result_reg;
reg done_reg;
reg error_reg;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        index <= N-1;
        current_max <= 5'b0;
        global_max <= 5'b0;
        zero_encountered <= 1'b0;
        done_reg <= 1'b0;
        error_reg <= 1'b0;
    end else begin
        if (valid_in) begin
            if (data_in == 5'b0) begin
                result_reg = (current_max == 0) ? 1 : current_max;
                zero_encountered <= 1'b1;
            end else begin
                if (data_in > current_max) begin
                    current_max <= data_in;
                end else if (data_in < current_max) begin
                    error_reg <= 1'b1;
                end
            end
            if (result_reg > global_max) begin
                global_max <= result_reg;
            end
            result_out <= result_reg;
            valid_out <= 1'b1;
            index <= index - 1;
            if (index == 0) begin
                done_reg <= 1'b1;
            end
        end
        if (done_reg) begin
            if (Q > global_max && !zero_encountered) begin
                error_reg <= 1'b1;
            end
        end
    end
endmodule