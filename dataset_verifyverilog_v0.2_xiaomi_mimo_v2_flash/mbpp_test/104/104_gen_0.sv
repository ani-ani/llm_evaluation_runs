module sort_sublists(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_sublists,
    input [2:0] num_strings_0,
    input [2:0] num_strings_1,
    input [2:0] num_strings_2,
    input [63:0] sublist_0_str_0, sublist_0_str_1, sublist_0_str_2, sublist_0_str_3,
                 sublist_0_str_4, sublist_0_str_5, sublist_0_str_6, sublist_0_str_7,
    input [63:0] sublist_1_str_0, sublist_1_str_1, sublist_1_str_2, sublist_1_str_3,
                 sublist_1_str_4, sublist_1_str_5, sublist_1_str_6, sublist_1_str_7,
    input [63:0] sublist_2_str_0, sublist_2_str_1, sublist_2_str_2, sublist_2_str_3,
                 sublist_2_str_4, sublist_2_str_5, sublist_2_str_6, sublist_2_str_7,
    output reg [63:0] result_str_0, result_str_1, result_str_2, result_str_3,
                      result_str_4, result_str_5, result_str_6, result_str_7,
    output reg [2:0] current_sublist,
    output reg result_valid,
    output reg done
);

    // Internal buffer for sorting
    reg [63:0] buffer [0:7];
    
    // State definitions
    localparam IDLE = 4'd0;
    localparam LOAD = 4'd1;
    localparam LOAD_WAIT = 4'd2;
    localparam SORT_INIT = 4'd3;
    localparam COMPARE = 4'd4;
    localparam SWAP = 4'd5;
    localparam NEXT_PAIR = 4'd6;
    localparam NEXT_PASS = 4'd7;
    localparam OUTPUT = 4'd8;
    localparam OUTPUT_WAIT = 4'd9;
    localparam NEXT_SUBLIST = 4'd10;
    localparam DONE = 4'd11;
    
    reg [3:0] state, next_state;
    
    // Control registers
    reg [2:0] current_list_idx;       // Which sublist we are processing
    reg [3:0] load_count;             // Counter for loading strings
    reg [3:0] pass_count;             // Bubble sort pass counter
    reg [3:0] pair_count;             // Pair index in current pass
    reg [2:0] output_count;           // Counter for outputting strings
    
    // Working registers for comparison
    reg [63:0] temp_str_a;
    reg [63:0] temp_str_b;
    reg cmp_result;                   // 1 if swap needed (a > b)
    
    // Decoded current sublist string count
    reg [2:0] current_num_strings;
    
    // Helper: get string from input based on list and index
    wire [63:0] input_str_0 [0:7];
    wire [63:0] input_str_1 [0:7];
    wire [63:0] input_str_2 [0:7];
    
    assign input_str_0[0] = sublist_0_str_0; assign input_str_0[1] = sublist_0_str_1;
    assign input_str_0[2] = sublist_0_str_2; assign input_str_0[3] = sublist_0_str_3;
    assign input_str_0[4] = sublist_0_str_4; assign input_str_0[5] = sublist_0_str_5;
    assign input_str_0[6] = sublist_0_str_6; assign input_str_0[7] = sublist_0_str_7;
    
    assign input_str_1[0] = sublist_1_str_0; assign input_str_1[1] = sublist_1_str_1;
    assign input_str_1[2] = sublist_1_str_2; assign input_str_1[3] = sublist_1_str_3;
    assign input_str_1[4] = sublist_1_str_4; assign input_str_1[5] = sublist_1_str_5;
    assign input_str_1[6] = sublist_1_str_6; assign input_str_1[7] = sublist_1_str_7;
    
    assign input_str_2[0] = sublist_2_str_0; assign input_str_2[1] = sublist_2_str_1;
    assign input_str_2[2] = sublist_2_str_2; assign input_str_2[3] = sublist_2_str_3;
    assign input_str_2[4] = sublist_2_str_4; assign input_str_2[5] = sublist_2_str_5;
    assign input_str_2[6] = sublist_2_str_6; assign input_str_2[7] = sublist_2_str_7;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    // Determine number of strings for current sublist
    always @(*) begin
        case(current_list_idx)
            3'd0: current_num_strings = num_strings_0;
            3'd1: current_num_strings = num_strings_1;
            3'd2: current_num_strings = num_strings_2;
            default: current_num_strings = 3'd0;
        endcase
    end
    
    // Compare first bytes of temp_str_a and temp_str_b
    // Returns 1 if a > b (swap needed for ascending)
    always @(*) begin
        cmp_result = (temp_str_a[63:56] > temp_str_b[63:56]);
    end
    
    // Next state logic
    always @(*) begin
        case(state)
            IDLE: begin
                if (start) next_state = LOAD;
                else next_state = IDLE;
            end
            
            LOAD: begin
                // Load all 8 positions (or just valid ones, but we load all inputs)
                // If current_num_strings is 0 (shouldn't happen), skip
                if (current_list_idx >= num_sublists)
                    next_state = DONE;
                else if (current_num_strings == 3'd0)
                    next_state = NEXT_SUBLIST;
                else
                    next_state = LOAD_WAIT;
            end
            
            LOAD_WAIT: begin
                // Wait one cycle for load to complete (internal logic handles it)
                next_state = SORT_INIT;
            end
            
            SORT_INIT: begin
                // Initialize sort counters
                next_state = COMPARE;
            end
            
            COMPARE: begin
                // Compare logic is combinational, proceed to SWAP decision
                next_state = SWAP;
            end
            
            SWAP: begin
                // Swap or not, then move to next pair
                next_state = NEXT_PAIR;
            end
            
            NEXT_PAIR: begin
                // Check if we finished all pairs for this pass
                // Max pairs for n elements is n-1. 
                // We iterate pair_count from 0 to (n-2).
                // If pair_count < (current_num_strings - 1), go to COMPARE
                // Note: pair_count is incremented after SWAP
                if (pair_count < (current_num_strings - 1)) begin
                    next_state = COMPARE;
                end else begin
                    next_state = NEXT_PASS;
                end
            end
            
            NEXT_PASS: begin
                // Check if we need more passes
                // Max 8 passes for 8 elements (n-1 passes needed, 8 is safe upper bound)
                // We use pass_count from 0 to 7. If pass_count < 7, loop.
                // Optimization: We could stop early if no swaps, but requirement says bounded iterations.
                if (pass_count < 3'd7) begin
                    next_state = COMPARE;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                // Output sorted strings one per cycle
                next_state = OUTPUT_WAIT;
            end
            
            OUTPUT_WAIT: begin
                // Wait for output to be registered
                if (output_count < current_num_strings - 1) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = NEXT_SUBLIST;
                end
            end
            
            NEXT_SUBLIST: begin
                // Check if done all sublists
                if (current_list_idx + 1 >= num_sublists)
                    next_state = DONE;
                else
                    next_state = LOAD;
            end
            
            DONE: begin
                next_state = DONE; // Stay in done state
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Output and control logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_list_idx <= 3'd0;
            load_count <= 4'd0;
            pass_count <= 3'd0;
            pair_count <= 4'd0;
            output_count <= 3'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            result_str_0 <= 64'd0; result_str_1 <= 64'd0; result_str_2 <= 64'd0; result_str_3 <= 64'd0;
            result_str_4 <= 64'd0; result_str_5 <= 64'd0; result_str_6 <= 64'd0; result_str_7 <= 64'd0;
            temp_str_a <= 64'd0;
            temp_str_b <= 64'd0;
            // Initialize buffer to prevent X propagation
            buffer[0] <= 64'd0; buffer[1] <= 64'd0; buffer[2] <= 64'd0; buffer[3] <= 64'd0;
            buffer[4] <= 64'd0; buffer[5] <= 64'd0; buffer[6] <= 64'd0; buffer[7] <= 64'd0;
        end else begin
            case(state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    current_list_idx <= 3'd0;
                    if (start) begin
                        load_count <= 4'd0;
                    end
                end
                
                LOAD: begin
                    // Prepare for load, reset counters
                    load_count <= 4'd0;
                end
                
                LOAD_WAIT: begin
                    // Load data into buffer based on current_list_idx
                    // We load all 8 positions. If fewer strings, we can just copy.
                    // The sorting logic uses num_strings to bound operations.
                    if (current_list_idx == 3'd0) begin
                        buffer[0] <= sublist_0_str_0; buffer[1] <= sublist_0_str_1;
                        buffer[2] <= sublist_0_str_2; buffer[3] <= sublist_0_str_3;
                        buffer[4] <= sublist_0_str_4; buffer[5] <= sublist_0_str_5;
                        buffer[6] <= sublist_0_str_6; buffer[7] <= sublist_0_str_7;
                    end else if (current_list_idx == 3'd1) begin
                        buffer[0] <= sublist_1_str_0; buffer[1] <= sublist_1_str_1;
                        buffer[2] <= sublist_1_str_2; buffer[3] <= sublist_1_str_3;
                        buffer[4] <= sublist_1_str_4; buffer[5] <= sublist_1_str_5;
                        buffer[6] <= sublist_1_str_6; buffer[7] <= sublist_1_str_7;
                    end else if (current_list_idx == 3'd2) begin
                        buffer[0] <= sublist_2_str_0; buffer[1] <= sublist_2_str_1;
                        buffer[2] <= sublist_2_str_2; buffer[3] <= sublist_2_str_3;
                        buffer[4] <= sublist_2_str_4; buffer[5] <= sublist_2_str_5;
                        buffer[6] <= sublist_2_str_6; buffer[7] <= sublist_2_str_7;
                    end
                    pass_count <= 3'd0;
                    pair_count <= 4'd0;
                end
                
                SORT_INIT: begin
                    pass_count <= 3'd0;
                    pair_count <= 4'd0;
                end
                
                COMPARE: begin
                    // Load registers for comparison
                    // pair_count points to the first element of the pair (i, i+1)
                    temp_str_a <= buffer[pair_count];
                    temp_str_b <= buffer[pair_count + 1];
                end
                
                SWAP: begin
                    // Perform swap if needed
                    // We already have temp_str_a and temp_str_b from COMPARE state
                    // Check if current elements are within the valid count (though we skip logic handles it)
                    // Actually, COMPARE might load invalid indices if not careful.
                    // But COMPARE is only entered from NEXT_PAIR which checks bounds.
                    // Wait, COMPARE enters based on pair_count. NEXT_PAIR updates pair_count.
                    // So in COMPARE, pair_count < current_num_strings - 1 is true.
                    
                    if (cmp_result) begin
                        // Swap: buffer[pair_count] gets b, buffer[pair_count+1] gets a
                        // Note: temp_str_a was buffer[pair_count], temp_str_b was buffer[pair_count+1]
                        buffer[pair_count] <= temp_str_b;
                        buffer[pair_count + 1] <= temp_str_a;
                    end
                    // Increment pair count here? No, done in NEXT_PAIR logic usually or implicitly.
                    // Let's increment in NEXT_PAIR state logic below.
                end
                
                NEXT_PAIR: begin
                    // Increment pair counter
                    pair_count <= pair_count + 1;
                end
                
                NEXT_PASS: begin
                    // Increment pass counter and reset pair counter
                    pass_count <= pass_count + 1;
                    pair_count <= 4'd0;
                end
                
                OUTPUT: begin
                    // Drive output for current output_count
                    result_valid <= 1'b1;
                    case(output_count)
                        3'd0: result_str_0 <= buffer[0];
                        3'd1: result_str_1 <= buffer[1];
                        3'd2: result_str_2 <= buffer[2];
                        3'd3: result_str_3 <= buffer[3];
                        3'd4: result_str_4 <= buffer[4];
                        3'd5: result_str_5 <= buffer[5];
                        3'd6: result_str_6 <= buffer[6];
                        3'd7: result_str_7 <= buffer[7];
                    endcase
                    // Set current_sublist output
                    current_sublist <= current_list_idx;
                end
                
                OUTPUT_WAIT: begin
                    // Ready for next output or finish
                    result_valid <= 1'b0;
                    if (output_count < current_num_strings - 1) begin
                        output_count <= output_count + 1;
                    end
                end
                
                NEXT_SUBLIST: begin
                    // Move to next sublist
                    current_list_idx <= current_list_idx + 1;
                    output_count <= 3'd0;
                    // Reset load count for next cycle
                    load_count <= 4'd0;
                end
                
                DONE: begin
                    done <= 1'b1;
                    result_valid <= 1'b0;
                end
            endcase
        end
    end
    
endmodule
