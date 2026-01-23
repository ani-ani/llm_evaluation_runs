module change_base(input clk, input rst_n, input start, input [7:0] x, input [3:0] base, output reg [31:0] result, output reg [3:0] num_digits, output reg done);
reg [7:0] current_value;
reg [31:0] digits;
reg [3:0] num_digits;
reg [15:0] cycle_counter;
reg [2:0] state;
reg [31:0] result_reg;
reg [3:0] num_digits_reg;
reg done_reg;

reg [7:0] quotient, remainder;

always @(*) begin
    if (base == 0) begin
        quotient = 0;
        remainder = current_value;
    end else begin
        remainder = current_value % base;
        quotient = current_value / base;
    end
end

always @(negedge rst_n) begin
    current_value <= 0;
digits <= 0;
num_digits <= 0;
cycle_counter <= 0;
state <= 0;
result_reg <= 0;
num_digits_reg <= 0;
done_reg <= 0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        current_value <= 0;
digits <= 0;
num_digits <= 0;
cycle_counter <= 0;
state <= 0;
result_reg <= 0;
num_digits_reg <= 0;
done_reg <= 0;
    end else begin
        if (state == 0) begin // IDLE
            if (start) begin
                current_value <= x;
digits <= 0;
num_digits <= 0;
cycle_counter <= 15;
state <= 1; // COMPUTE
            end
        end else if (state == 1) begin // COMPUTE
            if (cycle_counter > 0) begin
                if (current_value != 0 || (num_digits == 0 && current_value == 0)) begin
                    if (current_value != 0) begin
                        digits <= digits << 4 | remainder;
current_value <= quotient;
num_digits <= num_digits + 1;
                    end else begin
                        // Handle x=0 case
                        digits <= digits << 4 | 4'b0;
num_digits <= 1;
                    end
                end
                cycle_counter <= cycle_counter - 1;
            end else begin // cycle_counter == 0, move to DONE
                state <= 2; // DONE
                result_reg <= digits;
num_digits_reg <= num_digits;
done_reg <= 1;
            end
        end else if (state == 2) begin // DONE
            // Remain in DONE state
        end
    end
end

assign result = result_reg;
assign num_digits = num_digits_reg;
assign done = done_reg;

endmodule