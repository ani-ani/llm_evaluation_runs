module tuple_trimmer(input clk, input rst_n, input start, input [2:0] k, input [2:0] tuple_len, input [4:0] data_in [0:3], output reg [2:0] out_len, output reg [4:0] result_0, result_1, result_2, result_3, result_4, output reg done);
localparam IDLE = 3'd0;
localparam READ_K = 3'd1;
localparam COMPUTE = 3'd2;
localparam WRITE_OUT = 3'd3;
localparam DONE = 3'd4;

reg [2:0] state;
reg [2:0] counter;
reg [4:0] res0, res1, res2, res3;
reg [2:0] len_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        counter <= 0;
        res0 <= 0;
        res1 <= 0;
        res2 <= 0;
        res3 <= 0;
        len_reg <= 0;
        done <= 0;
    end else begin
        case(state)
            IDLE: begin
                if (start)
                    state <= READ_K;
                else
                    state <= IDLE;
            end
            READ_K: begin
                state <= COMPUTE;
                counter <= 4;
            end
            COMPUTE: begin
                if (counter == 0) begin
                    state <= WRITE_OUT;
                end else begin
                    counter <= counter - 1;
                end
            end
            WRITE_OUT: begin
                len_reg = max(0, tuple_len - 2 * k);
                if (len_reg > 0) begin
                    res0 = data_in[0][k];
                    res1 = data_in[1][k];
                    res2 = data_in[2][k];
                    res3 = data_in[3][k];
                end else begin
                    res0 = 0;
                    res1 = 0;
                    res2 = 0;
                    res3 = 0;
                end
                out_len <= len_reg;
                result_0 <= res0;
                result_1 <= res1;
                result_2 <= res2;
                result_3 <= res3;
                result_4 <= 0;
                done <= 1;
                state <= DONE;
            end
            DONE: state <= DONE;
        endcase
    end
end
endmodule