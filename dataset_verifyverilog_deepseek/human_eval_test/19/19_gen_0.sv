module number_sorter (
    input clk,
    input rst_n,
    input [2:0] count,
    input [31:0] numbers,
    input start,
    output reg [31:0] sorted,
    output reg done
);

    reg [1:0] state;
    localparam IDLE       = 2'b00;
    localparam SORTING    = 2'b01;
    localparam DONE_SET   = 2'b10;
    localparam DONE_WAIT  = 2'b11;

    reg [3:0] data_reg [0:7];
    reg [2:0] i_reg, j_reg;
    reg [2:0] count_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            sorted <= 32'b0;
            foreach (data_reg[i]) data_reg[i] <= 4'b0;
            i_reg <= 3'b0;
            j_reg <= 3'b0;
            count_reg <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Process inputs and load data_reg
                        for (int idx = 0; idx < 8; idx = idx + 1) begin
                            automatic logic [3:0] num = numbers[idx*4 +:4];
                            data_reg[idx] <= (num > 4'd9) ? 4'b0 : num;
                        end
                        count_reg <= count;
                        if (count <= 3'd1) state <= DONE_SET;
                        else begin
                            i_reg <= 0;
                            j_reg <= 0;
                            state <= SORTING;
                        end
                    end
                end

                SORTING: begin
                    if (i_reg < (count_reg - 1)) begin
                        if (j_reg < (count_reg - 1 - i_reg)) begin
                            // Compare and conditionally swap
                            if (data_reg[j_reg] > data_reg[j_reg+1]) begin
                                data_reg[j_reg] <= data_reg[j_reg+1];
                                data_reg[j_reg+1] <= data_reg[j_reg];
                            end
                            j_reg <= j_reg + 1;
                        end else begin
                            j_reg <= 0;
                            i_reg <= i_reg + 1;
                        end
                    end else state <= DONE_SET;
                end

                DONE_SET: begin
                    sorted <= {data_reg[7], data_reg[6], data_reg[5], data_reg[4],
                              data_reg[3], data_reg[2], data_reg[1], data_reg[0]};
                    state <= DONE_WAIT;
                end

                DONE_WAIT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule