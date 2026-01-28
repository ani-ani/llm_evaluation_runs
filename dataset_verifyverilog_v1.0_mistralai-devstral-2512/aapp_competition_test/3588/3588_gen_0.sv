module ShareTracker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [8:0] data_in,
    input wire load_cmd,
    input wire data_valid,
    output reg [15:0] result,
    output reg [7:0] day_out,
    output reg output_valid,
    output reg done,
    output reg [3:0] output_index
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INPUT     = 3'd1;
    localparam [2:0] SORT      = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    localparam [2:0] COMPLETE  = 3'd4;

    reg [2:0] state, next_state;

    // Record storage
    reg [8:0] shares [0:9];
    reg [7:0] days [0:9];
    reg [3:0] record_count;

    // Day accumulation
    reg [15:0] sum_shares [0:127];
    reg [7:0] unique_days [0:15];
    reg [15:0] unique_sums [0:15];
    reg [3:0] unique_count;

    // Sorting variables
    reg [3:0] sort_i, sort_j;
    reg [7:0] temp_day;
    reg [15:0] temp_sum;

    // Output variables
    reg [3:0] output_ptr;

    // Cycle counter for safety
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            record_count <= 4'd0;
            unique_count <= 4'd0;
            output_ptr <= 4'd0;
            output_index <= 4'd0;
            result <= 16'd0;
            day_out <= 8'd0;
            output_valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize arrays
            integer i;
            for (i = 0; i < 10; i = i + 1) begin
                shares[i] <= 9'd0;
                days[i] <= 8'd0;
            end
            for (i = 0; i < 128; i = i + 1) begin
                sum_shares[i] <= 16'd0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                unique_days[i] <= 8'd0;
                unique_sums[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    output_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= INPUT;
                        record_count <= 4'd0;
                        unique_count <= 4'd0;
                        output_ptr <= 4'd0;
                        output_index <= 4'd0;
                        cycle_count <= 8'd0;

                        // Clear arrays
                        integer i;
                        for (i = 0; i < 10; i = i + 1) begin
                            shares[i] <= 9'd0;
                            days[i] <= 8'd0;
                        end
                        for (i = 0; i < 128; i = i + 1) begin
                            sum_shares[i] <= 16'd0;
                        end
                        for (i = 0; i < 16; i = i + 1) begin
                            unique_days[i] <= 8'd0;
                            unique_sums[i] <= 16'd0;
                        end
                    end
                end

                INPUT: begin
                    output_valid <= 1'b0;
                    done <= 1'b0;
                    if (data_valid) begin
                        if (!load_cmd) begin
                            // Load shares
                            shares[record_count] <= data_in;
                        end else begin
                            // Load day
                            days[record_count] <= data_in[7:0];
                            record_count <= record_count + 4'd1;
                        end
                    end

                    // Check if we have all records or input stopped
                    if ((record_count >= 4'd10) || (!start && !data_valid)) begin
                        next_state <= SORT;
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;

                        // Accumulate shares per day
                        integer i;
                        for (i = 0; i < record_count; i = i + 1) begin
                            sum_shares[days[i]] <= sum_shares[days[i]] + shares[i];
                        end

                        // Extract unique days
                        reg [7:0] day_list [0:127];
                        integer idx, day_idx;
                        for (idx = 0; idx < 128; idx = idx + 1) begin
                            day_list[idx] <= idx;
                        end

                        unique_count <= 4'd0;
                        for (day_idx = 0; day_idx < 128; day_idx = day_idx + 1) begin
                            if (sum_shares[day_idx] > 16'd0) begin
                                unique_days[unique_count] <= day_list[day_idx];
                                unique_sums[unique_count] <= sum_shares[day_idx];
                                unique_count <= unique_count + 4'd1;
                            end
                        end
                    end
                end

                SORT: begin
                    output_valid <= 1'b0;
                    done <= 1'b0;

                    // Bubble sort implementation
                    if (sort_i < unique_count - 4'd1) begin
                        if (sort_j < unique_count - sort_i - 4'd1) begin
                            if (unique_days[sort_j] > unique_days[sort_j + 4'd1]) begin
                                // Swap days
                                temp_day <= unique_days[sort_j];
                                unique_days[sort_j] <= unique_days[sort_j + 4'd1];
                                unique_days[sort_j + 4'd1] <= temp_day;

                                // Swap sums
                                temp_sum <= unique_sums[sort_j];
                                unique_sums[sort_j] <= unique_sums[sort_j + 4'd1];
                                unique_sums[sort_j + 4'd1] <= temp_sum;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 4'd1;
                        end
                    end else begin
                        next_state <= OUTPUT;
                        output_ptr <= 4'd0;
                        output_index <= 4'd0;
                    end
                end

                OUTPUT: begin
                    if (output_ptr < unique_count) begin
                        if (unique_days[output_ptr] > 8'd0) begin
                            result <= unique_sums[output_ptr];
                            day_out <= unique_days[output_ptr];
                            output_valid <= 1'b1;
                            output_index <= output_ptr;
                            output_ptr <= output_ptr + 4'd1;
                        end else begin
                            output_ptr <= output_ptr + 4'd1;
                        end
                    end else begin
                        next_state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    output_valid <= 1'b0;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    output_valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule