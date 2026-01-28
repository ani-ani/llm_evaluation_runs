module PermutationGenerator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [23:0] N,
    input wire [19:0] K,
    output reg [15:0] data,
    output reg valid,
    output reg done,
    output reg error
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] GENERATE_BLOCK = 3'd2;
    localparam [2:0] OUTPUT_BLOCK = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;

    // Counters and registers
    reg [19:0] block_size;
    reg [19:0] current_block;
    reg [19:0] current_number;
    reg [19:0] block_start;
    reg [19:0] block_end;
    reg [19:0] numbers_output;
    reg [19:0] cycle_count;

    // Block size calculation
    always @(*) begin
        if (K == 0) begin
            block_size = 20'd0;
        end else begin
            block_size = (N + K - 1) / K;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            data <= 16'd0;
            valid <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            current_block <= 20'd0;
            current_number <= 20'd0;
            block_start <= 20'd0;
            block_end <= 20'd0;
            numbers_output <= 20'd0;
            cycle_count <= 20'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK;
                end
            end

            CHECK: begin
                if (K == 1 && N > 1) begin
                    next_state = FINISH;
                end else if (K == N) begin
                    next_state = OUTPUT_BLOCK;
                end else begin
                    next_state = GENERATE_BLOCK;
                end
            end

            GENERATE_BLOCK: begin
                if (current_block < K && block_start < N) begin
                    next_state = OUTPUT_BLOCK;
                end else begin
                    next_state = FINISH;
                end
            end

            OUTPUT_BLOCK: begin
                if (numbers_output == N) begin
                    next_state = FINISH;
                end else if (current_number == block_start - 1) begin
                    next_state = GENERATE_BLOCK;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(*) begin
        data = 16'd0;
        valid = 1'b0;
        done = 1'b0;
        error = 1'b0;

        case (state)
            IDLE: begin
                // Reset outputs
                data = 16'd0;
                valid = 1'b0;
                done = 1'b0;
                error = 1'b0;
            end

            CHECK: begin
                if (K == 1 && N > 1) begin
                    error = 1'b1;
                    done = 1'b1;
                end
            end

            GENERATE_BLOCK: begin
                // Calculate block boundaries
                block_start = current_block * block_size + 1;
                block_end = (current_block + 1) * block_size;
                if (block_end > N) begin
                    block_end = N;
                end
                current_number = block_end;
            end

            OUTPUT_BLOCK: begin
                if (current_number <= N) begin
                    data = current_number[15:0];
                    valid = 1'b1;
                    numbers_output = numbers_output + 1;
                    current_number = current_number - 1;
                end
                if (numbers_output == N) begin
                    done = 1'b1;
                end
            end

            FINISH: begin
                done = 1'b1;
            end

            default: begin
                data = 16'd0;
                valid = 1'b0;
                done = 1'b0;
                error = 1'b0;
            end
        endcase
    end

    // Block counter increment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_block <= 20'd0;
        end else begin
            if (state == OUTPUT_BLOCK && current_number == block_start - 1) begin
                current_block <= current_block + 1;
            end
        end
    end

endmodule