module monotone_seq_generator(
    input clk,
    input rst_n,
    input start,
    input [7:0] N,
    input [7:0] K,
    output reg [7:0] data,
    output reg [7:0] index,
    output reg valid,
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] OUTPUT  = 3'd2;
    localparam [2:0] DONE    = 3'd3;
    localparam [2:0] ERROR   = 3'd4;

    reg [2:0] state;
    reg [7:0] current_N;
    reg [7:0] current_K;
    reg [7:0] min_K;
    reg [7:0] q;
    reg [7:0] r;
    reg [7:0] block_size;
    reg [7:0] start_num;
    reg [7:0] current_block;
    reg [7:0] block_counter;
    reg [7:0] output_counter;
    reg [7:0] sqrt_N;

    // Compute sqrt(N) using iterative approximation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            data <= 8'd0;
            index <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            current_N <= 8'd0;
            current_K <= 8'd0;
            min_K <= 8'd0;
            q <= 8'd0;
            r <= 8'd0;
            block_size <= 8'd0;
            start_num <= 8'd0;
            current_block <= 8'd0;
            block_counter <= 8'd0;
            output_counter <= 8'd0;
            sqrt_N <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    done <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        current_N <= N;
                        current_K <= K;
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Compute sqrt(N) using iterative approximation
                    reg [7:0] temp_sqrt;
                    reg [7:0] i;
                    temp_sqrt <= 8'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if ((temp_sqrt + 1'b1) * (temp_sqrt + 1'b1) <= current_N) begin
                            temp_sqrt <= temp_sqrt + 1'b1;
                        end
                    end
                    sqrt_N <= temp_sqrt;

                    // Compute min_K = ceil(sqrt(N))
                    if (sqrt_N * sqrt_N < current_N) begin
                        min_K <= sqrt_N + 1'b1;
                    end else begin
                        min_K <= sqrt_N;
                    end

                    // Check for error conditions
                    if (current_K < min_K || current_K > current_N) begin
                        error <= 1'b1;
                        done <= 1'b1;
                        state <= ERROR;
                    end else begin
                        // Compute q = N/K, r = N%K
                        q <= current_N / current_K;
                        r <= current_N % current_K;
                        current_block <= 8'd0;
                        block_counter <= 8'd0;
                        output_counter <= 8'd0;
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    valid <= 1'b1;
                    done <= 1'b0;
                    error <= 1'b0;

                    // Determine block size
                    if (current_block < r) begin
                        block_size <= q + 1'b1;
                    end else begin
                        block_size <= q;
                    end

                    // Compute start_num for current block
                    if (current_block < r) begin
                        start_num <= 1'b1 + current_block * q + current_block;
                    end else begin
                        start_num <= 1'b1 + current_block * q + r;
                    end

                    // Generate decreasing sequence within block
                    data <= start_num + block_size - 1'b1 - block_counter;
                    index <= output_counter;

                    // Update counters
                    block_counter <= block_counter + 1'b1;
                    output_counter <= output_counter + 1'b1;

                    // Check if block is complete
                    if (block_counter == block_size) begin
                        block_counter <= 8'd0;
                        current_block <= current_block + 1'b1;
                    end

                    // Check if all blocks are complete
                    if (output_counter == current_N) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    error <= 1'b0;
                end

                ERROR: begin
                    valid <= 1'b0;
                    done <= 1'b1;
                    error <= 1'b1;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule