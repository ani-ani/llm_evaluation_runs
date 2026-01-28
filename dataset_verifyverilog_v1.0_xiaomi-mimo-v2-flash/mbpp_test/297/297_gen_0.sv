module flatten_2d_array (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0_0, arr_0_1, arr_0_2, arr_0_3, arr_0_4, arr_0_5, arr_0_6, arr_0_7,
    input wire [7:0] arr_1_0, arr_1_1, arr_1_2, arr_1_3, arr_1_4, arr_1_5, arr_1_6, arr_1_7,
    input wire [7:0] arr_2_0, arr_2_1, arr_2_2, arr_2_3, arr_2_4, arr_2_5, arr_2_6, arr_2_7,
    input wire [7:0] arr_3_0, arr_3_1, arr_3_2, arr_3_3, arr_3_4, arr_3_5, arr_3_6, arr_3_7,
    input wire [7:0] arr_4_0, arr_4_1, arr_4_2, arr_4_3, arr_4_4, arr_4_5, arr_4_6, arr_4_7,
    input wire [7:0] arr_5_0, arr_5_1, arr_5_2, arr_5_3, arr_5_4, arr_5_5, arr_5_6, arr_5_7,
    input wire [7:0] arr_6_0, arr_6_1, arr_6_2, arr_6_3, arr_6_4, arr_6_5, arr_6_6, arr_6_7,
    input wire [7:0] arr_7_0, arr_7_1, arr_7_2, arr_7_3, arr_7_4, arr_7_5, arr_7_6, arr_7_7,
    input wire [7:0] len,
    input wire [3:0] valid_len_0, valid_len_1, valid_len_2, valid_len_3,
    input wire [3:0] valid_len_4, valid_len_5, valid_len_6, valid_len_7,
    output reg [511:0] result,
    output reg done,
    output reg [5:0] count
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [2:0] subarray_idx;    // 0-7 for each subarray
    reg [2:0] element_idx;     // 0-7 for each element in subarray
    reg [5:0] result_idx;      // 0-63 for packed output
    reg [7:0] processed_len;   // Track how many elements processed per subarray
    reg [7:0] current_len;     // Length of current subarray
    reg [3:0] cycle_count;     // Prevent infinite loops (max 16 cycles per subarray)
    localparam [3:0] MAX_CYCLES = 4'd15;

    // Combine valid_len inputs for easier access
    wire [3:0] valid_len_array [0:7];
    assign valid_len_array[0] = valid_len_0;
    assign valid_len_array[1] = valid_len_1;
    assign valid_len_array[2] = valid_len_2;
    assign valid_len_array[3] = valid_len_3;
    assign valid_len_array[4] = valid_len_4;
    assign valid_len_array[5] = valid_len_5;
    assign valid_len_array[6] = valid_len_6;
    assign valid_len_array[7] = valid_len_7;

    // Combine arr inputs for easier access
    wire [7:0] arr_array [0:7][0:7];
    assign arr_array[0][0] = arr_0_0; assign arr_array[0][1] = arr_0_1; assign arr_array[0][2] = arr_0_2; assign arr_array[0][3] = arr_0_3;
    assign arr_array[0][4] = arr_0_4; assign arr_array[0][5] = arr_0_5; assign arr_array[0][6] = arr_0_6; assign arr_array[0][7] = arr_0_7;
    assign arr_array[1][0] = arr_1_0; assign arr_array[1][1] = arr_1_1; assign arr_array[1][2] = arr_1_2; assign arr_array[1][3] = arr_1_3;
    assign arr_array[1][4] = arr_1_4; assign arr_array[1][5] = arr_1_5; assign arr_array[1][6] = arr_1_6; assign arr_array[1][7] = arr_1_7;
    assign arr_array[2][0] = arr_2_0; assign arr_array[2][1] = arr_2_1; assign arr_array[2][2] = arr_2_2; assign arr_array[2][3] = arr_2_3;
    assign arr_array[2][4] = arr_2_4; assign arr_array[2][5] = arr_2_5; assign arr_array[2][6] = arr_2_6; assign arr_array[2][7] = arr_2_7;
    assign arr_array[3][0] = arr_3_0; assign arr_array[3][1] = arr_3_1; assign arr_array[3][2] = arr_3_2; assign arr_array[3][3] = arr_3_3;
    assign arr_array[3][4] = arr_3_4; assign arr_array[3][5] = arr_3_5; assign arr_array[3][6] = arr_3_6; assign arr_array[3][7] = arr_3_7;
    assign arr_array[4][0] = arr_4_0; assign arr_array[4][1] = arr_4_1; assign arr_array[4][2] = arr_4_2; assign arr_array[4][3] = arr_4_3;
    assign arr_array[4][4] = arr_4_4; assign arr_array[4][5] = arr_4_5; assign arr_array[4][6] = arr_4_6; assign arr_array[4][7] = arr_4_7;
    assign arr_array[5][0] = arr_5_0; assign arr_array[5][1] = arr_5_1; assign arr_array[5][2] = arr_5_2; assign arr_array[5][3] = arr_5_3;
    assign arr_array[5][4] = arr_5_4; assign arr_array[5][5] = arr_5_5; assign arr_array[5][6] = arr_5_6; assign arr_array[5][7] = arr_5_7;
    assign arr_array[6][0] = arr_6_0; assign arr_array[6][1] = arr_6_1; assign arr_array[6][2] = arr_6_2; assign arr_array[6][3] = arr_6_3;
    assign arr_array[6][4] = arr_6_4; assign arr_array[6][5] = arr_6_5; assign arr_array[6][6] = arr_6_6; assign arr_array[6][7] = arr_6_7;
    assign arr_array[7][0] = arr_7_0; assign arr_array[7][1] = arr_7_1; assign arr_array[7][2] = arr_7_2; assign arr_array[7][3] = arr_7_3;
    assign arr_array[7][4] = arr_7_4; assign arr_array[7][5] = arr_7_5; assign arr_array[7][6] = arr_7_6; assign arr_array[7][7] = arr_7_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 512'd0;
            done <= 1'b0;
            count <= 6'd0;
            subarray_idx <= 3'd0;
            element_idx <= 3'd0;
            result_idx <= 6'd0;
            processed_len <= 8'd0;
            current_len <= 8'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 6'd0;
                    subarray_idx <= 3'd0;
                    element_idx <= 3'd0;
                    result_idx <= 6'd0;
                    processed_len <= 8'd0;
                    current_len <= 8'd0;
                    cycle_count <= 4'd0;
                    
                    if (start) begin
                        state <= PROCESS;
                        // Get length of first subarray
                        current_len <= (len[0] && valid_len_array[0] != 4'd0) ? {4'd0, valid_len_array[0]} : 8'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check if current subarray has valid data
                    if (len[subarray_idx] && current_len != 8'd0 && processed_len < current_len) begin
                        // Copy element from current subarray
                        case (subarray_idx)
                            3'd0: result[result_idx*8 +: 8] <= arr_array[0][element_idx];
                            3'd1: result[result_idx*8 +: 8] <= arr_array[1][element_idx];
                            3'd2: result[result_idx*8 +: 8] <= arr_array[2][element_idx];
                            3'd3: result[result_idx*8 +: 8] <= arr_array[3][element_idx];
                            3'd4: result[result_idx*8 +: 8] <= arr_array[4][element_idx];
                            3'd5: result[result_idx*8 +: 8] <= arr_array[5][element_idx];
                            3'd6: result[result_idx*8 +: 8] <= arr_array[6][element_idx];
                            3'd7: result[result_idx*8 +: 8] <= arr_array[7][element_idx];
                            default: result[result_idx*8 +: 8] <= 8'd0;
                        endcase
                        
                        element_idx <= element_idx + 3'd1;
                        result_idx <= result_idx + 6'd1;
                        processed_len <= processed_len + 8'd1;
                        count <= count + 6'd1;
                    end else begin
                        // Move to next subarray
                        element_idx <= 3'd0;
                        processed_len <= 8'd0;
                        subarray_idx <= subarray_idx + 3'd1;
                        
                        // Get length of next subarray
                        case (subarray_idx + 3'd1)
                            3'd0: current_len <= (len[0] && valid_len_array[0] != 4'd0) ? {4'd0, valid_len_array[0]} : 8'd0;
                            3'd1: current_len <= (len[1] && valid_len_array[1] != 4'd0) ? {4'd0, valid_len_array[1]} : 8'd0;
                            3'd2: current_len <= (len[2] && valid_len_array[2] != 4'd0) ? {4'd0, valid_len_array[2]} : 8'd0;
                            3'd3: current_len <= (len[3] && valid_len_array[3] != 4'd0) ? {4'd0, valid_len_array[3]} : 8'd0;
                            3'd4: current_len <= (len[4] && valid_len_array[4] != 4'd0) ? {4'd0, valid_len_array[4]} : 8'd0;
                            3'd5: current_len <= (len[5] && valid_len_array[5] != 4'd0) ? {4'd0, valid_len_array[5]} : 8'd0;
                            3'd6: current_len <= (len[6] && valid_len_array[6] != 4'd0) ? {4'd0, valid_len_array[6]} : 8'd0;
                            3'd7: current_len <= (len[7] && valid_len_array[7] != 4'd0) ? {4'd0, valid_len_array[7]} : 8'd0;
                            default: current_len <= 8'd0;
                        endcase
                    end
                    
                    // Exit conditions: processed all 8 subarrays or exceeded cycle limit
                    if ((subarray_idx == 3'd7 && processed_len >= current_len && current_len != 8'd0) ||
                        (subarray_idx == 3'd7 && len[7] == 1'b0) ||
                        (subarray_idx > 3'd7) ||
                        cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 512'd0;
                    done <= 1'b0;
                    count <= 6'd0;
                    subarray_idx <= 3'd0;
                    element_idx <= 3'd0;
                    result_idx <= 6'd0;
                    processed_len <= 8'd0;
                    current_len <= 8'd0;
                    cycle_count <= 4'd0;
                end
            endcase
        end
    end

endmodule