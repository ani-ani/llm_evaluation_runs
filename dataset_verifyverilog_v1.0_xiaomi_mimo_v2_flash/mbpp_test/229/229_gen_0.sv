module array_rearrange (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:7],
    input wire [3:0] n,
    output reg signed [7:0] result [0:7],
    output reg done,
    output reg [2:0] valid
);

    // State declarations
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] READ_INPUT    = 3'd1;
    localparam [2:0] BUBBLE_NEG    = 3'd2;
    localparam [2:0] VERIFY_POS    = 3'd3;
    localparam [2:0] PAD_OUTPUT    = 3'd4;
    localparam [2:0] FINISH        = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg signed [7:0] work_array [0:7];
    reg [3:0] count;           // Cycle counter
    reg [3:0] i, j;            // Index counters
    reg signed [7:0] temp;     // Swap temporary
    reg [2:0] neg_count;       // Count of negative numbers
    reg swap_occurred;         // Flag for swap detection
    
    // Constants
    localparam [3:0] MAX_CYCLES = 4'd64;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? READ_INPUT : IDLE;
            
            READ_INPUT: next_state = BUBBLE_NEG;
            
            BUBBLE_NEG: begin
                if (i >= n || count >= MAX_CYCLES) begin
                    next_state = VERIFY_POS;
                end else begin
                    next_state = BUBBLE_NEG;
                end
            end
            
            VERIFY_POS: begin
                if (j >= neg_count || count >= MAX_CYCLES) begin
                    next_state = PAD_OUTPUT;
                end else begin
                    next_state = VERIFY_POS;
                end
            end
            
            PAD_OUTPUT: begin
                if (i >= 8'd8) begin
                    next_state = FINISH;
                end else begin
                    next_state = PAD_OUTPUT;
                end
            end
            
            FINISH: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            valid <= 3'd0;
            count <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            temp <= 8'sd0;
            neg_count <= 3'd0;
            swap_occurred <= 1'b0;
            
            // Reset work array and result array
            work_array[0] <= 8'sd0;
            work_array[1] <= 8'sd0;
            work_array[2] <= 8'sd0;
            work_array[3] <= 8'sd0;
            work_array[4] <= 8'sd0;
            work_array[5] <= 8'sd0;
            work_array[6] <= 8'sd0;
            work_array[7] <= 8'sd0;
            
            result[0] <= 8'sd0;
            result[1] <= 8'sd0;
            result[2] <= 8'sd0;
            result[3] <= 8'sd0;
            result[4] <= 8'sd0;
            result[5] <= 8'sd0;
            result[6] <= 8'sd0;
            result[7] <= 8'sd0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 4'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    neg_count <= 3'd0;
                    swap_occurred <= 1'b0;
                end
                
                READ_INPUT: begin
                    // Read input array elements
                    work_array[0] <= arr[0];
                    work_array[1] <= arr[1];
                    work_array[2] <= arr[2];
                    work_array[3] <= arr[3];
                    work_array[4] <= arr[4];
                    work_array[5] <= arr[5];
                    work_array[6] <= arr[6];
                    work_array[7] <= arr[7];
                    
                    i <= 4'd0;
                    j <= 4'd0;
                    count <= 4'd0;
                    swap_occurred <= 1'b0;
                end
                
                BUBBLE_NEG: begin
                    count <= count + 4'd1;
                    
                    // Bubble sort: move negatives to front
                    if (i < n && count < MAX_CYCLES) begin
                        if (work_array[i] >= 8'sd0) begin
                            // Find next negative element
                            if (i < n - 1) begin
                                if (work_array[i + 1] < 8'sd0) begin
                                    // Swap positive with negative
                                    temp <= work_array[i];
                                    work_array[i] <= work_array[i + 1];
                                    work_array[i + 1] <= temp;
                                    swap_occurred <= 1'b1;
                                end
                            end
                        end
                        
                        i <= i + 4'd1;
                    end else if (count >= MAX_CYCLES) begin
                        i <= n;
                    end
                    
                    // Count negatives
                    if (i >= n) begin
                        neg_count <= 3'd0;
                        i <= 4'd0;
                    end else if (work_array[i] < 8'sd0) begin
                        neg_count <= neg_count + 3'd1;
                    end
                end
                
                VERIFY_POS: begin
                    count <= count + 4'd1;
                    
                    // Verify positive order is maintained
                    if (j < neg_count && count < MAX_CYCLES) begin
                        // Ensure no negative numbers appear after positives
                        if (j < n - 1) begin
                            if (work_array[j] >= 8'sd0 && work_array[j + 1] < 8'sd0) begin
                                // Found negative after positive, swap
                                temp <= work_array[j];
                                work_array[j] <= work_array[j + 1];
                                work_array[j + 1] <= temp;
                            end
                        end
                        
                        j <= j + 4'd1;
                    end else if (count >= MAX_CYCLES) begin
                        j <= neg_count;
                    end
                end
                
                PAD_OUTPUT: begin
                    // Copy work array to result and pad with zeros
                    if (i < 4'd8) begin
                        if (i < n) begin
                            result[i] <= work_array[i];
                        end else begin
                            result[i] <= 8'sd0;
                        end
                        i <= i + 4'd1;
                    end
                    
                    if (i >= 4'd8) begin
                        valid <= neg_count; // Valid elements equals processed count
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid <= 3'd0;
                end
            endcase
        end
    end

    // State transition
    always @(posedge clk) begin
        state <= next_state;
    end

endmodule