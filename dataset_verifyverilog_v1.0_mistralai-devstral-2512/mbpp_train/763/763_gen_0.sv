module min_abs_diff(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SORT    = 2'd1;
    localparam [1:0] COMPARE = 2'd2;
    localparam [1:0] DONE    = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] sorted_arr [0:7];
    reg [8:0] min_diff;
    reg [7:0] i, j;
    reg [7:0] temp;
    reg swap_flag;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            min_diff <= 9'd0;
            i <= 8'd0;
            j <= 8'd0;
            swap_flag <= 1'b0;
            // Initialize sorted array
            integer k;
            for (k = 0; k < 8; k = k + 1) begin
                sorted_arr[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Copy input array to sorted array
                        integer k;
                        for (k = 0; k < 8; k = k + 1) begin
                            sorted_arr[k] <= arr[k];
                        end
                        next_state <= SORT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= COMPARE;
                    end else begin
                        // Bubble sort pass
                        if (j == 8'd0) begin
                            swap_flag <= 1'b0;
                            i <= 8'd0;
                        end

                        if (i < len - 1) begin
                            if (sorted_arr[i] > sorted_arr[i + 1]) begin
                                // Swap
                                temp <= sorted_arr[i];
                                sorted_arr[i] <= sorted_arr[i + 1];
                                sorted_arr[i + 1] <= temp;
                                swap_flag <= 1'b1;
                            end
                            i <= i + 8'd1;
                        end else begin
                            if (swap_flag) begin
                                i <= 8'd0;
                                j <= j + 8'd1;
                            end else begin
                                next_state <= COMPARE;
                            end
                        end
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE;
                    end else begin
                        if (i == 8'd0) begin
                            min_diff <= 9'd255;  // Initialize to max possible
                        end

                        if (i < len - 1) begin
                            // Compute absolute difference
                            if (sorted_arr[i] > sorted_arr[i + 1]) begin
                                temp <= sorted_arr[i] - sorted_arr[i + 1];
                            end else begin
                                temp <= sorted_arr[i + 1] - sorted_arr[i];
                            end

                            // Update min_diff
                            if (temp < min_diff) begin
                                min_diff <= temp;
                            end

                            i <= i + 8'd1;
                        end else begin
                            next_state <= DONE;
                        end
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    result <= min_diff;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule