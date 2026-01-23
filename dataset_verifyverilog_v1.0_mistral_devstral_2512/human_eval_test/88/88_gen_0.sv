module conditional_sorter(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LOAD        = 3'd1;
    localparam [2:0] CHECK_SUM   = 3'd2;
    localparam [2:0] SORT_INIT   = 3'd3;
    localparam [2:0] SORT_COMPARE = 3'd4;
    localparam [2:0] SORT_SWAP   = 3'd5;
    localparam [2:0] OUTPUT      = 3'd6;

    reg [2:0] state, next_state;
    reg [7:0] internal_arr [0:7];
    reg [7:0] sum_first_last;
    reg sort_ascending;
    reg [7:0] i, j;
    reg [7:0] temp;
    reg swap_needed;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            swap_needed <= 1'b0;
            sort_ascending <= 1'b0;
            sum_first_last <= 8'd0;
            for (temp = 0; temp < 8; temp = temp + 1) begin
                internal_arr[temp] <= 8'd0;
                result[temp] <= 8'd0;
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
                    next_state = LOAD;
                end
            end
            LOAD: begin
                next_state = CHECK_SUM;
            end
            CHECK_SUM: begin
                next_state = SORT_INIT;
            end
            SORT_INIT: begin
                next_state = SORT_COMPARE;
            end
            SORT_COMPARE: begin
                if (swap_needed) begin
                    next_state = SORT_SWAP;
                end else if (i == 8'd6 && j == 8'd7) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = SORT_COMPARE;
                end
            end
            SORT_SWAP: begin
                next_state = SORT_COMPARE;
            end
            OUTPUT: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Load input array
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state register
        end else if (state == LOAD) begin
            for (temp = 0; temp < 8; temp = temp + 1) begin
                internal_arr[temp] <= arr[temp];
            end
        end
    end

    // Calculate sum and determine sort direction
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled
        end else if (state == CHECK_SUM) begin
            sum_first_last <= internal_arr[0] + internal_arr[7];
            sort_ascending <= sum_first_last[0];
        end
    end

    // Bubble sort logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled
        end else begin
            case (state)
                SORT_INIT: begin
                    i <= 8'd0;
                    j <= 8'd0;
                    swap_needed <= 1'b0;
                end
                SORT_COMPARE: begin
                    if (j < 8'd7 - i) begin
                        if (sort_ascending) begin
                            swap_needed <= (internal_arr[j] > internal_arr[j + 1]);
                        end else begin
                            swap_needed <= (internal_arr[j] < internal_arr[j + 1]);
                        end
                        if (swap_needed) begin
                            // Will swap in next state
                        end else begin
                            j <= j + 8'd1;
                        end
                    end else begin
                        i <= i + 8'd1;
                        j <= 8'd0;
                    end
                end
                SORT_SWAP: begin
                    temp <= internal_arr[j];
                    internal_arr[j] <= internal_arr[j + 1];
                    internal_arr[j + 1] <= temp;
                    j <= j + 8'd1;
                    swap_needed <= 1'b0;
                end
                OUTPUT: begin
                    for (temp = 0; temp < 8; temp = temp + 1) begin
                        result[temp] <= internal_arr[temp];
                    end
                    done <= 1'b1;
                end
                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state != IDLE && state != OUTPUT) begin
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state = IDLE;
                done <= 1'b0;
                cycle_count <= 8'd0;
            end
        end else begin
            cycle_count <= 8'd0;
        end
    end

endmodule