module permutation_generator(input clk, input rst_n, input start, input [9:0] N, input [5:0] A, input [5:0] B, output reg [9:0] data_out, output reg valid_out, output reg done);
reg [2:0] state_reg;
reg [9:0] n_reg, a_reg, b_reg;
reg [10:0] base_reg;
reg [5:0] rem_count_reg;
reg [31:0] current_val;
reg [3:0] group_index;
reg [31:0] group_element_count;

always @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= 3'b0;
        n_reg <= 10'd0;
        a_reg <= 6'd0;
        b_reg <= 6'd0;
        base_reg <= 11'd0;
        rem_count_reg <= 6'd0;
        current_val <= 32'd0;
        group_index <= 4'd0;
        group_element_count <= 32'd0;
    end else begin
        case (state_reg)
            3'b0:
                if (start == 1) begin
                    state_reg <= 3'b1;
                end
            3'b1:
                n_reg <= N;
                a_reg <= A;
                b_reg <= B;
                if (b_reg > 1) begin
                    integer rem = n_reg - a_reg;
                    if (rem < 0) rem = 0;
                    base_reg <= rem / (b_reg - 1);
                    rem_count_reg <= rem % (b_reg - 1);
                end else begin
                    base_reg <= 11'd0;
                    rem_count_reg <= 6'd0;
                end
                if (b_reg == 0) begin
                    state_reg <= 3'b3;
                end else begin
                    state_reg <= 3'b2;
                    current_val <= n_reg;
                    group_index <= 4'd0;
                    group_element_count <= 32'd0;
                end
            3'b2:
                if (group_index >= b_reg) begin
                    state_reg <= 3'b3;
                    valid_out = 1'b0;
                    done = 1'b1;
                    data_out = 10'd0;
                end else begin
                    if (group_index < b_reg - 1) begin
                        sz = base_reg + (group_index < rem_count_reg ? 1 : 0);
                    end else begin
                        sz = a_reg;
                    end
                    if (group_element_count < sz) begin
                        if (group_index < b_reg - 1) begin
                            data_out = current_val - group_element_count;
                        end else begin
                            data_out = group_element_count + 1;
                        end
                        valid_out = 1'b1;
                        group_element_count <= group_element_count + 1;
                    end else begin
                        valid_out = 1'b0;
                        group_element_count <= 32'd0;
                        if (group_index < b_reg - 1) begin
                            current_val <= current_val - sz;
                        end
                        group_index <= group_index + 1;
                    end
                    done = 1'b0;
                end
            3'b3:
                state_reg <= 3'b3;
                valid_out = 1'b0;
                done = 1'b1;
                data_out = 10'd0;
        endcase
    end
end

endmodule