module PowerSupply(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] k,
    input wire [31:0] batteries [0:31],
    output reg [15:0] result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] READ_INPUT = 4'd1;
    localparam [3:0] SORT = 4'd2;
    localparam [3:0] BINARY_SEARCH = 4'd3;
    localparam [3:0] ALLOC_CHECK = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    reg [3:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Input registers
    reg [31:0] battery_reg [0:31];
    reg [4:0] total_batteries;

    // Sorting registers
    reg [31:0] sorted_batteries [0:31];
    reg [4:0] sort_i, sort_j;
    reg sort_done;

    // Binary search registers
    reg [15:0] low, high, mid;
    reg [3:0] search_iter;
    localparam [3:0] MAX_ITER = 4'd10;

    // Allocation check registers
    reg [4:0] alloc_i, alloc_j;
    reg [2:0] machine_count;
    reg [31:0] current_min, current_max;
    reg alloc_valid;

    // FSM state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 16'd0;
            sort_done <= 1'b0;
            search_iter <= 4'd0;
            machine_count <= 3'd0;
            alloc_valid <= 1'b0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        next_state <= READ_INPUT;
                        cycle_count <= 8'd0;
                    end
                end

                READ_INPUT: begin
                    total_batteries <= 2 * n * k;
                    // Copy input batteries to registers
                    integer i;
                    for (i = 0; i < 32; i = i + 1) begin
                        battery_reg[i] <= batteries[i];
                    end
                    next_state <= SORT;
                end

                SORT: begin
                    if (!sort_done) begin
                        // Simple bubble sort implementation
                        if (sort_j == 0) begin
                            sort_i <= sort_i + 5'd1;
                            if (sort_i >= total_batteries - 5'd1) begin
                                sort_done <= 1'b1;
                            end
                        end else begin
                            sort_j <= sort_j - 5'd1;
                        end

                        // Perform comparison and swap
                        if (sort_i < total_batteries - 5'd1 && !sort_done) begin
                            if (sorted_batteries[sort_i] > sorted_batteries[sort_i + 5'd1]) begin
                                reg [31:0] temp;
                                temp <= sorted_batteries[sort_i];
                                sorted_batteries[sort_i] <= sorted_batteries[sort_i + 5'd1];
                                sorted_batteries[sort_i + 5'd1] <= temp;
                            end
                            sort_j <= 5'd31;
                        end
                    end else begin
                        next_state <= BINARY_SEARCH;
                        low <= 16'd0;
                        high <= 16'd1023;
                        search_iter <= 4'd0;
                    end
                end

                BINARY_SEARCH: begin
                    if (search_iter < MAX_ITER) begin
                        mid <= (low + high) / 2;
                        next_state <= ALLOC_CHECK;
                        alloc_i <= 5'd0;
                        alloc_j <= 5'd0;
                        machine_count <= 3'd0;
                        alloc_valid <= 1'b1;
                    end else begin
                        result <= mid;
                        next_state <= DONE_STATE;
                    end
                end

                ALLOC_CHECK: begin
                    if (alloc_valid) begin
                        if (machine_count < n) begin
                            if (alloc_j < 2 * k - 5'd1) begin
                                // Check if current pair is valid
                                if (sorted_batteries[alloc_i + alloc_j] > sorted_batteries[alloc_i + alloc_j + 5'd1]) begin
                                    current_min <= sorted_batteries[alloc_i + alloc_j + 5'd1];
                                    current_max <= sorted_batteries[alloc_i + alloc_j];
                                end else begin
                                    current_min <= sorted_batteries[alloc_i + alloc_j];
                                    current_max <= sorted_batteries[alloc_i + alloc_j + 5'd1];
                                end

                                if (current_max - current_min <= mid) begin
                                    alloc_j <= alloc_j + 5'd2;
                                end else begin
                                    alloc_valid <= 1'b0;
                                end
                            end else begin
                                machine_count <= machine_count + 3'd1;
                                alloc_i <= alloc_i + 5'd1;
                                alloc_j <= 5'd0;
                            end
                        end else begin
                            // All machines allocated successfully
                            high <= mid;
                            next_state <= BINARY_SEARCH;
                            search_iter <= search_iter + 4'd1;
                        end
                    end else begin
                        // Allocation failed, try higher d
                        low <= mid + 16'd1;
                        next_state <= BINARY_SEARCH;
                        search_iter <= search_iter + 4'd1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Initialize sorted batteries on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                sorted_batteries[i] <= 32'd0;
            end
            sort_i <= 5'd0;
            sort_j <= 5'd0;
            sort_done <= 1'b0;
        end else if (state == READ_INPUT) begin
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                sorted_batteries[i] <= battery_reg[i];
            end
            sort_i <= 5'd0;
            sort_j <= 5'd0;
            sort_done <= 1'b0;
        end
    end

endmodule