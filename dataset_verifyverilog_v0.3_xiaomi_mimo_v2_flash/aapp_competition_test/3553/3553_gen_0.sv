module ArrayProcessor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] query_type,
    input wire [3:0] update_pos,
    input wire [2:0] update_value,
    output reg [15:0] result,
    output reg done
);
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] UPDATE = 3'd1;
    localparam [2:0] QUERY_INIT = 3'd2;
    localparam [2:0] QUERY_LEFT = 3'd3;
    localparam [2:0] QUERY_RIGHT = 3'd4;
    localparam [2:0] QUERY_CHECK = 3'd5;
    localparam [2:0] FINISH = 3'd6;
    
    // Array storage (16 elements, 3 bits each, values 1-5 stored as 0-4)
    reg [2:0] arr [0:15];
    
    // Query state variables
    reg [2:0] state;
    reg [3:0] left_idx;
    reg [3:0] right_idx;
    reg [3:0] best_len;
    reg [3:0] current_len;
    reg [2:0] count [0:4];  // Count of each number 1-5
    reg [2:0] distinct_count;
    reg [3:0] k_value;  // K from query (1..5)
    
    // Counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize all array elements to 1 (value 1 stored as 0)
            for (i = 0; i < 16; i = i + 1) begin
                arr[i] <= 3'd0;
            end
            left_idx <= 4'd0;
            right_idx <= 4'd0;
            best_len <= 4'd15;
            current_len <= 4'd0;
            for (i = 0; i < 5; i = i + 1) begin
                count[i] <= 3'd0;
            end
            distinct_count <= 3'd0;
            k_value <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        if (query_type == 2'd1) begin
                            // Update query
                            state <= UPDATE;
                        end else if (query_type == 2'd2) begin
                            // Query type 2
                            state <= QUERY_INIT;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end
                
                UPDATE: begin
                    // Store value-1 (since input 1-5, store as 0-4)
                    if (update_pos < 16) begin
                        arr[update_pos] <= update_value - 3'd1;
                    end
                    state <= FINISH;
                end
                
                QUERY_INIT: begin
                    // Initialize for sliding window
                    k_value <= 4'd5;  // We always look for 1..5 (all numbers)
                    best_len <= 4'd15;
                    left_idx <= 4'd0;
                    right_idx <= 4'd0;
                    distinct_count <= 3'd0;
                    for (i = 0; i < 5; i = i + 1) begin
                        count[i] <= 3'd0;
                    end
                    state <= QUERY_LEFT;
                end
                
                QUERY_LEFT: begin
                    // Reset for new left index
                    right_idx <= left_idx;
                    distinct_count <= 3'd0;
                    for (i = 0; i < 5; i = i + 1) begin
                        count[i] <= 3'd0;
                    end
                    state <= QUERY_RIGHT;
                end
                
                QUERY_RIGHT: begin
                    // Add element at right_idx
                    if (right_idx < 16) begin
                        if (arr[right_idx] < 5) begin
                            count[arr[right_idx]] <= count[arr[right_idx]] + 3'd1;
                            if (count[arr[right_idx]] == 3'd0) begin
                                distinct_count <= distinct_count + 3'd1;
                            end
                        end
                        right_idx <= right_idx + 4'd1;
                    end
                    state <= QUERY_CHECK;
                end
                
                QUERY_CHECK: begin
                    // Check if we have all 5 numbers
                    if (distinct_count == 3'd5) begin
                        // Found valid subarray
                        current_len <= right_idx - left_idx;
                        // Update best length
                        if (best_len > (right_idx - left_idx)) begin
                            best_len <= right_idx - left_idx;
                        end
                        // Move to next left index
                        if (left_idx < 15) begin
                            // Remove left element
                            if (arr[left_idx] < 5) begin
                                count[arr[left_idx]] <= count[arr[left_idx]] - 3'd1;
                                if (count[arr[left_idx]] == 3'd0) begin
                                    distinct_count <= distinct_count - 3'd1;
                                end
                            end
                            left_idx <= left_idx + 4'd1;
                            state <= QUERY_LEFT;
                        end else begin
                            state <= FINISH;
                        end
                    end else begin
                        // Continue extending right
                        if (right_idx < 16) begin
                            state <= QUERY_RIGHT;
                        end else begin
                            // Reached end, move to next left
                            if (left_idx < 15) begin
                                // Remove left element
                                if (arr[left_idx] < 5) begin
                                    count[arr[left_idx]] <= count[arr[left_idx]] - 3'd1;
                                    if (count[arr[left_idx]] == 3'd0) begin
                                        distinct_count <= distinct_count - 3'd1;
                                    end
                                end
                                left_idx <= left_idx + 4'd1;
                                state <= QUERY_LEFT;
                            end else begin
                                state <= FINISH;
                            end
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (state == QUERY_INIT || state == QUERY_LEFT || 
                        state == QUERY_RIGHT || state == QUERY_CHECK) begin
                        // Query finished
                        if (best_len <= 4'd15 && best_len > 4'd0) begin
                            result <= {12'd0, best_len};
                        end else begin
                            result <= 16'hFFFF;  // -1 for no subarray
                        end
                    end else begin
                        // Update finished
                        result <= 16'd0;
                    end
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Prevent infinite loops
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                state <= FINISH;
                result <= 16'hFFFF;
                done <= 1'b1;
            end
        end
    end
endmodule