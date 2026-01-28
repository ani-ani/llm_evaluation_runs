module PowerOfKCounter(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr [0:15],
    input [3:0] len,
    input [2:0] k,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE_POWERS = 4'd1;
    localparam [3:0] PREFIX_SUM = 4'd2;
    localparam [3:0] COUNT_SEGMENTS = 4'd3;
    localparam [3:0] FINISH = 4'd4;

    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Power computation
    reg signed [31:0] current_power;
    reg signed [31:0] powers [0:15];
    reg [3:0] power_count;
    reg [3:0] power_index;

    // Prefix sum computation
    reg signed [15:0] prefix [0:15];
    reg [3:0] prefix_index;

    // Frequency table
    reg [15:0] freq_table [0:15];
    reg [3:0] freq_index;
    reg [3:0] lookup_index;
    reg [3:0] power_lookup_index;

    // Counting
    reg [15:0] temp_result;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            current_power <= 32'd0;
            power_count <= 4'd0;
            power_index <= 4'd0;
            prefix_index <= 4'd0;
            freq_index <= 4'd0;
            lookup_index <= 4'd0;
            power_lookup_index <= 4'd0;
            temp_result <= 16'd0;

            // Initialize arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                powers[i] <= 32'd0;
                prefix[i] <= 16'd0;
                freq_table[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE_POWERS;
                    end
                end

                COMPUTE_POWERS: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute powers of k
                    if (power_count == 4'd0) begin
                        // Initialize first power
                        if (k == 3'd0) begin
                            powers[0] <= 32'd1;
                            power_count <= 4'd1;
                        end else if (k == 3'd1 || k == 3'd7) begin
                            powers[0] <= 32'd1;
                            power_count <= 4'd1;
                        end else if (k == 3'd6) begin
                            powers[0] <= 32'd1;
                            powers[1] <= 32'd6;
                            power_count <= 4'd2;
                        end else begin
                            powers[0] <= 32'd1;
                            current_power <= 32'd1;
                            power_count <= 4'd1;
                        end
                    end else begin
                        // Compute next power
                        if (power_count < 4'd16) begin
                            current_power <= current_power * k;
                            if (current_power > 32'd65535 || current_power < 32'd-65535) begin
                                // Stop if power exceeds range
                                state <= PREFIX_SUM;
                            end else begin
                                powers[power_count] <= current_power;
                                power_count <= power_count + 4'd1;
                            end
                        end else begin
                            state <= PREFIX_SUM;
                        end
                    end

                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                PREFIX_SUM: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute prefix sums
                    if (prefix_index == 4'd0) begin
                        prefix[0] <= arr[0];
                        prefix_index <= 4'd1;
                    end else if (prefix_index < len) begin
                        prefix[prefix_index] <= prefix[prefix_index - 4'd1] + arr[prefix_index];
                        prefix_index <= prefix_index + 4'd1;
                    end else begin
                        // Initialize frequency table with first prefix
                        freq_table[0] <= prefix[0];
                        freq_index <= 4'd1;
                        state <= COUNT_SEGMENTS;
                    end

                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                COUNT_SEGMENTS: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Update frequency table and count segments
                    if (freq_index < len) begin
                        // Check all powers for current prefix
                        if (power_lookup_index < power_count) begin
                            // Check if (prefix[freq_index] - powers[power_lookup_index]) exists in freq_table
                            integer j;
                            for (j = 0; j < freq_index; j = j + 1) begin
                                if (prefix[j] == (prefix[freq_index] - powers[power_lookup_index])) begin
                                    temp_result <= temp_result + 16'd1;
                                end
                            end

                            power_lookup_index <= power_lookup_index + 4'd1;
                        end else begin
                            // Add current prefix to frequency table
                            freq_table[freq_index] <= prefix[freq_index];
                            freq_index <= freq_index + 4'd1;
                            power_lookup_index <= 4'd0;
                        end
                    end else begin
                        result <= temp_result;
                        state <= FINISH;
                    end

                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule