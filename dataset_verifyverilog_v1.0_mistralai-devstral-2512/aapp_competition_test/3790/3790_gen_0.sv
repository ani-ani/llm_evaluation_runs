module LongestNonDecreasingSequence(
    input clk,
    input rst_n,
    input start,
    input [6:0] n_i,
    input [23:0] T_i,
    input [8:0] arr_i,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_INPUT = 3'd1;
    localparam [2:0] COMPUTE_FREQ = 3'd2;
    localparam [2:0] BUILD_2N_ARRAY = 3'd3;
    localparam [2:0] LIS_LOOP = 3'd4;
    localparam [2:0] RESULT_CALC = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state, next_state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Input buffer for array elements
    reg [8:0] arr_buffer [0:99];
    reg [6:0] arr_index;

    // Frequency counting
    reg [23:0] freq_count [0:300];
    reg [23:0] max_freq;
    reg [8:0] freq_index;

    // 2n array generation
    reg [8:0] two_n_array [0:199];
    reg [6:0] two_n_index;

    // BIT for LIS computation
    reg [15:0] bit_tree [0:511];
    reg [8:0] bit_index;
    reg [15:0] current_lis;
    reg [15:0] max_lis;

    // Intermediate results
    reg [15:0] lis_2n;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            arr_index <= 7'd0;
            freq_index <= 9'd0;
            two_n_index <= 7'd0;
            bit_index <= 9'd0;
            current_lis <= 16'd0;
            max_lis <= 16'd0;
            lis_2n <= 16'd0;
            max_freq <= 24'd0;

            // Initialize frequency counts
            integer i;
            for (i = 0; i < 301; i = i + 1) begin
                freq_count[i] <= 24'd0;
            end

            // Initialize BIT tree
            for (i = 0; i < 512; i = i + 1) begin
                bit_tree[i] <= 16'd0;
            end

            // Initialize array buffers
            for (i = 0; i < 100; i = i + 1) begin
                arr_buffer[i] <= 9'd0;
            end

            for (i = 0; i < 200; i = i + 1) begin
                two_n_array[i] <= 9'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        next_state <= READ_INPUT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                READ_INPUT: begin
                    if (arr_index < n_i) begin
                        arr_buffer[arr_index] <= arr_i;
                        arr_index <= arr_index + 7'd1;
                        next_state <= READ_INPUT;
                    end else begin
                        arr_index <= 7'd0;
                        next_state <= COMPUTE_FREQ;
                    end
                end

                COMPUTE_FREQ: begin
                    if (freq_index < 9'd300) begin
                        if (freq_index < n_i) begin
                            reg [8:0] val = arr_buffer[freq_index];
                            if (val > 9'd0 && val <= 9'd300) begin
                                freq_count[val] <= freq_count[val] + 24'd1;
                            end
                        end
                        freq_index <= freq_index + 9'd1;
                        next_state <= COMPUTE_FREQ;
                    end else begin
                        // Find max frequency
                        integer i;
                        max_freq <= 24'd0;
                        for (i = 1; i <= 300; i = i + 1) begin
                            if (freq_count[i] > max_freq) begin
                                max_freq <= freq_count[i];
                            end
                        end
                        freq_index <= 9'd0;
                        next_state <= BUILD_2N_ARRAY;
                    end
                end

                BUILD_2N_ARRAY: begin
                    if (two_n_index < 7'd200) begin
                        two_n_array[two_n_index] <= arr_buffer[two_n_index % n_i];
                        two_n_index <= two_n_index + 7'd1;
                        next_state <= BUILD_2N_ARRAY;
                    end else begin
                        two_n_index <= 7'd0;
                        bit_index <= 9'd0;
                        current_lis <= 16'd0;
                        max_lis <= 16'd0;
                        next_state <= LIS_LOOP;
                    end
                end

                LIS_LOOP: begin
                    if (bit_index < 9'd200) begin
                        reg [8:0] val = two_n_array[bit_index];
                        reg [15:0] query_result = bit_query(val);
                        current_lis <= query_result + 16'd1;
                        if (current_lis > max_lis) begin
                            max_lis <= current_lis;
                        end
                        bit_update(val, current_lis);
                        bit_index <= bit_index + 9'd1;
                        next_state <= LIS_LOOP;
                    end else begin
                        lis_2n <= max_lis;
                        bit_index <= 9'd0;
                        next_state <= RESULT_CALC;
                    end
                end

                RESULT_CALC: begin
                    if (T_i <= 24'd2) begin
                        result <= lis_2n;
                    end else begin
                        reg [31:0] temp = (T_i - 24'd2) * max_freq;
                        result <= lis_2n + temp;
                    end
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // BIT query function
    function [15:0] bit_query;
        input [8:0] idx;
        integer i;
        reg [15:0] res;
        begin
            res = 16'd0;
            i = idx + 1;
            while (i > 0) begin
                if (bit_tree[i] > res) begin
                    res = bit_tree[i];
                end
                i = i - (i & -i);
            end
            bit_query = res;
        end
    endfunction

    // BIT update function
    function void bit_update;
        input [8:0] idx;
        input [15:0] val;
        integer i;
        begin
            i = idx + 1;
            while (i <= 512) begin
                if (val > bit_tree[i]) begin
                    bit_tree[i] = val;
                end
                i = i + (i & -i);
            end
        end
    endfunction

endmodule