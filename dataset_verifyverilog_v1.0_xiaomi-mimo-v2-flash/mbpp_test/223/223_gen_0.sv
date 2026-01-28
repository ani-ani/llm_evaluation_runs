module majority_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] arr,
    input wire [3:0] len,
    input wire [7:0] target,
    output reg result,
    output reg done
);

// State declarations
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT = 3'd1;
localparam [2:0] SEARCH = 3'd2;
localparam [2:0] CHECK = 3'd3;
localparam [2:0] FINISH = 3'd4;

// Internal registers
reg [2:0] state;
reg [3:0] low;
reg [3:0] high;
reg [3:0] mid;
reg [3:0] search_count;
reg found_flag;
reg [3:0] found_index;
reg [3:0] n_div_2;
reg [3:0] temp_plus;
reg [3:0] check_index;
reg [7:0] arr_mid;
reg [7:0] arr_mid_minus_1;
reg [7:0] arr_check;

// Combinational logic for array access
always @(*) begin
    // Extract arr[mid] (8-bit value)
    arr_mid = arr[mid * 8 +: 8];
    
    // Extract arr[mid-1] if mid > 0
    if (mid > 4'd0) begin
        arr_mid_minus_1 = arr[(mid - 4'd1) * 8 +: 8];
    end else begin
        arr_mid_minus_1 = 8'd0;
    end
    
    // Extract arr[check_index] for majority check
    arr_check = arr[check_index * 8 +: 8];
    
    // Calculate n/2 using bit shift
    n_div_2 = len >> 1;
    
    // Calculate mid + n/2 with bounds check
    temp_plus = mid + n_div_2;
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 1'b0;
        done <= 1'b0;
        low <= 4'd0;
        high <= 4'd0;
        mid <= 4'd0;
        search_count <= 4'd0;
        found_flag <= 1'b0;
        found_index <= 4'd0;
        check_index <= 4'd0;
        temp_plus <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                result <= 1'b0;
                if (start) begin
                    if (len == 4'd0) begin
                        // Empty array: no majority
                        state <= FINISH;
                        result <= 1'b0;
                    end else begin
                        state <= INIT;
                    end
                end
            end
            
            INIT: begin
                // Initialize binary search bounds
                low <= 4'd0;
                high <= len - 4'd1;
                search_count <= 4'd0;
                found_flag <= 1'b0;
                state <= SEARCH;
            end
            
            SEARCH: begin
                if (low <= high && search_count < 4'd16) begin
                    // Compute mid = (low + high) / 2
                    mid <= (low + high) >> 1;
                    
                    // Check if arr[mid] == target
                    if (arr_mid == target) begin
                        // Check if it's the first occurrence
                        if (mid == 4'd0 || arr_mid_minus_1 < target) begin
                            found_flag <= 1'b1;
                            found_index <= mid;
                            // Move to CHECK state
                            state <= CHECK;
                        end else begin
                            // Not first occurrence, search left
                            if (mid > 4'd0) begin
                                high <= mid - 4'd1;
                            end else begin
                                high <= 4'd0;
                            end
                            search_count <= search_count + 4'd1;
                        end
                    end else if (arr_mid < target) begin
                        // Search right
                        low <= mid + 4'd1;
                        search_count <= search_count + 4'd1;
                    end else begin
                        // Search left
                        if (mid > 4'd0) begin
                            high <= mid - 4'd1;
                        end else begin
                            high <= 4'd0;
                        end
                        search_count <= search_count + 4'd1;
                    end
                end else begin
                    // Search complete or timeout
                    state <= FINISH;
                    result <= 1'b0;
                end
            end
            
            CHECK: begin
                // Check if target is majority
                // Calculate mid + n/2
                temp_plus <= found_index + n_div_2;
                
                // Check bounds and value
                if (found_flag && temp_plus < len) begin
                    check_index <= found_index + n_div_2;
                    if (arr_check == target) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                end else begin
                    result <= 1'b0;
                end
                state <= FINISH;
            end
            
            FINISH: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: begin
                state <= IDLE;
                result <= 1'b0;
                done <= 1'b0;
            end
        endcase
    end
end

endmodule