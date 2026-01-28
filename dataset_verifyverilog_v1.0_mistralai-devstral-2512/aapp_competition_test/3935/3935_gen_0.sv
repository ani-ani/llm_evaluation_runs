module bipartite_min_remove(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [63:0] arr [0:15],
    output reg [63:0] result [0:15],
    output reg [3:0] result_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_V2 = 3'd1;
    localparam [2:0] BUILD_HISTOGRAM = 3'd2;
    localparam [2:0] FIND_MAX_V2 = 3'd3;
    localparam [2:0] FILTER_RESULTS = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // V2 computation
    reg [5:0] current_idx;
    reg [5:0] v2 [0:15];
    reg [5:0] v2_temp;
    reg [5:0] bit_pos;

    // Histogram
    reg [3:0] histogram [0:63];
    reg [5:0] max_v2;
    reg [3:0] max_count;

    // Result filtering
    reg [3:0] result_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            current_idx <= 6'd0;
            bit_pos <= 6'd0;
            v2_temp <= 6'd0;
            max_v2 <= 6'd0;
            max_count <= 4'd0;
            result_idx <= 4'd0;
            done <= 1'b0;
            result_len <= 4'd0;

            // Initialize arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                v2[i] <= 6'd0;
                result[i] <= 64'd0;
            end

            for (i = 0; i < 64; i = i + 1) begin
                histogram[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_len <= 4'd0;
                    cycle_count <= 8'd0;
                    current_idx <= 6'd0;
                    if (start) begin
                        next_state <= COMPUTE_V2;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_V2: begin
                    if (current_idx < len) begin
                        if (bit_pos == 6'd0) begin
                            v2_temp <= 6'd0;
                        end

                        if (bit_pos < 64) begin
                            if (arr[current_idx][bit_pos] == 1'b0) begin
                                v2_temp <= v2_temp + 6'd1;
                            end else begin
                                v2[current_idx] <= v2_temp;
                                bit_pos <= 6'd0;
                                current_idx <= current_idx + 6'd1;
                            end
                            bit_pos <= bit_pos + 6'd1;
                        end
                        next_state <= COMPUTE_V2;
                    end else begin
                        current_idx <= 6'd0;
                        bit_pos <= 6'd0;
                        next_state <= BUILD_HISTOGRAM;
                    end
                end

                BUILD_HISTOGRAM: begin
                    if (current_idx < len) begin
                        histogram[v2[current_idx]] <= histogram[v2[current_idx]] + 4'd1;
                        current_idx <= current_idx + 6'd1;
                        next_state <= BUILD_HISTOGRAM;
                    end else begin
                        current_idx <= 6'd0;
                        max_v2 <= 6'd0;
                        max_count <= 4'd0;
                        next_state <= FIND_MAX_V2;
                    end
                end

                FIND_MAX_V2: begin
                    if (current_idx < 64) begin
                        if (histogram[current_idx] > max_count) begin
                            max_count <= histogram[current_idx];
                            max_v2 <= current_idx;
                        end
                        current_idx <= current_idx + 6'd1;
                        next_state <= FIND_MAX_V2;
                    end else begin
                        current_idx <= 6'd0;
                        result_idx <= 4'd0;
                        next_state <= FILTER_RESULTS;
                    end
                end

                FILTER_RESULTS: begin
                    if (current_idx < len) begin
                        if (v2[current_idx] != max_v2) begin
                            result[result_idx] <= arr[current_idx];
                            result_idx <= result_idx + 4'd1;
                        end
                        current_idx <= current_idx + 6'd1;
                        next_state <= FILTER_RESULTS;
                    end else begin
                        result_len <= result_idx;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
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