module critical_elements (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] n,
    input wire [7:0] arr_0, arr_1, arr_2, arr_3, arr_4, arr_5, arr_6, arr_7,
    input wire [7:0] arr_8, arr_9, arr_10, arr_11, arr_12, arr_13, arr_14, arr_15,
    output reg [7:0] critical_0, critical_1, critical_2, critical_3,
    output reg [7:0] critical_4, critical_5, critical_6, critical_7,
    output reg [7:0] critical_8, critical_9, critical_10, critical_11,
    output reg [7:0] critical_12, critical_13, critical_14, critical_15,
    output reg [4:0] critical_count,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE            = 4'd0;
    localparam [3:0] COPY_INPUT      = 4'd1;
    localparam [3:0] LIS_ORIG        = 4'd2;
    localparam [3:0] CHECK_ELEMENT   = 4'd3;
    localparam [3:0] BUILD_TEMP       = 4'd4;
    localparam [3:0] LIS_TEMP         = 4'd5;
    localparam [3:0] COMPARE_LEN      = 4'd6;
    localparam [3:0] NEXT_ELEMENT     = 4'd7;
    localparam [3:0] SORT_BUBBLE      = 4'd8;
    localparam [3:0] OUTPUT_RESULT    = 4'd9;
    localparam [3:0] FINISHED         = 4'd10;

    // Internal registers for array storage
    reg [7:0] orig_arr [15:0];
    reg [7:0] temp_arr [15:0];
    reg [7:0] crit_arr [15:0];
    
    // Loop counters and states
    reg [3:0] state, next_state;
    reg [4:0] idx;
    reg [4:0] len_orig;
    reg [4:0] len_temp;
    reg [4:0] crit_idx;
    reg [4:0] sort_pass;
    reg [4:0] sort_idx;
    
    // LIS computation registers (iterative)
    reg [7:0] lis_values [15:0];  // DP values
    reg [4:0] lis_outer;
    reg [4:0] lis_inner;
    reg [4:0] lis_max;
    reg [4:0] lis_len;
    
    // Computation states for LIS
    localparam [2:0] LIS_IDLE     = 3'd0;
    localparam [2:0] LIS_INIT     = 3'd1;
    localparam [2:0] LIS_OUTER    = 3'd2;
    localparam [2:0] LIS_INNER    = 3'd3;
    localparam [2:0] LIS_UPDATE   = 3'd4;
    localparam [2:0] LIS_MAX      = 3'd5;
    localparam [2:0] LIS_DONE     = 3'd6;
    
    reg [2:0] lis_state, lis_next;
    reg [4:0] lis_array_len;
    reg [7:0] lis_source [15:0];  // Input array for LIS
    reg [4:0] lis_result_len;
    reg lis_start;
    reg lis_done_flag;
    reg [4:0] lis_count;

    // Main FSM
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = COPY_INPUT;
            COPY_INPUT: next_state = LIS_ORIG;
            LIS_ORIG: if (lis_done_flag) next_state = CHECK_ELEMENT;
            CHECK_ELEMENT: if (idx >= n) next_state = SORT_BUBBLE; else next_state = BUILD_TEMP;
            BUILD_TEMP: next_state = LIS_TEMP;
            LIS_TEMP: if (lis_done_flag) next_state = COMPARE_LEN;
            COMPARE_LEN: next_state = NEXT_ELEMENT;
            NEXT_ELEMENT: next_state = CHECK_ELEMENT;
            SORT_BUBBLE: if (sort_pass >= crit_idx - 1 && crit_idx > 0) next_state = OUTPUT_RESULT;
                         else if (crit_idx == 0) next_state = OUTPUT_RESULT;
                         else next_state = SORT_BUBBLE;
            OUTPUT_RESULT: next_state = FINISHED;
            FINISHED: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            critical_count <= 5'd0;
            idx <= 5'd0;
            crit_idx <= 5'd0;
            sort_pass <= 5'd0;
            sort_idx <= 5'd0;
            lis_start <= 1'b0;
            lis_done_flag <= 1'b0;
            // Initialize output regs
            critical_0 <= 8'd0; critical_1 <= 8'd0; critical_2 <= 8'd0; critical_3 <= 8'd0;
            critical_4 <= 8'd0; critical_5 <= 8'd0; critical_6 <= 8'd0; critical_7 <= 8'd0;
            critical_8 <= 8'd0; critical_9 <= 8'd0; critical_10 <= 8'd0; critical_11 <= 8'd0;
            critical_12 <= 8'd0; critical_13 <= 8'd0; critical_14 <= 8'd0; critical_15 <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    lis_done_flag <= 1'b0;
                end
                
                COPY_INPUT: begin
                    // Copy input to orig_arr
                    orig_arr[0] <= arr_0;
                    orig_arr[1] <= arr_1;
                    orig_arr[2] <= arr_2;
                    orig_arr[3] <= arr_3;
                    orig_arr[4] <= arr_4;
                    orig_arr[5] <= arr_5;
                    orig_arr[6] <= arr_6;
                    orig_arr[7] <= arr_7;
                    orig_arr[8] <= arr_8;
                    orig_arr[9] <= arr_9;
                    orig_arr[10] <= arr_10;
                    orig_arr[11] <= arr_11;
                    orig_arr[12] <= arr_12;
                    orig_arr[13] <= arr_13;
                    orig_arr[14] <= arr_14;
                    orig_arr[15] <= arr_15;
                    idx <= 5'd0;
                    crit_idx <= 5'd0;
                    critical_count <= 5'd0;
                end
                
                LIS_ORIG: begin
                    lis_start <= 1'b1;
                    lis_array_len <= n;
                    // Copy orig_arr to lis_source
                    lis_source[0] <= orig_arr[0];
                    lis_source[1] <= orig_arr[1];
                    lis_source[2] <= orig_arr[2];
                    lis_source[3] <= orig_arr[3];
                    lis_source[4] <= orig_arr[4];
                    lis_source[5] <= orig_arr[5];
                    lis_source[6] <= orig_arr[6];
                    lis_source[7] <= orig_arr[7];
                    lis_source[8] <= orig_arr[8];
                    lis_source[9] <= orig_arr[9];
                    lis_source[10] <= orig_arr[10];
                    lis_source[11] <= orig_arr[11];
                    lis_source[12] <= orig_arr[12];
                    lis_source[13] <= orig_arr[13];
                    lis_source[14] <= orig_arr[14];
                    lis_source[15] <= orig_arr[15];
                    lis_done_flag <= 1'b0;
                end
                
                BUILD_TEMP: begin
                    // Build temp_arr (orig without element idx)
                    for (int i = 0; i < 16; i = i + 1) begin
                        if (i < idx) temp_arr[i] <= orig_arr[i];
                        else if (i < 15) temp_arr[i] <= orig_arr[i + 1];
                    end
                    lis_start <= 1'b0;
                    lis_done_flag <= 1'b0;
                end
                
                LIS_TEMP: begin
                    lis_start <= 1'b1;
                    lis_array_len <= n - 5'd1;
                    // Copy temp_arr to lis_source
                    lis_source[0] <= temp_arr[0];
                    lis_source[1] <= temp_arr[1];
                    lis_source[2] <= temp_arr[2];
                    lis_source[3] <= temp_arr[3];
                    lis_source[4] <= temp_arr[4];
                    lis_source[5] <= temp_arr[5];
                    lis_source[6] <= temp_arr[6];
                    lis_source[7] <= temp_arr[7];
                    lis_source[8] <= temp_arr[8];
                    lis_source[9] <= temp_arr[9];
                    lis_source[10] <= temp_arr[10];
                    lis_source[11] <= temp_arr[11];
                    lis_source[12] <= temp_arr[12];
                    lis_source[13] <= temp_arr[13];
                    lis_source[14] <= temp_arr[14];
                    lis_source[15] <= temp_arr[15];
                    lis_done_flag <= 1'b0;
                end
                
                COMPARE_LEN: begin
                    lis_start <= 1'b0;
                    if (lis_result_len < len_orig) begin
                        crit_arr[crit_idx] <= orig_arr[idx];
                        crit_idx <= crit_idx + 5'd1;
                        critical_count <= crit_idx + 5'd1;
                    end
                end
                
                NEXT_ELEMENT: begin
                    idx <= idx + 5'd1;
                end
                
                SORT_BUBBLE: begin
                    if (crit_idx > 5'd1) begin
                        if (crit_arr[sort_idx] > crit_arr[sort_idx + 5'd1]) begin
                            crit_arr[sort_idx] <= crit_arr[sort_idx + 5'd1];
                            crit_arr[sort_idx + 5'd1] <= crit_arr[sort_idx];
                        end
                        sort_idx <= sort_idx + 5'd1;
                        if (sort_idx >= crit_idx - 5'd2) begin
                            sort_idx <= 5'd0;
                            sort_pass <= sort_pass + 5'd1;
                        end
                    end
                end
                
                OUTPUT_RESULT: begin
                    // Output sorted critical elements
                    critical_0 <= crit_arr[0];
                    critical_1 <= crit_arr[1];
                    critical_2 <= crit_arr[2];
                    critical_3 <= crit_arr[3];
                    critical_4 <= crit_arr[4];
                    critical_5 <= crit_arr[5];
                    critical_6 <= crit_arr[6];
                    critical_7 <= crit_arr[7];
                    critical_8 <= crit_arr[8];
                    critical_9 <= crit_arr[9];
                    critical_10 <= crit_arr[10];
                    critical_11 <= crit_arr[11];
                    critical_12 <= crit_arr[12];
                    critical_13 <= crit_arr[13];
                    critical_14 <= crit_arr[14];
                    critical_15 <= crit_arr[15];
                end
                
                FINISHED: begin
                    done <= 1'b1;
                    sort_pass <= 5'd0;
                    sort_idx <= 5'd0;
                end
            endcase
            
            // LIS FSM control
            if (lis_start) begin
                lis_done_flag <= 1'b0;
                lis_state <= LIS_INIT;
            end else if (lis_state != LIS_IDLE) begin
                case (lis_state)
                    LIS_INIT: begin
                        lis_outer <= 5'd0;
                        lis_inner <= 5'd0;
                        lis_count <= 5'd0;
                        // Initialize lis_values to 1
                        for (int i = 0; i < 16; i = i + 1) begin
                            lis_values[i] <= 8'd1;
                        end
                        lis_state <= LIS_OUTER;
                    end
                    
                    LIS_OUTER: begin
                        if (lis_outer < lis_array_len) begin
                            lis_inner <= 5'd0;
                            lis_state <= LIS_INNER;
                        end else begin
                            lis_count <= lis_outer;
                            lis_max <= 5'd0;
                            lis_state <= LIS_MAX;
                        end
                    end
                    
                    LIS_INNER: begin
                        if (lis_inner < lis_outer) begin
                            lis_state <= LIS_UPDATE;
                        end else begin
                            lis_outer <= lis_outer + 5'd1;
                            lis_state <= LIS_OUTER;
                        end
                    end
                    
                    LIS_UPDATE: begin
                        if (lis_source[lis_inner] < lis_source[lis_outer]) begin
                            if (lis_values[lis_inner] + 8'd1 > lis_values[lis_outer]) begin
                                lis_values[lis_outer] <= lis_values[lis_inner] + 8'd1;
                            end
                        end
                        lis_inner <= lis_inner + 5'd1;
                        lis_state <= LIS_INNER;
                    end
                    
                    LIS_MAX: begin
                        if (lis_count < lis_array_len) begin
                            if (lis_values[lis_count] > lis_max) begin
                                lis_max <= lis_values[lis_count];
                            end
                            lis_count <= lis_count + 5'd1;
                        end else begin
                            lis_result_len <= lis_max;
                            lis_state <= LIS_DONE;
                        end
                    end
                    
                    LIS_DONE: begin
                        lis_done_flag <= 1'b1;
                        lis_state <= LIS_IDLE;
                    end
                endcase
            end
        end
    end

    // Assign original LIS length after first computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            len_orig <= 5'd0;
            len_temp <= 5'd0;
        end else if (lis_done_flag && state == LIS_ORIG) begin
            len_orig <= lis_result_len;
        end else if (lis_done_flag && state == LIS_TEMP) begin
            len_temp <= lis_result_len;
        end
    end

endmodule