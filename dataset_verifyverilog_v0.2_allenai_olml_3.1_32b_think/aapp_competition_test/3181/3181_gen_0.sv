module construct_sequence (
    input clk,
    input rst_n,
    input start,
    input [4:0] N_in,
    input [4:0] K_in,
    output reg [4:0] sequence_out,
    output reg valid,
    output reg done,
    output reg error
);

reg [2:0] state;
reg [4:0] reg_N, reg_K;
reg [3:0] block_sizes [15:0];
reg [4:0] current_start, current_value;
reg [3:0] block_idx, inner_counter;
reg [4:0] N, K;
reg error_flag, done_flag, valid_flag;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 0;
        reg_N <= 0;
        reg_K <= 0;
        error_flag <= 0;
        done_flag <= 0;
        valid_flag <= 0;
        current_start <= 0;
        block_idx <= 0;
        inner_counter <= 0;
        // block_sizes can be don't care
    end else begin
        if (state == 0) begin // IDLE
            if (start) begin
                reg_N <= N_in;
                reg_K <= K_in;
                state <= 1;
            end
        end else if (state == 1) begin // SETUP
            if (reg_K > reg_N) begin
                error_flag <= 1;
                done_flag <= 1;
                valid_flag <= 0;
                state <= 3;
            end else if (reg_K < 1) begin
                error_flag <= 1;
                done_flag <= 1;
                valid_flag <= 0;
                state <= 3;
            end else if ((reg_K == 1) && (reg_N != 1)) begin
                error_flag <= 1;
                done_flag <= 1;
                valid_flag <= 0;
                state <= 3;
            end else if (reg_N > (reg_K * reg_K)) begin
                error_flag <= 1;
                done_flag <= 1;
                valid_flag <= 0;
                state <= 3;
            end else begin
                // Calculate block sizes
                integer base, rem;
                base = reg_N / reg_K;
                rem = reg_N % reg_K;
                for (int i=0; i<reg_K; i++) begin
                    if (i < rem) begin
                        block_sizes[i] <= base + 1;
                    end else begin
                        block_sizes[i] <= base;
                    end
                end
                state <= 2;
                current_start <= 1;
                block_idx <= 0;
                inner_counter <= 0;
                error_flag <= 0;
                done_flag <= 0;
                valid_flag <= 0;
            end
        end else if (state == 2) begin // GENERATE
            if (block_idx >= reg_K) begin
                state <= 3;
                done_flag <= 1;
                valid_flag <= 0;
            end else begin
                reg [3:0] s = block_sizes[block_idx];
                if (inner_counter < s) begin
                    current_value = current_start + s - 1 - inner_counter;
                    sequence_out <= current_value;
                    valid_flag <= 1;
                    if (inner_counter == s - 1) begin
                        if (block_idx == reg_K - 1) begin
                            done_flag <= 1;
                        end
                        block_idx <= block_idx + 1;
                        current_start <= current_start + s;
                        inner_counter <= 0;
                    end else begin
                        inner_counter <= inner_counter + 1;
                    end
                end else begin
                    // This should not happen
                    state <= 3;
                    done_flag <= 1;
                    valid_flag <= 0;
                end
            end
        end else begin // FINISHED
            state <= 3;
        end
    end
endmodule