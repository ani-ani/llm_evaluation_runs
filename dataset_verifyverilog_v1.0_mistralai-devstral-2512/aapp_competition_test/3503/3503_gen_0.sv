module distinct_arithmetic(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire signed [31:0] a [0:15],
    input wire signed [31:0] b [0:15],
    output reg [1:0] op [0:15],
    output reg signed [31:0] result [0:15],
    output reg valid,
    output reg impossible
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COMPUTE = 4'd1;
    localparam [3:0] CHECK = 4'd2;
    localparam [3:0] BACKTRACK = 4'd3;
    localparam [3:0] DONE = 4'd4;
    localparam [3:0] IMPOSSIBLE_STATE = 4'd5;

    reg [3:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Current pair index
    reg [3:0] current_pair;

    // Track used results (bit vector)
    reg [15:0] used_results [0:15];
    reg [15:0] used_results_temp [0:15];

    // Temporary storage for operations
    reg [1:0] op_temp [0:15];
    reg signed [31:0] result_temp [0:15];

    // Backtracking stack
    reg [3:0] backtrack_stack [0:15];
    reg [3:0] backtrack_ptr;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            current_pair <= 4'd0;
            valid <= 1'b0;
            impossible <= 1'b0;
            
            for (i = 0; i < 16; i = i + 1) begin
                op[i] <= 2'd0;
                result[i] <= 32'd0;
                op_temp[i] <= 2'd0;
                result_temp[i] <= 32'd0;
                used_results[i] <= 16'd0;
                used_results_temp[i] <= 16'd0;
                backtrack_stack[i] <= 4'd0;
            end
            backtrack_ptr <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    impossible <= 1'b0;
                    cycle_count <= 8'd0;
                    current_pair <= 4'd0;
                    
                    // Clear all temporary storage
                    for (i = 0; i < 16; i = i + 1) begin
                        op[i] <= 2'd0;
                        result[i] <= 32'd0;
                        op_temp[i] <= 2'd0;
                        result_temp[i] <= 32'd0;
                        used_results[i] <= 16'd0;
                        used_results_temp[i] <= 16'd0;
                        backtrack_stack[i] <= 4'd0;
                    end
                    backtrack_ptr <= 4'd0;
                    
                    if (start) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute all possible results for current pair
                    // Try operations in order: +, -, *
                    // Check if result is already used
                    
                    // Try addition
                    result_temp[current_pair] = a[current_pair] + b[current_pair];
                    if (!is_result_used(result_temp[current_pair], used_results, current_pair)) begin
                        op_temp[current_pair] = 2'd0;
                        mark_result_used(result_temp[current_pair], used_results_temp, current_pair);
                        
                        if (current_pair == n - 1) begin
                            state <= CHECK;
                        end else begin
                            current_pair <= current_pair + 4'd1;
                        end
                    end
                    // Try subtraction
                    else begin
                        result_temp[current_pair] = a[current_pair] - b[current_pair];
                        if (!is_result_used(result_temp[current_pair], used_results, current_pair)) begin
                            op_temp[current_pair] = 2'd1;
                            mark_result_used(result_temp[current_pair], used_results_temp, current_pair);
                            
                            if (current_pair == n - 1) begin
                                state <= CHECK;
                            end else begin
                                current_pair <= current_pair + 4'd1;
                            end
                        end
                        // Try multiplication
                        else begin
                            result_temp[current_pair] = (a[current_pair] * b[current_pair]) >> 32;
                            if (!is_result_used(result_temp[current_pair], used_results, current_pair)) begin
                                op_temp[current_pair] = 2'd2;
                                mark_result_used(result_temp[current_pair], used_results_temp, current_pair);
                                
                                if (current_pair == n - 1) begin
                                    state <= CHECK;
                                end else begin
                                    current_pair <= current_pair + 4'd1;
                                end
                            end
                            // No valid operation found
                            else begin
                                state <= BACKTRACK;
                            end
                        end
                    end
                    
                    // Check cycle limit
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IMPOSSIBLE_STATE;
                    end
                end

                CHECK: begin
                    // Verify all results are distinct
                    reg all_distinct;
                    all_distinct = 1'b1;
                    
                    for (i = 0; i < n; i = i + 1) begin
                        if (is_result_used(result_temp[i], used_results_temp, i)) begin
                            all_distinct = 1'b0;
                        end
                    end
                    
                    if (all_distinct) begin
                        // Copy results to output
                        for (i = 0; i < n; i = i + 1) begin
                            op[i] <= op_temp[i];
                            result[i] <= result_temp[i];
                        end
                        state <= DONE;
                    end else begin
                        state <= BACKTRACK;
                    end
                end

                BACKTRACK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Backtrack to previous pair
                    if (current_pair > 4'd0) begin
                        current_pair <= current_pair - 4'd1;
                        
                        // Clear the used result for this pair
                        clear_result_used(result_temp[current_pair], used_results_temp, current_pair);
                        
                        // Push to backtrack stack
                        backtrack_stack[backtrack_ptr] = current_pair;
                        backtrack_ptr <= backtrack_ptr + 4'd1;
                        
                        state <= COMPUTE;
                    end else begin
                        state <= IMPOSSIBLE_STATE;
                    end
                    
                    // Check cycle limit
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IMPOSSIBLE_STATE;
                    end
                end

                DONE: begin
                    valid <= 1'b1;
                    state <= IDLE;
                end

                IMPOSSIBLE_STATE: begin
                    impossible <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Function to check if result is already used
    function is_result_used;
        input signed [31:0] res;
        input [15:0] used [0:15];
        input [3:0] current_idx;
        integer j;
        begin
            is_result_used = 1'b0;
            for (j = 0; j < current_idx; j = j + 1) begin
                if (used[j][res[15:0]]) begin
                    is_result_used = 1'b1;
                    return;
                end
            end
        end
    endfunction

    // Function to mark result as used
    function mark_result_used;
        input signed [31:0] res;
        output [15:0] used [0:15];
        input [3:0] current_idx;
        integer j;
        begin
            for (j = 0; j < 16; j = j + 1) begin
                used[j] = used[j];
            end
            used[current_idx][res[15:0]] = 1'b1;
        end
    endfunction

    // Function to clear result from used
    function clear_result_used;
        input signed [31:0] res;
        output [15:0] used [0:15];
        input [3:0] current_idx;
        integer j;
        begin
            for (j = 0; j < 16; j = j + 1) begin
                used[j] = used[j];
            end
            used[current_idx][res[15:0]] = 1'b0;
        end
    endfunction

endmodule