module find_unique_numbers (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] len,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg [3:0] result_len,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNT = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state;
    reg [3:0] idx;
    reg [3:0] out_idx;
    reg [7:0] freq_table [0:255];
    reg [7:0] input_reg [0:7];
    reg [3:0] len_reg;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_len <= 4'd0;
            idx <= 4'd0;
            out_idx <= 4'd0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            for (i = 0; i < 256; i = i + 1) begin
                freq_table[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 4'd0;
                    out_idx <= 4'd0;
                    result_len <= 4'd0;
                    if (start) begin
                        input_reg[0] <= arr_0;
                        input_reg[1] <= arr_1;
                        input_reg[2] <= arr_2;
                        input_reg[3] <= arr_3;
                        input_reg[4] <= arr_4;
                        input_reg[5] <= arr_5;
                        input_reg[6] <= arr_6;
                        input_reg[7] <= arr_7;
                        len_reg <= len;
                        for (i = 0; i < 256; i = i + 1) begin
                            freq_table[i] <= 8'd0;
                        end
                        state <= COUNT;
                    end
                end

                COUNT: begin
                    if (idx < len_reg) begin
                        freq_table[input_reg[idx]] <= freq_table[input_reg[idx]] + 8'd1;
                        idx <= idx + 4'd1;
                    end else begin
                        idx <= 4'd0;
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    if (idx < len_reg) begin
                        if (freq_table[input_reg[idx]] == 8'd1) begin
                            case (out_idx)
                                4'd0: result_0 <= input_reg[idx];
                                4'd1: result_1 <= input_reg[idx];
                                4'd2: result_2 <= input_reg[idx];
                                4'd3: result_3 <= input_reg[idx];
                                4'd4: result_4 <= input_reg[idx];
                                4'd5: result_5 <= input_reg[idx];
                                4'd6: result_6 <= input_reg[idx];
                                4'd7: result_7 <= input_reg[idx];
                            endcase
                            out_idx <= out_idx + 4'd1;
                            result_len <= result_len + 4'd1;
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule