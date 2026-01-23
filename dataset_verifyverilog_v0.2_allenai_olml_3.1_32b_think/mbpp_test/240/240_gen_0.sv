module replace_list (
    input clk,
    input rst_n,
    input start,
    input [7:0] list1_len,
    input [7:0] list2_len,
    input [2:0] list1_addr,
    input [7:0] list1_data_in,
    input [2:0] list2_addr,
    input [2:0] list2_data_in,
    input load_done,
    output reg [2:0] result_addr,
    output reg [7:0] result_data,
    output reg result_valid,
    output reg done,
    output reg [3:0] result_len
);

// Internal signals
reg [1:0] state;
reg [7:0] list1_len_reg;
reg [7:0] list2_len_reg;
reg [3:0] result_length;
reg [3:0] result_counter;
reg [7:0] list1_mem [7:0];
reg [7:0] list2_mem [7:0];

always @(negedge rst_n) begin
    state <= 2'b00;
    list1_len_reg <= 8'b0;
    list2_len_reg <= 8'b0;
    result_length <= 4'b0;
    result_counter <= 4'b0;
    list1_mem[0] <= 8'b0;
    list1_mem[1] <= 8'b0;
    list1_mem[2] <= 8'b0;
    list1_mem[3] <= 8'b0;
    list1_mem[4] <= 8'b0;
    list1_mem[5] <= 8'b0;
    list1_mem[6] <= 8'b0;
    list1_mem[7] <= 8'b0;
    list2_mem[0] <= 8'b0;
    list2_mem[1] <= 8'b0;
    list2_mem[2] <= 8'b0;
    list2_mem[3] <= 8'b0;
    list2_mem[4] <= 8'b0;
    list2_mem[5] <= 8'b0;
    list2_mem[6] <= 8'b0;
    list2_mem[7] <= 8'b0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 2'b00;
        list1_len_reg <= 8'b0;
        list2_len_reg <= 8'b0;
        result_length <= 4'b0;
        result_counter <= 4'b0;
    end else begin
        case (state)
            2'b00: begin
                if (start) state <= 2'b01;
            end
            2'b01: begin
                if (load_done) begin
                    list1_len_reg <= list1_len;
                    list2_len_reg <= list2_len;
                    result_length <= list1_len_reg + list2_len_reg - 1;
                    if (result_length > 0) state <= 2'b10;
                    else state <= 2'b11;
                end
            end
            2'b10: begin
                if (result_counter < result_length) begin
                    if (result_counter < (list1_len_reg - 1)) begin
                        result_data <= list1_mem[result_counter];
                    end else begin
                        if (result_counter - (list1_len_reg - 1) < list2_len_reg) begin
                            result_data <= list2_mem[result_counter - (list1_len_reg - 1)];
                        end else begin
                            result_data <= 8'b0;
                        end
                    end
                    result_addr <= result_counter;
                    result_valid <= 1'b1;
                    if (result_counter == result_length -1) begin
                        result_counter <= result_length;
                    end else begin
                        result_counter <= result_counter +1;
                    end
                end else begin
                    result_valid <= 1'b0;
                    done <= 1'b1;
                    state <= 2'b11;
                end
            end
            2'b11: begin
                if (start) begin
                    state <= 2'b00;
                    result_valid <=1'b0;
                    done <=1'b0;
                end
            end
        endcase
    end
end

assign result_len = result_length;

endmodule