module sum_of_digits (
    input clk,
    input rst_n,
    input start,
    input [7:0] num_count,
    input [63:0] str_data [0:7],
    output reg [15:0] result,
    output reg done
);
reg [2:0] current_num_index;
reg [2:0] current_char_index;
reg [15:0] running_sum;
reg [7:0] temp_sum;
reg [2:0] state;
localparam IDLE = 3'b000;
localparam PARSE = 3'b001;
localparam DONE = 3'b010;
always @(posedge clk) begin
    if (!rst_n) begin
        current_num_index <= 3'b0;
        current_char_index <= 3'b0;
        running_sum <= 16'b0;
        temp_sum <= 8'b0;
        state <= IDLE;
        done <= 1'b0;
    end else begin
        if (state == IDLE) begin
            if (num_count == 8'd0) begin
                done <= 1'b1;
            end else if (start) begin
                current_num_index <= 3'b0;
                current_char_index <= 3'b0;
                running_sum <= 16'b0;
                temp_sum <= 8'b0;
                state <= PARSE;
            end
        end else if (state == PARSE) begin
            [7:0] current_char_byte;
            current_char_byte = str_data[current_num_index][ (current_char_index)*8 + 7 : (current_char_index)*8 ];
            if (current_char_byte >= 8'h30 && current_char_byte <= 8'h39) begin
                temp_sum <= temp_sum + (current_char_byte - 8'h30);
            end
            if (current_char_index == 3'd7) begin
                running_sum <= running_sum + temp_sum;
                temp_sum <= 8'b0;
                if (current_num_index < num_count - 1) begin
                    current_num_index <= current_num_index + 1;
                    current_char_index <= 3'b0;
                end else begin
                    done <= 1'b1;
                    state <= DONE;
                end
            end else begin
                current_char_index <= current_char_index + 1;
            end
        end else if (state == DONE) begin
        end
    end
assign result = running_sum;
endmodule