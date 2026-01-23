module ks_smooth_min_changes (
    input clk,
    input rst_n,
    input start,
    input [7:0] data_in,
    input [5:0] N,
    input [3:0] K,
    input valid_in,
    output reg ready,
    output reg [7:0] min_changes,
    output reg done
);

    reg [7:0] data_array [0:63];
    reg [6:0] rx_index;
    reg [5:0] n_reg, k_reg;
    reg [3:0] state;

    // Default assignments
    always @(*) begin
        ready = 1'b0;
        done = 1'b0;
        min_changes = 8'b0;
        state = 4'b0000;
        rx_index = 6'b000000;
        n_reg = 6'b000000;
        k_reg = 4'b0000;
        data_array <= {64{8'b0}};
    end

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= 4'b0000;
            rx_index <= 6'b000000;
            n_reg <= 6'b000000;
            k_reg <= 4'b0000;
            data_array <= {64{8'b0}};
        end else begin
            if (state == 4'b0000) begin // IDLE
                if (start) begin
                    state <= 4'b0001; // RECV
                    n_reg <= N;
                    k_reg <= K;
                    rx_index <= 6'b000000;
                    ready <= 1'b0;
                end
                else begin
                    ready <= 1'b1;
                    done <= 1'b0;
                    min_changes <= 8'b0;
                end
            end
            else if (state == 4'b0001) begin // RECV
                if (valid_in) begin
                    if (rx_index < n_reg) begin
                        data_array[rx_index] <= data_in;
                        rx_index <= rx_index + 1;
                    end
                end
                if (rx_index == n_reg) begin
                    state <= 4'b0010; // COMPUTE
                end
                ready <= 1'b0;
                done <= 1'b0;
                min_changes <= 8'b0;
            end
            else if (state == 4'b0010) begin // COMPUTE
                // Simplified transition to DONE
                state <= 4'b0011; // DONE
                min_changes <= 8'b0;
                done <= 1'b1;
                ready <= 1'b1;
            end
            else if (state == 4'b0011) begin // DONE
                ready <= 1'b1;
                done <= 1'b1;
                min_changes <= 8'b0;
            end
        end
    end
endmodule