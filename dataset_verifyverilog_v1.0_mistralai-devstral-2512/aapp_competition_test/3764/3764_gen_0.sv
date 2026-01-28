module RangerSimulator(
    input clk,
    input rst_n,
    input start,
    input [3:0] n_in,
    input [3:0] k_in,
    input [9:0] x_in,
    input [7:0][9:0] arr_in,
    output reg [9:0] max_out,
    output reg [9:0] min_out,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SORTING   = 3'd1;
    localparam [2:0] XORING    = 3'd2;
    localparam [2:0] CHECKING  = 3'd3;
    localparam [2:0] FINISHED  = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] iter_count;
    reg [3:0] sort_cycle;
    reg [9:0] arr [0:7];
    reg [9:0] temp;
    integer i, j;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            iter_count <= 4'd0;
            sort_cycle <= 4'd0;
            done <= 1'b0;
            max_out <= 10'd0;
            min_out <= 10'd0;
            for (i = 0; i < 8; i = i + 1) begin
                arr[i] <= 10'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    // Load input array
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < n_in)
                            arr[i] = arr_in[i];
                        else
                            arr[i] = 10'd0;
                    end
                    if (k_in == 4'd0) begin
                        // Special case: k=0, output immediately
                        next_state = FINISHED;
                    end else begin
                        next_state = SORTING;
                        sort_cycle = 4'd0;
                    end
                end
            end

            SORTING: begin
                // Bubble sort implementation
                if (sort_cycle < 4'd7) begin
                    for (i = 0; i < 7 - sort_cycle; i = i + 1) begin
                        if (arr[i] > arr[i + 1]) begin
                            temp = arr[i];
                            arr[i] = arr[i + 1];
                            arr[i + 1] = temp;
                        end
                    end
                    sort_cycle = sort_cycle + 4'd1;
                end else begin
                    next_state = XORING;
                end
            end

            XORING: begin
                // Apply XOR to even indices
                for (i = 0; i < 8; i = i + 2) begin
                    if (i < n_in)
                        arr[i] = arr[i] ^ x_in;
                end
                next_state = CHECKING;
            end

            CHECKING: begin
                // Check if we've done k iterations
                if (iter_count < k_in - 4'd1) begin
                    iter_count = iter_count + 4'd1;
                    next_state = SORTING;
                    sort_cycle = 4'd0;
                end else begin
                    next_state = FINISHED;
                end
            end

            FINISHED: begin
                // Find max and min
                max_out = 10'd0;
                min_out = 10'd1023;
                for (i = 0; i < 8; i = i + 1) begin
                    if (i < n_in) begin
                        if (arr[i] > max_out) max_out = arr[i];
                        if (arr[i] < min_out) min_out = arr[i];
                    end
                end
                done = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Update array registers
    always @(posedge clk) begin
        if (state == SORTING || state == XORING) begin
            for (i = 0; i < 8; i = i + 1) begin
                arr[i] <= arr[i];
            end
        end
    end

endmodule