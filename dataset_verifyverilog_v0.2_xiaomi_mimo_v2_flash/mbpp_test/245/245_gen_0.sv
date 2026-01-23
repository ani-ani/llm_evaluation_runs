module bitonic_max_sum (
    input clk,
    input rst_n,
    input start,
    input [2:0] array_len,
    input [7:0] array_data [0:7],
    output reg [15:0] max_sum_result,
    output reg done
);

    // States
    localparam IDLE = 3'b000;
    localparam CALC_MSIBS = 3'b001;
    localparam CALC_MSDBS = 3'b010;
    localparam CALC_RESULT = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [7:0] arr_reg [0:7];
    reg [15:0] msibs [0:7];
    reg [15:0] msdbs [0:7];
    reg [3:0] len_reg; // 4-bit to handle length 8
    reg [2:0] i, j;
    reg [15:0] current_max;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            max_sum_result <= 16'd0;
            i <= 0;
            j <= 0;
            len_reg <= 0;
            current_max <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        arr_reg[0] <= array_data[0];
                        arr_reg[1] <= array_data[1];
                        arr_reg[2] <= array_data[2];
                        arr_reg[3] <= array_data[3];
                        arr_reg[4] <= array_data[4];
                        arr_reg[5] <= array_data[5];
                        arr_reg[6] <= array_data[6];
                        arr_reg[7] <= array_data[7];

                        // Handle length encoding (1-8)
                        if (array_len == 0) len_reg <= 8;
                        else len_reg <= {1'b0, array_len};

                        i <= 0;
                        j <= 0;

                        // Start calculation if length > 0 (or length 8)
                        if (array_len != 0 || array_len == 0) state <= CALC_MSIBS;
                        else state <= DONE;
                    end
                end

                CALC_MSIBS: begin
                    if (i < len_reg) begin
                        if (j == 0) begin
                            current_max <= {8'b0, arr_reg[i]};
                            if (i > 0) begin
                                if (arr_reg[i] > arr_reg[0]) begin
                                    current_max <= msibs[0] + {8'b0, arr_reg[i]};
                                end
                                j <= 1;
                            end else begin
                                msibs[0] <= {8'b0, arr_reg[0]};
                                i <= 1;
                            end
                        end else if (j < i) begin
                            if (arr_reg[i] > arr_reg[j]) begin
                                if (msibs[j] + {8'b0, arr_reg[i]} > current_max)
                                    current_max <= msibs[j] + {8'b0, arr_reg[i]};
                            end
                            j <= j + 1;
                        end else begin
                            msibs[i] <= current_max;
                            i <= i + 1;
                            j <= 0;
                        end
                    end else begin
                        i <= len_reg - 1;
                        j <= len_reg;
                        state <= CALC_MSDBS;
                    end
                end

                CALC_MSDBS: begin
                    if (i >= len_reg && i != 0) begin
                        state <= CALC_RESULT;
                        i <= 0;
                    end else begin
                        if (j == len_reg) begin
                            current_max <= {8'b0, arr_reg[i]};
                            j <= len_reg - 1;
                        end else if (j > i) begin
                            if (arr_reg[i] > arr_reg[j]) begin
                                if (msdbs[j] + {8'b0, arr_reg[i]} > current_max)
                                    current_max <= msdbs[j] + {8'b0, arr_reg[i]};
                            end
                            j <= j - 1;
                        end else begin
                            msdbs[i] <= current_max;
                            if (i == 0) begin
                                i <= i - 1;
                            end else begin
                                i <= i - 1;
                                j <= len_reg;
                            end
                        end
                    end
                end

                CALC_RESULT: begin
                    if (i < len_reg) begin
                        if (i == 0) begin
                            max_sum_result <= msibs[0] + msdbs[0] - arr_reg[0];
                        end else begin
                            if (msibs[i] + msdbs[i] - arr_reg[i] > max_sum_result)
                                max_sum_result <= msibs[i] + msdbs[i] - arr_reg[i];
                        end
                        i <= i + 1;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule