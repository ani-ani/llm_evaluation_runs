module find_largest_d (
input clk,
input rst_n,
input start,
input [23:0] data_in,
input [2:0] index,
input write_en,
output reg [23:0] result,
output reg valid,
output reg done
);
localparam INITIAL_MAX = -8388608;
reg [23:0] data [0:7];
reg [11:0] compute_counter;
reg [23:0] max_d;
reg [3:0] state;
reg [2:0] i, j, k, l;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data <= 0;
        compute_counter <= 0;
        max_d <= INITIAL_MAX;
        state <= 0;
        result <= 0;
        valid <= 0;
        done <= 0;
    end else begin
        reg [3:0] next_state;
        next_state <= state;

        case (state)
            0: begin // IDLE
                if (write_en) begin
                    next_state <= 1; // WRITE_MODE
                end else if (start) begin
                    next_state <= 2; // COMPUTE
                    compute_counter <= 0;
                    max_d <= INITIAL_MAX;
                end
            end
            1: begin // WRITE_MODE
                data[index] <= data_in;
                if (write_en) begin
                    next_state <= 1;
                end else begin
                    next_state <= 0;
                end
            end
            2: begin // COMPUTE
                i = compute_counter >> 9;
                j = (compute_counter >> 6) & 7;
                k = (compute_counter >> 3) & 7;
                l = compute_counter & 7;

                if (i != j && i != k && i != l && j != k && j != l && k != l) begin
                    if (data[i] + data[j] + data[k] == data[l]) begin
                        if (data[l] > max_d) begin
                            max_d <= data[l];
                        end
                    end
                end

                if (compute_counter == 4095) begin
                    next_state <= 3; // DONE
                end else begin
                    compute_counter <= compute_counter + 1;
                    next_state <= 2;
                end
            end
            3: begin // DONE
                if (max_d == INITIAL_MAX) begin
                    result <= 0;
                    valid <= 0;
                end else begin
                    result <= max_d;
                    valid <= 1;
                end
                done <= 1;
                next_state <= 3;
            end
        endcase

        state <= next_state;
    end
endmodule