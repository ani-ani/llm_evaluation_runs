module unique_digits(input clk, input rst_n, input start, input [13:0] in0, in1, in2, in3, output reg [13:0] out0, out1, out2, out3, output reg [2:0] count, output reg done)

localparam IDLE = 3'd0, PARSE_0 = 1, PARSE_1 = 2, PARSE_2 = 3, PARSE_3 = 4, FILTER = 5, SORT = 6, DONE = 7;

reg [2:0] state_reg;
reg [3:0] valid_reg;
reg [3][13:0] temp_buf_reg;
reg [2:0] temp_count_reg;
reg [3][13:0] sorted_buf_reg;
reg [13:0] out0_reg, out1_reg, out2_reg, out3_reg;
reg [2:0] count_reg;
reg done_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        valid_reg <= 4'b0000;
        temp_buf_reg <= 4'b0;
        temp_count_reg <= 3'b000;
        sorted_buf_reg <= 4'b0;
        count_reg <= 3'b000;
        done_reg <= 1'b0;
        out0_reg <= 14'b0;
        out1_reg <= 14'b0;
        out2_reg <= 14'b0;
        out3_reg <= 14'b0;
    end else begin
        case(state_reg)
            IDLE: begin
                if (start) state_reg <= PARSE_0;
                else state_reg <= IDLE;
            end
            PARSE_0: begin
                valid_reg[0] = is_valid(in0);
                state_reg <= PARSE_1;
            end
            PARSE_1: begin
                valid_reg[1] = is_valid(in1);
                state_reg <= PARSE_2;
            end
            PARSE_2: begin
                valid_reg[2] = is_valid(in2);
                state_reg <= PARSE_3;
            end
            PARSE_3: begin
                valid_reg[3] = is_valid(in3);
                state_reg <= FILTER;
            end
            FILTER: begin
                temp_count_reg <= valid_reg[0] + valid_reg[1] + valid_reg[2] + valid_reg[3];
                temp_buf_reg[0] = (valid_reg[0] ? in0 : valid_reg[1] ? in1 : valid_reg[2] ? in2 : valid_reg[3] ? in3 : 16'b0);
                temp_buf_reg[1] = (valid_reg[0] ? (valid_reg[1] ? in1 : valid_reg[2] ? in2 : valid_reg[3] ? in3 : 16'b0) : (valid_reg[1] ? (valid_reg[2] ? in2 : valid_reg[3] ? in3 : 16'b0) : (valid_reg[2] ? in2 : valid_reg[3] ? in3 : 16'b0)));
                temp_buf_reg[2] = (valid_reg[0] ? (valid_reg[1] ? (valid_reg[2] ? in2 : valid_reg[3] ? in3 : 16'b0) : (valid_reg[2] ? in2 : valid_reg[3] ? in3 : 16'b0)) : (valid_reg[1] ? (valid_reg[2] ? in2 : valid_reg[3] ? in3 : 16'b0) : (valid_reg[2] ? in2 : valid_reg[3] ? in3 : 16'b0)));
                temp_buf_reg[3] = (valid_reg[0] ? (valid_reg[1] ? (valid_reg[2] ? (valid_reg[3] ? in3 : 16'b0) : (valid_reg[3] ? in3 : 16'b0)) : (valid_reg[1] ? (valid_reg[2] ? (valid_reg[3] ? in3 : 16'b0) : (valid_reg[3] ? in3 : 16'b0)) : (valid_reg[2] ? (valid_reg[3] ? in3 : 16'b0) : (valid_reg[3] ? in3 : 16'b0)))) : (valid_reg[1] ? (valid_reg[2] ? (valid_reg[3] ? in3 : 16'b0) : (valid_reg[3] ? in3 : 16'b0)) : (valid_reg[2] ? (valid_reg[3] ? in3 : 16'b0) : (valid_reg[3] ? in3 : 16'b0))));
                state_reg <= SORT;
            end
            SORT: begin
                sorted_buf_reg <= insertion_sort(temp_buf_reg, temp_count_reg);
                state_reg <= DONE;
            end
            DONE: begin
                count_reg <= temp_count_reg;
                done_reg <= 1'b1;
                out0_reg <= sorted_buf_reg[0];
                out1_reg <= sorted_buf_reg[1];
                out2_reg <= sorted_buf_reg[2];
                out3_reg <= sorted_buf_reg[3];
                state_reg <= DONE;
            end
        endcase
    end
end

assign out0 = out0_reg;
assign out1 = out1_reg;
assign out2 = out2_reg;
assign out3 = out3_reg;
assign count = count_reg;
assign done = done_reg;

function is_valid;
    input [13:0] num;
    wire [13:0] n = num;
    wire zero = (n == 0);
    wire valid;
    valid = 1'b1;
    if (zero) valid = 1'b0;
    else begin
        wire [3:0] d0 = n % 10;
        wire d0_even = d0 % 2 == 0;
        if (d0_even) valid = 1'b0;
        else begin
            wire [13:0] n1 = n / 10;
            if (n1 == 0) valid = 1'b1;
            else begin
                wire [3:0] d1 = n1 % 10;
                wire d1_even = d1 % 2 == 0;
                if (d1_even) valid = 1'b0;
                else begin
                    wire [13:0] n2 = n1 / 10;
                    if (n2 == 0) valid = 1'b1;
                    else begin
                        wire [3:0] d2 = n2 % 10;
                        wire d2_even = d2 % 2 == 0;
                        if (d2_even) valid = 1'b0;
                        else begin
                            wire [13:0] n3 = n2 / 10;
                            if (n3 == 0) valid = 1'b1;
                            else begin
                                wire [3:0] d3 = n3 % 10;
                                wire d3_even = d3 % 2 == 0;
                                if (d3_even) valid = 1'b0;
                                else valid = 1'b1;
                            end
                        end
                    end
                end
            end
        end
    end
    is_valid = valid;
endfunction

function [3:0][13:0] insertion_sort;
    input [3:0][13:0] data;
    input [2:0] count;
    wire [3:0][13:0] sorted;
    assign sorted[0] = data[0];
    assign sorted[1] = data[1];
    assign sorted[2] = data[2];
    assign sorted[3] = data[3];
    if (count <= 1) begin
        // No change
    end else begin
        if (data[1] < data[0]) begin
            sorted[0] = data[1];
            sorted[1] = data[0];
        end
        if (count >= 3) begin
            wire [13:0] key = data[2];
            if (key < sorted[1]) begin
                sorted[2] = sorted[1];
                if (key < sorted[0]) begin
                    sorted[1] = sorted[0];
                    sorted[0] = key;
                end else begin
                    sorted[1] = key;
                end
            end else if (key < sorted[0]) begin
                sorted[2] = sorted[1];
                sorted[1] = sorted[0];
                sorted[0] = key;
            end
        end
        if (count == 4) begin
            wire [13:0] key = data[3];
            if (key < sorted[2]) begin
                sorted[3] = sorted[2];
                if (key < sorted[1]) begin
                    sorted[2] = sorted[1];
                    if (key < sorted[0]) begin
                        sorted[1] = sorted[0];
                        sorted[0] = key;
                    end else begin
                        sorted[1] = key;
                    end
                end else begin
                    sorted[2] = key;
                end
            end else if (key < sorted[1]) begin
                sorted[3] = sorted[1];
                sorted[2] = sorted[1];
                if (key < sorted[0]) begin
                    sorted[1] = sorted[0];
                    sorted[0] = key;
                end else begin
                    sorted[1] = key;
                end
            end else if (key < sorted[0]) begin
                sorted[3] = sorted[0];
                sorted[2] = sorted[1];
                sorted[1] = sorted[0];
                sorted[0] = key;
            end
        end
    end
    insertion_sort = sorted;
endfunction
endmodule