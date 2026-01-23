module PoolShark (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] data_in,
    input wire [1:0] data_valid,
    output reg [15:0] d_out,
    output reg [15:0] theta_out,
    output reg done,
    output reg impossible
);

    reg [4:0] input_cnt;
    reg [5:0] state;
    reg [31:0] w_reg, l_reg, r_reg, h_reg;
    reg [31:0] x1, y1, x2, y2, x3, y3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0;
            input_cnt <= 0;
            done <= 0;
            impossible <= 0;
            d_out <= 0;
            theta_out <= 0;
            w_reg <= 0;
            l_reg <= 0;
            r_reg <= 0;
            h_reg <= 0;
            x1 <= 0;
            y1 <= 0;
            x2 <= 0;
            y2 <= 0;
            x3 <= 0;
            y3 <= 0;
        end else begin
            if (start) begin
                if (input_cnt < 10) begin
                    if (data_valid[0]) begin
                        case (input_cnt)
                            0: w_reg <= data_in;
                            1: l_reg <= data_in;
                            2: r_reg <= data_in;
                            3: x1 <= data_in;
                            4: y1 <= data_in;
                            5: x2 <= data_in;
                            6: y2 <= data_in;
                            7: x3 <= data_in;
                            8: y3 <= data_in;
                            9: h_reg <= data_in;
                        endcase
                        input_cnt <= input_cnt + 1;
                    end
                end
                if (input_cnt == 10) begin
                    state <= 1;
                    done <= 1;
                    impossible <= 0;
                    d_out <= 0;
                    theta_out <= 0;
                end
            end
        end
    end

endmodule