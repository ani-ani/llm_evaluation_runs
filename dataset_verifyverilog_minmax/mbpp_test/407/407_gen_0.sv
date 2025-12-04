module next_bigger_num (
    input clk,
    input rst_n,
    input start,
    input [9:0] num,
    output reg [9:0] next_num,
    output reg done,
    output reg no_bigger
);

    parameter [2:0] IDLE = 3'd0,
                   FIND_PIVOT = 3'd1,
                   FIND_MIN = 3'd2,
                   SWAP_SORT = 3'd3,
                   VALID = 3'd4;

    reg [2:0] state;
    reg [3:0] hundreds_reg, tens_reg, units_reg;
    reg [3:0] new_hundreds_reg, new_tens_reg, new_units_reg;
    reg [1:0] pivot_index;
    reg has_pivot;
    reg [3:0] next_digit;

    always @(posedge clk) begin
        if (rst_n == 0) begin
            state <= IDLE;
            done <= 1'b0;
            no_bigger <= 1'b0;
            next_num <= 10'd0;
        end
        else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        hundreds_reg <= num / 100;
                        tens_reg <= (num % 100) / 10;
                        units_reg <= num % 10;
                        state <= FIND_PIVOT;
                    end
                end
                FIND_PIVOT: begin
                    if (tens_reg < units_reg) begin
                        pivot_index <= 2'd1;
                        has_pivot <= 1'b1;
                    end
                    else if (hundreds_reg < tens_reg) begin
                        pivot_index <= 2'd0;
                        has_pivot <= 1'b1;
                    end
                    else begin
                        has_pivot <= 1'b0;
                    end
                    state <= FIND_MIN;
                end
                FIND_MIN: begin
                    if (has_pivot) begin
                        if (pivot_index == 1) begin
                            next_digit <= units_reg;
                        end
                        else if (pivot_index == 0) begin
                            next_digit <= 4'd15;
                            if (tens_reg > hundreds_reg) next_digit <= tens_reg;
                            if (units_reg > hundreds_reg && units_reg < next_digit) next_digit <= units_reg;
                        end
                    end
                    state <= SWAP_SORT;
                end
                SWAP_SORT: begin
                    if (has_pivot) begin
                        if (pivot_index == 1) begin
                            new_tens_reg <= units_reg;
                            new_units_reg <= tens_reg;
                            new_hundreds_reg <= hundreds_reg;
                        end
                        else if (pivot_index == 0) begin
                            if (next_digit == tens_reg) begin
                                new_hundreds_reg <= tens_reg;
                                new_tens_reg <= hundreds_reg;
                                new_units_reg <= units_reg;
                            end
                            else if (next_digit == units_reg) begin
                                new_hundreds_reg <= units_reg;
                                new_tens_reg <= tens_reg;
                                new_units_reg <= hundreds_reg;
                            end
                            if (new_tens_reg > new_units_reg) begin
                                new_tens_reg <= new_units_reg;
                                new_units_reg <= new_tens_reg;
                            end
                        end
                    end
                    state <= VALID;
                end
                VALID: begin
                    if (has_pivot) begin
                        next_num <= new_hundreds_reg * 100 + new_tens_reg * 10 + new_units_reg;
                        done <= 1'b1;
                        no_bigger <= 1'b0;
                    end
                    else begin
                        done <= 1'b1;
                        no_bigger <= 1'b1;
                    end
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule