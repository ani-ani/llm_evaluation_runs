module tuple_modulo (
    input clk,
    input rst_n,
    input start,
    input [7:0] tuple1 [0:3],
    input [7:0] tuple2 [0:3],
    output reg [7:0] result [0:3],
    output reg done
);

reg [1:0] current_element;
reg [7:0] dividend, divisor, remainder;
reg [2:0] compute_counter;
reg [1:0] state;
reg [7:0] result_reg [0:3];
reg done_reg;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        current_element <= 2\'b00;
        dividend <= 8\'b0;
        divisor <= 8\'b0;
        remainder <= 8\'b0;
        compute_counter <= 3\'b011;
        state <= 2\'b00;
        done_reg <= 1\'b0;
    end else begin
        if (state == 2\'b00) begin // IDLE
            if (start == 1\'b1) begin
                state <= 2\'b01; // LOAD
            end
        end else if (state == 2\'b01) begin // LOAD
            dividend <= tuple1[current_element];
            divisor <= tuple2[current_element];
            remainder <= dividend;
            compute_counter <= 3\'b011;
            state <= 2\'b10; // COMPUTE
        end else if (state == 2\'b10) begin // COMPUTE
            if (compute_counter == 3\'b000) begin
                state <= 2\'b11; // STORE
            end else begin
                compute_counter <= compute_counter - 1;
                if (remainder >= divisor) begin
                    remainder <= remainder - divisor;
                end
                state <= 2\'b10;
            end
        end else if (state == 2\'b11) begin // STORE
            result_reg[current_element] <= remainder;
            if (current_element == 2\'b11) begin // Last element?
                done_reg <= 1\'b1;
                state <= 2\'b00; // Return to IDLE
            end else begin
                current_element <= current_element + 1;
                state <= 2\'b01; // LOAD next element
            end
        end
    end
end

// Assign outputs
assign result = result_reg;
assign done = done_reg;

endmodule