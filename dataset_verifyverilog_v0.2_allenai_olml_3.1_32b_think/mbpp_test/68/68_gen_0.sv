module is_monotonic (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] data_in,
    input [2:0] index,
    output reg result,
    output reg done
);

parameter integer N = 8;
localparam IDLE = 3'b000,
        LOADING = 3'b001,
        PROCESSING = 3'b010,
        DONE = 3'b100;

reg [7:0] array_reg [7:0];
reg [2:0] expected_index;
reg [2:0] state;
reg non_dec, non_inc;
reg result_temp;

// Initialize registers
always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        expected_index <= 3'b000;
        // array_reg is initialized to 0 automatically
        non_dec <= 1'bX;
        non_inc <= 1'bX;
        result_temp <= 1'b0;
        result <= 1'b0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: 
                if (start) state <= LOADING;
                else state <= IDLE;
            LOADING: 
                if (start) begin
                    if (index == expected_index) begin
                        array_reg[index] <= data_in;
                        expected_index <= expected_index + 1;
                        if (expected_index == N) begin
                            state <= PROCESSING;
                        end else begin
                            state <= LOADING;
                        end
                    end else begin
                        state <= LOADING;
                    end
                end else begin
                    state <= LOADING;
                end
            PROCESSING: 
                // Compute monotonic
                non_dec = 1'b1;
                non_inc = 1'b1;
                if (array_reg[0] > array_reg[1]) non_dec = 1'b0;
                if (array_reg[1] > array_reg[2]) non_dec = 1'b0;
                if (array_reg[2] > array_reg[3]) non_dec = 1'b0;
                if (array_reg[3] > array_reg[4]) non_dec = 1'b0;
                if (array_reg[4] > array_reg[5]) non_dec = 1'b0;
                if (array_reg[5] > array_reg[6]) non_dec = 1'b0;
                if (array_reg[6] > array_reg[7]) non_dec = 1'b0;
                if (array_reg[0] < array_reg[1]) non_inc = 1'b0;
                if (array_reg[1] < array_reg[2]) non_inc = 1'b0;
                if (array_reg[2] < array_reg[3]) non_inc = 1'b0;
                if (array_reg[3] < array_reg[4]) non_inc = 1'b0;
                if (array_reg[4] < array_reg[5]) non_inc = 1'b0;
                if (array_reg[5] < array_reg[6]) non_inc = 1'b0;
                if (array_reg[6] < array_reg[7]) non_inc = 1'b0;
                result_temp = non_dec || non_inc;
                state <= DONE;
            DONE: 
                result <= result_temp;
                done <= 1'b1;
                if (start) begin
                    state <= IDLE;
                    done <= 1'b0;
                    result_temp <= 1'b0;
                end else begin
                    state <= DONE;
                end
        endcase
    end
end

endmodule