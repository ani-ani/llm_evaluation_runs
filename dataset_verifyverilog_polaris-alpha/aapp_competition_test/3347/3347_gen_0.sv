module gold_store_optimizer(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [15:0] t_i_0,
    input [15:0] h_i_0,
    input [15:0] t_i_1,
    input [15:0] h_i_1,
    input [15:0] t_i_2,
    input [15:0] h_i_2,
    input [15:0] t_i_3,
    input [15:0] h_i_3,
    input [15:0] t_i_4,
    input [15:0] h_i_4,
    input [15:0] t_i_5,
    input [15:0] h_i_5,
    input [15:0] t_i_6,
    input [15:0] h_i_6,
    input [15:0] t_i_7,
    input [15:0] h_i_7,
    output reg [3:0] max_count,
    output reg done
);

    // State encoding
    localparam IDLE        = 2'b00;
    localparam SORT        = 2'b01;
    localparam ACCUMULATE  = 2'b10;
    localparam DONE_STATE  = 2'b11;

    reg [1:0] state, next_state;

    // Internal arrays for sorting and processing
    reg [15:0] t_arr [0:7];
    reg [15:0] h_arr [0:7];

    // Bubble sort indices
    reg [3:0] sort_i;  // outer loop (0..n-1)
    reg [3:0] sort_j;  // inner loop (0..n-2)

    // Temporary for swap
    reg [15:0] tmp_t;
    reg [15:0] tmp_h;

    // Accumulation
    reg [31:0] total_time;
    reg [3:0]  idx;

    // Start edge detect
    reg start_d;
    wire start_pulse = start & ~start_d;

    // Sequential logic for state and registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            start_d    <= 1'b0;
            done       <= 1'b0;
            max_count  <= 4'd0;

            sort_i     <= 4'd0;
            sort_j     <= 4'd0;
            total_time <= 32'd0;
            idx        <= 4'd0;

            t_arr[0]   <= 16'd0; h_arr[0] <= 16'd0;
            t_arr[1]   <= 16'd0; h_arr[1] <= 16'd0;
            t_arr[2]   <= 16'd0; h_arr[2] <= 16'd0;
            t_arr[3]   <= 16'd0; h_arr[3] <= 16'd0;
            t_arr[4]   <= 16'd0; h_arr[4] <= 16'd0;
            t_arr[5]   <= 16'd0; h_arr[5] <= 16'd0;
            t_arr[6]   <= 16'd0; h_arr[6] <= 16'd0;
            t_arr[7]   <= 16'd0; h_arr[7] <= 16'd0;
        end else begin
            start_d <= start;
            state   <= next_state;

            case (state)
                IDLE: begin
                    // Wait for start pulse; load inputs when pulse occurs (in next_state logic)
                    if (start_pulse) begin
                        done      <= 1'b0;
                        max_count <= 4'd0;

                        // Load arrays from inputs
                        t_arr[0] <= t_i_0; h_arr[0] <= h_i_0;
                        t_arr[1] <= t_i_1; h_arr[1] <= h_i_1;
                        t_arr[2] <= t_i_2; h_arr[2] <= h_i_2;
                        t_arr[3] <= t_i_3; h_arr[3] <= h_i_3;
                        t_arr[4] <= t_i_4; h_arr[4] <= h_i_4;
                        t_arr[5] <= t_i_5; h_arr[5] <= h_i_5;
                        t_arr[6] <= t_i_6; h_arr[6] <= h_i_6;
                        t_arr[7] <= t_i_7; h_arr[7] <= h_i_7;

                        // Initialize sort indices
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;

                        // Prepare accumulation
                        total_time <= 32'd0;
                        idx        <= 4'd0;
                    end
                end

                SORT: begin
                    if (n > 0) begin
                        // Perform one compare-swap per cycle: ascending by height
                        if (sort_j < (n - 1 - sort_i)) begin
                            if (h_arr[sort_j] > h_arr[sort_j + 1]) begin
                                // swap
                                tmp_h                 <= h_arr[sort_j];
                                tmp_t                 <= t_arr[sort_j];
                                h_arr[sort_j]         <= h_arr[sort_j + 1];
                                t_arr[sort_j]         <= t_arr[sort_j + 1];
                                h_arr[sort_j + 1]     <= tmp_h;
                                t_arr[sort_j + 1]     <= tmp_t;
                            end
                            sort_j <= sort_j + 1'b1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 1'b1;
                        end
                    end

                    // When bubble sort completes, ACCUMULATE will start via next_state logic
                end

                ACCUMULATE: begin
                    // Process one store per cycle
                    if (idx < n) begin
                        // Check if we can include this store
                        if (total_time + t_arr[idx] <= h_arr[idx]) begin
                            total_time <= total_time + t_arr[idx];
                            max_count  <= max_count + 1'b1;
                        end
                        idx <= idx + 1'b1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1; // hold done high until next start or reset
                    // No internal changes here except done/max_count hold
                end

                default: begin
                    // Should not occur
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start_pulse && (n != 4'd0)) begin
                    next_state = SORT;
                end else begin
                    next_state = IDLE;
                end
            end

            SORT: begin
                if ((n == 4'd0)) begin
                    next_state = DONE_STATE;
                end else if (sort_i >= (n - 1)) begin
                    // Completed bubble sort passes
                    next_state = ACCUMULATE;
                end else begin
                    next_state = SORT;
                end
            end

            ACCUMULATE: begin
                if (idx >= n) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = ACCUMULATE;
                end
            end

            DONE_STATE: begin
                // Stay in DONE until a new start pulse (with non-zero n)
                if (start_pulse) begin
                    if (n == 4'd0)
                        next_state = DONE_STATE;
                    else
                        next_state = SORT;
                end else begin
                    next_state = DONE_STATE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule