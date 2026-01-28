module max_increasing_subsegment(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [3:0] n,
    output reg [7:0] result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_LEFT = 3'd1;
    localparam [2:0] COMPUTE_RIGHT = 3'd2;
    localparam [2:0] COMPUTE_RESULT = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] left [0:15];
    reg [7:0] right [0:15];
    reg [7:0] max_len;
    reg [3:0] i, j;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                left[i] <= 8'd0;
                right[i] <= 8'd0;
            end
            i <= 4'd0;
            j <= 4'd0;
            max_len <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE_LEFT;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE_LEFT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute left array
                    if (i == 0) begin
                        left[i] <= 1;
                    end else if (i < n) begin
                        if (arr[i] > arr[i-1]) begin
                            left[i] <= left[i-1] + 1;
                        end else begin
                            left[i] <= 1;
                        end
                    end
                    
                    if (i == n-1) begin
                        i <= 4'd0;
                        next_state <= COMPUTE_RIGHT;
                    end else begin
                        i <= i + 4'd1;
                    end
                end
                
                COMPUTE_RIGHT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute right array
                    if (j == n-1) begin
                        right[j] <= 1;
                    end else if (j < n) begin
                        if (arr[j] < arr[j+1]) begin
                            right[j] <= right[j+1] + 1;
                        end else begin
                            right[j] <= 1;
                        end
                    end
                    
                    if (j == 0) begin
                        j <= 4'd0;
                        next_state <= COMPUTE_RESULT;
                    end else begin
                        j <= j - 4'd1;
                    end
                end
                
                COMPUTE_RESULT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Find maximum length
                    if (j == 0) begin
                        max_len <= left[0];
                    end else if (j < n) begin
                        // Check single segment
                        if (left[j] > max_len) begin
                            max_len <= left[j];
                        end
                        if (right[j] > max_len) begin
                            max_len <= right[j];
                        end
                        
                        // Check merging segments
                        if (j > 0 && j < n-1 && arr[j-1] + 1 < arr[j+1]) begin
                            if (left[j-1] + right[j+1] > max_len) begin
                                max_len <= left[j-1] + right[j+1];
                            end
                        end
                    end
                    
                    if (j == n-1) begin
                        // Final check for n=1
                        if (n == 1) begin
                            max_len <= 1;
                        end
                        
                        // Extend by one if possible
                        if (max_len < n && max_len + 1 <= n) begin
                            max_len <= max_len + 1;
                        end
                        
                        result <= max_len;
                        next_state <= FINISH;
                    end else begin
                        j <= j + 4'd1;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule