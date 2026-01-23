module odd_collatz(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SEQ_RUN   = 3'd1;
    localparam [2:0] SEQ_CHECK = 3'd2;
    localparam [2:0] SORT_LOOP = 3'd3;
    localparam [2:0] OUTPUT    = 3'd4;
    localparam [2:0] DONE      = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] current_n;
    reg [3:0] iteration_count;
    reg [2:0] odd_count;
    reg [15:0] odd_buffer [0:7];
    reg [2:0] sort_i, sort_j;
    reg [2:0] output_index;
    reg swap_flag;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_n <= 16'd0;
            iteration_count <= 4'd0;
            odd_count <= 3'd0;
            sort_i <= 3'd0;
            sort_j <= 3'd0;
            output_index <= 3'd0;
            swap_flag <= 1'b0;
            result <= 16'd0;
            done <= 1'b0;
            // Initialize odd_buffer
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
                odd_buffer[k] <= 16'd0;
            end
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
                    next_state = SEQ_RUN;
                    current_n = n;
                    iteration_count = 4'd0;
                    odd_count = 3'd0;
                    // Reset buffer
                    integer k;
                    for (k = 0; k < 8; k = k + 1) begin
                        odd_buffer[k] = 16'd0;
                    end
                end
            end

            SEQ_RUN: begin
                next_state = SEQ_CHECK;
            end

            SEQ_CHECK: begin
                if (current_n == 16'd1 || iteration_count == 4'd15) begin
                    next_state = SORT_LOOP;
                    sort_i = 3'd0;
                    sort_j = 3'd0;
                end else begin
                    next_state = SEQ_RUN;
                end
            end

            SORT_LOOP: begin
                if (sort_i == 3'd7) begin
                    if (sort_j == 3'd7) begin
                        next_state = OUTPUT;
                        output_index = 3'd0;
                    end else begin
                        sort_j = sort_j + 3'd1;
                        sort_i = 3'd0;
                    end
                end else begin
                    sort_i = sort_i + 3'd1;
                end
            end

            OUTPUT: begin
                if (output_index == 3'd7) begin
                    next_state = DONE;
                end else begin
                    output_index = output_index + 3'd1;
                end
            end

            DONE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequence generation
    always @(posedge clk) begin
        if (state == SEQ_RUN) begin
            if (current_n[0] == 1'b0) begin
                current_n <= current_n >> 1;
            end else begin
                current_n <= (current_n * 3'd3) + 16'd1;
                if (odd_count < 3'd8) begin
                    odd_buffer[odd_count] <= current_n;
                    odd_count <= odd_count + 3'd1;
                end
            end
            iteration_count <= iteration_count + 4'd1;
        end
    end

    // Bubble sort
    always @(posedge clk) begin
        if (state == SORT_LOOP) begin
            if (sort_j < 3'd7 && odd_buffer[sort_j] > odd_buffer[sort_j + 3'd1]) begin
                // Swap
                reg [15:0] temp;
                temp = odd_buffer[sort_j];
                odd_buffer[sort_j] = odd_buffer[sort_j + 3'd1];
                odd_buffer[sort_j + 3'd1] = temp;
                swap_flag = 1'b1;
            end
        end
    end

    // Output logic
    always @(posedge clk) begin
        if (state == OUTPUT) begin
            result <= odd_buffer[output_index];
            done <= 1'b0;
        end else if (state == DONE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule