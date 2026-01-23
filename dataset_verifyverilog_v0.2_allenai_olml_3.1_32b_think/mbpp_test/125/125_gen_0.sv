module max_diff_substring (input clk, input rst_n, input start, input [7:0] binary_string, output reg [3:0] max_diff, output reg done);

reg [1:0] state;
reg [3:0] current_sum;
reg [3:0] max_sum;
reg [2:0] index;
reg [7:0] bin_str_reg;
reg [3:0] max_diff_reg;

always @(negedge rst_n) begin
    state <= 2'b00;
current_sum <= 4'b0;
max_sum <= 4'b0;
index <= 3'b111;
bin_str_reg <= 8'b0;
max_diff_reg <= 4'b0;
end

always @(posedge clk) begin
    bin_str_reg <= binary_string;

    if (!rst_n) begin
        state <= 2'b00;
current_sum <= 4'b0;
max_sum <= 4'b0;
index <= 3'b111;
max_diff_reg <= 4'b0;
    end else begin
        case(state)
            2'b00: begin
                if (start) begin
                    current_sum <= 4'b0;
max_sum <= 4'b0;
index <= 3'b111;
state <= 2'b01;
                end
            end
            2'b01: begin
                integer bit_val;
                if (bin_str_reg[index] == 0) begin
                    bit_val = 1;
                end else begin
                    bit_val = -1;
                end

                current_sum_next = current_sum + bit_val;
                if (current_sum_next < 0) begin
                    current_sum_next = 0;
                end

                if (current_sum_next > max_sum) begin
                    max_sum_next = current_sum_next;
                end else begin
                    max_sum_next = max_sum;
                end

                if (index == 0) begin
                    state_next = 2'b10;
max_diff_reg <= max_sum_next;
index_next = 0;
                end else begin
                    state_next = 2'b01;
index_next = index - 1;
                end

                current_sum <= current_sum_next;
max_sum <= max_sum_next;
            end
            2'b10: begin
            end
        endcase

        max_diff <= max_diff_reg;
    end
end

assign done = (state == 2'b10);

endmodule