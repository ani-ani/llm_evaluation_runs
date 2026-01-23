module check_if_last_char_is_a_letter (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [127:0] string_data,
    input [3:0] string_len,
    output reg result,
    output reg done
);

localparam IDLE = 2'b00,
        PROCESSING = 2'b01,
        WAIT = 2'b10,
        DONE = 2'b11;

reg [1:0] state;
reg [7:0] result_int;
reg result_reg;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result_int <= 8'b0;
        result_reg <= 1'b0;
    end else begin
        // Handle start-triggered transitions
        if (start == 1) begin
            if (state == IDLE) begin
                state <= PROCESSING;
            end else if (state == DONE) begin
                state <= IDLE;
            end
        end

        // State transitions
        if (state == PROCESSING) begin
            state <= WAIT;
        end else if (state == WAIT) begin
            state <= DONE;
        end

        // Compute result_int in PROCESSING state
        if (state == PROCESSING) begin
            integer len = string_len;
            if (len == 0) begin
                result_int <= 8'b0;
            end else begin
                integer shift = (len * 8) - 8;
                logic [7:0] last_char = string_data >> shift;
                last_char = last_char & 8'hFF;
                if ((last_char >= 8'h41 && last_char <= 8'h5A) || (last_char >= 8'h61 && last_char <= 8'h7A)) begin
                    if (len == 1) begin
                        result_int <= 1'b1;
                    end else begin
                        integer prev_shift = shift - 8;
                        logic [7:0] prev_char = string_data >> prev_shift;
                        prev_char = prev_char & 8'hFF;
                        if (prev_char == 8'h20) begin
                            result_int <= 1'b1;
                        end else begin
                            result_int <= 1'b0;
                        end
                    end
                end else begin
                    result_int <= 1'b0;
                end
            end
        end else if (state == DONE) begin
            result_reg <= result_int;
        end
    end
end

// Assign outputs
assign done = (state == DONE);
assign result = result_reg;

endmodule