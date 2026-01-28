module MaxIncreasingSubsegment(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] n,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPUTE_L = 3'd1;
    localparam [2:0] COMPUTE_R = 3'd2;
    localparam [2:0] CALCULATE = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    reg [2:0] state, next_state;
    
    // Internal arrays (max 16 elements)
    reg [7:0] left [0:15];   // left[i]: length of inc subseg ending at i
    reg [7:0] right [0:15];  // right[i]: length of inc subseg starting at i
    
    // Counters and indices
    reg [3:0] i;             // 0-15
    reg [3:0] j;             // 0-15
    reg [7:0] temp_result;
    reg [7:0] merge_result;
    reg [7:0] max_left;
    reg [7:0] max_right;
    reg [7:0] single_max;
    reg [7:0] extend_result;
    
    // Flags
    reg computing_left;
    reg computing_right;
    
    // Cycle counter for timeout protection
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State register and reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            temp_result <= 8'd0;
            merge_result <= 8'd0;
            max_left <= 8'd0;
            max_right <= 8'd0;
            single_max <= 8'd0;
            extend_result <= 8'd0;
            computing_left <= 1'b0;
            computing_right <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize arrays
            integer idx;
            for (idx = 0; idx < 16; idx = idx + 1) begin
                left[idx] <= 8'd0;
                right[idx] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    i <= 4'd0;
                    j <= 4'd0;
                    temp_result <= 8'd0;
                    merge_result <= 8'd0;
                    max_left <= 8'd0;
                    max_right <= 8'd0;
                    single_max <= 8'd0;
                    extend_result <= 8'd0;
                    computing_left <= 1'b0;
                    computing_right <= 1'b0;
                    cycle_count <= 8'd0;
                end
                
                COMPUTE_L: begin
                    cycle_count <= cycle_count + 8'd1;
                    computing_left <= 1'b1;
                    if (i == 4'd0) begin
                        left[i] <= 8'd1;
                        max_left <= 8'd1;
                    end else begin
                        if (arr[i-1] < arr[i]) begin
                            left[i] <= left[i-1] + 8'd1;
                            if (left[i-1] + 8'd1 > max_left)
                                max_left <= left[i-1] + 8'd1;
                        end else begin
                            left[i] <= 8'd1;
                            if (8'd1 > max_left)
                                max_left <= 8'd1;
                        end
                    end
                    if (i < n - 4'd1)
                        i <= i + 4'd1;
                end
                
                COMPUTE_R: begin
                    cycle_count <= cycle_count + 8'd1;
                    computing_right <= 1'b1;
                    j <= n - 4'd1 - i;
                    if (i == 4'd0) begin
                        right[n-4'd1] <= 8'd1;
                        max_right <= 8'd1;
                    end else begin
                        if (arr[n-4'd1-i+4'd1] < arr[n-4'd1-i]) begin
                            right[n-4'd1-i] <= right[n-4'd1-i+4'd1] + 8'd1;
                            if (right[n-4'd1-i+4'd1] + 8'd1 > max_right)
                                max_right <= right[n-4'd1-i+4'd1] + 8'd1;
                        end else begin
                            right[n-4'd1-i] <= 8'd1;
                            if (8'd1 > max_right)
                                max_right <= 8'd1;
                        end
                    end
                    if (i < n - 4'd1)
                        i <= i + 4'd1;
                end
                
                CALCULATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Single segment max
                    single_max <= (max_left > max_right) ? max_left : max_right;
                    
                    // Calculate merging with one change
                    merge_result <= 8'd0;
                    if (i < n - 4'd2) begin
                        // Check if arr[i-1] + 1 < arr[i+1]
                        if (arr[i] + 8'd1 < arr[i+2]) begin
                            if (left[i] + right[i+2] + 8'd1 > merge_result)
                                merge_result <= left[i] + right[i+2] + 8'd1;
                        end
                        i <= i + 4'd1;
                    end else begin
                        // Check extension
                        if (single_max < n[7:0]) begin
                            extend_result <= single_max + 8'd1;
                        end else begin
                            extend_result <= single_max;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // Final result calculation
                    if (merge_result > single_max) begin
                        result <= merge_result;
                    end else begin
                        if (extend_result > single_max)
                            result <= extend_result;
                        else
                            result <= single_max;
                    end
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start && (n != 4'd0)) begin
                    if (n == 4'd1) begin
                        next_state = FINISH;
                    end else begin
                        next_state = COMPUTE_L;
                    end
                end
            end
            
            COMPUTE_L: begin
                if ((i >= n - 4'd1) || (cycle_count >= MAX_CYCLES)) begin
                    next_state = COMPUTE_R;
                end
            end
            
            COMPUTE_R: begin
                if ((i >= n - 4'd1) || (cycle_count >= MAX_CYCLES)) begin
                    next_state = CALCULATE;
                    i <= 4'd0;
                end
            end
            
            CALCULATE: begin
                if (i >= n - 4'd2) begin
                    next_state = FINISH;
                end else if (cycle_count >= MAX_CYCLES) begin
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule