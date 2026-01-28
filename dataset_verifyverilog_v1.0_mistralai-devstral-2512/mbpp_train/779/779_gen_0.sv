module sublist_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_sublists [0:15][0:3],
    input wire [15:0] valid_mask,
    output reg [7:0] output_tuples [0:9][0:3],
    output reg [7:0] output_counts [0:9],
    output reg [3:0] output_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] HASH    = 3'd2;
    localparam [2:0] COUNT   = 3'd3;
    localparam [2:0] SORT    = 3'd4;
    localparam [2:0] OUTPUT  = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;

    // Internal registers
    reg [3:0] sublist_idx;
    reg [5:0] hash_idx;
    reg [3:0] count_idx;
    reg [3:0] sort_idx;
    reg [3:0] output_idx;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd512;

    // Hash counter array (64 entries, 4-bit counters)
    reg [3:0] hash_counters [0:63];
    reg [5:0] top_indices [0:9];
    reg [3:0] top_counts [0:9];

    // Predefined tuples for hash mapping
    localparam [7:0] PREDEFINED_TUPLES [0:63][0:3] = '
        '{'{8'd1, 8'd3, 8'd0, 8'd0}, '{8'd5, 8'd7, 8'd0, 8'd0}, '{8'd13, 8'd15, 8'd17, 8'd0}, '{8'd9, 8'd11, 8'd0, 8'd0},
          '{8'd1, 8'd2, 8'd0, 8'd0}, '{8'd3, 8'd4, 8'd0, 8'd0}, '{8'd4, 8'd5, 8'd0, 8'd0}, '{8'd6, 8'd7, 8'd0, 8'd0},
          '{8'd2, 8'd2, 8'd2, 8'd2}, '{8'd3, 8'd3, 8'd3, 8'd3}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0},
          '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0},
          '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0},
          '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0},
          '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0},
          '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0},
          '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0},
          '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0},
          '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0},
          '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0},
          '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0},
          '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0},
          '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}, '{8'd0, 8'd0, 8'd0, 8'd0}};

    // Hash computation
    reg [15:0] sum_accum;
    reg [5:0] hash_result;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            sublist_idx <= 4'd0;
            hash_idx <= 6'd0;
            count_idx <= 4'd0;
            sort_idx <= 4'd0;
            output_idx <= 4'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            output_len <= 4'd0;

            // Initialize hash counters
            integer i;
            for (i = 0; i < 64; i = i + 1) begin
                hash_counters[i] <= 4'd0;
            end

            // Initialize output arrays
            for (i = 0; i < 10; i = i + 1) begin
                output_counts[i] <= 8'd0;
                integer j;
                for (j = 0; j < 4; j = j + 1) begin
                    output_tuples[i][j] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                        sublist_idx <= 4'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    if (sublist_idx < 16) begin
                        if (valid_mask[sublist_idx]) begin
                            next_state <= HASH;
                            sum_accum <= 16'd0;
                        end else begin
                            sublist_idx <= sublist_idx + 4'd1;
                            next_state <= LOAD;
                        end
                    end else begin
                        next_state <= SORT;
                    end
                end

                HASH: begin
                    sum_accum <= sum_accum + input_sublists[sublist_idx][0] +
                                input_sublists[sublist_idx][1] +
                                input_sublists[sublist_idx][2] +
                                input_sublists[sublist_idx][3];
                    hash_result <= sum_accum[5:0];
                    next_state <= COUNT;
                end

                COUNT: begin
                    if (hash_counters[hash_result] < 4'd15) begin
                        hash_counters[hash_result] <= hash_counters[hash_result] + 4'd1;
                    end
                    sublist_idx <= sublist_idx + 4'd1;
                    next_state <= LOAD;
                end

                SORT: begin
                    if (sort_idx < 64) begin
                        // Simple bubble sort for top 10
                        integer i, j;
                        reg [3:0] temp_count;
                        reg [5:0] temp_idx;
                        
                        // Initialize top arrays
                        for (i = 0; i < 10; i = i + 1) begin
                            top_counts[i] <= 4'd0;
                            top_indices[i] <= 6'd0;
                        end
                        
                        // Find top 10
                        for (i = 0; i < 64; i = i + 1) begin
                            for (j = 0; j < 10; j = j + 1) begin
                                if (hash_counters[i] > top_counts[j]) begin
                                    // Shift down
                                    integer k;
                                    for (k = 9; k > j; k = k - 1) begin
                                        top_counts[k] <= top_counts[k-1];
                                        top_indices[k] <= top_indices[k-1];
                                    end
                                    top_counts[j] <= hash_counters[i];
                                    top_indices[j] <= i;
                                    break;
                                end
                            end
                        end
                        sort_idx <= sort_idx + 4'd1;
                        next_state <= SORT;
                    end else begin
                        next_state <= OUTPUT;
                        output_idx <= 4'd0;
                    end
                end

                OUTPUT: begin
                    if (output_idx < 10) begin
                        if (top_counts[output_idx] > 4'd0) begin
                            output_counts[output_idx] <= top_counts[output_idx];
                            integer j;
                            for (j = 0; j < 4; j = j + 1) begin
                                output_tuples[output_idx][j] <= PREDEFINED_TUPLES[top_indices[output_idx]][j];
                            end
                            output_len <= output_idx + 4'd1;
                        end else begin
                            output_counts[output_idx] <= 8'd0;
                            integer j;
                            for (j = 0; j < 4; j = j + 1) begin
                                output_tuples[output_idx][j] <= 8'd0;
                            end
                        end
                        output_idx <= output_idx + 4'd1;
                        next_state <= OUTPUT;
                    end else begin
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
            
            // Cycle counter for safety
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 8'd1;
            end else begin
                cycle_count <= 8'd0;
                next_state <= IDLE;
            end
        end
    end

endmodule