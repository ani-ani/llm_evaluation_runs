module median_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] data_in,
    input wire data_in_valid,
    input wire [3:0] len,
    output reg signed [7:0] data_out,
    output reg [3:0] data_out_addr,
    output reg data_out_valid,
    output reg done,
    output reg signed [15:0] result
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FILL = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] SWAP = 3'd3;
    localparam [2:0] MEDIAN = 3'd4;
    localparam [2:0] FINISH = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;
    
    // Memory (16 elements, 8-bit signed)
    reg signed [7:0] mem [0:15];
    
    // State machine
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Fill counter
    reg [3:0] fill_count;
    
    // Sort variables
    reg [3:0] i;      // Outer loop index
    reg [3:0] j;      // Inner loop index
    reg [3:0] min_idx;
    reg signed [7:0] min_val;
    reg swap_pending;
    reg signed [7:0] temp_val;
    
    // Medain calculation
    reg signed [15:0] sum;
    reg [15:0] avg_result;
    reg odd_flag;
    reg [3:0] mid_idx;
    
    // Cycle counter for timeout
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd256;
    
    // Done flag tracking
    reg done_pending;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            fill_count <= 4'd0;
            i <= 4'd0;
            j <= 4'd0;
            min_idx <= 4'd0;
            min_val <= 8'sd0;
            swap_pending <= 1'b0;
            temp_val <= 8'sd0;
            sum <= 16'sd0;
            avg_result <= 16'd0;
            odd_flag <= 1'b0;
            mid_idx <= 4'd0;
            cycle_count <= 9'd0;
            done_pending <= 1'b0;
            data_out <= 8'sd0;
            data_out_addr <= 4'd0;
            data_out_valid <= 1'b0;
            done <= 1'b0;
            result <= 16'sd0;
            
            // Initialize memory
            mem[0] <= 8'sd0;
            mem[1] <= 8'sd0;
            mem[2] <= 8'sd0;
            mem[3] <= 8'sd0;
            mem[4] <= 8'sd0;
            mem[5] <= 8'sd0;
            mem[6] <= 8'sd0;
            mem[7] <= 8'sd0;
            mem[8] <= 8'sd0;
            mem[9] <= 8'sd0;
            mem[10] <= 8'sd0;
            mem[11] <= 8'sd0;
            mem[12] <= 8'sd0;
            mem[13] <= 8'sd0;
            mem[14] <= 8'sd0;
            mem[15] <= 8'sd0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 9'd0;
                    done_pending <= 1'b0;
                    data_out_valid <= 1'b0;
                    
                    if (start) begin
                        fill_count <= 4'd0;
                        state <= FILL;
                    end
                end
                
                FILL: begin
                    if (data_in_valid && fill_count < len) begin
                        mem[fill_count] <= data_in;
                        fill_count <= fill_count + 4'd1;
                    end
                    
                    if (fill_count >= len && !data_in_valid) begin
                        i <= 4'd0;
                        j <= 4'd0;
                        min_idx <= 4'd0;
                        cycle_count <= 9'd0;
                        state <= SORT;
                    end
                end
                
                SORT: begin
                    cycle_count <= cycle_count + 9'd1;
                    
                    if (i < (len - 4'd1)) begin
                        if (cycle_count < MAX_CYCLES) begin
                            j <= i + 4'd1;
                            min_idx <= i;
                            min_val <= mem[i];
                            swap_pending <= 1'b0;
                            state <= SORT;
                            
                            // Find min in inner loop
                            if (j < len) begin
                                if (mem[j] < min_val) begin
                                    min_val <= mem[j];
                                    min_idx <= j;
                                end
                                j <= j + 4'd1;
                            end
                            
                            // End of inner loop
                            if (j >= len) begin
                                if (min_idx != i) begin
                                    // Swap needed
                                    data_out <= mem[i];
                                    data_out_addr <= i;
                                    data_out_valid <= 1'b1;
                                    swap_pending <= 1'b1;
                                    temp_val <= mem[min_idx];
                                    state <= SWAP;
                                end else begin
                                    // No swap, move to next i
                                    i <= i + 4'd1;
                                    state <= SORT;
                                end
                            end
                        end else begin
                            // Timeout - go to median
                            state <= MEDIAN;
                        end
                    end else begin
                        // Sorting complete
                        state <= MEDIAN;
                    end
                end
                
                SWAP: begin
                    data_out_valid <= 1'b0;
                    
                    if (swap_pending) begin
                        // Complete the swap in memory
                        mem[i] <= temp_val;
                        mem[min_idx] <= data_out;
                        swap_pending <= 1'b0;
                        i <= i + 4'd1;
                        state <= SORT;
                    end
                end
                
                MEDIAN: begin
                    // Calculate median
                    if (len > 4'd0) begin
                        if (len[0] == 1'b1) begin
                            // Odd length
                            odd_flag <= 1'b1;
                            mid_idx <= len >> 1;  // len/2
                            sum <= 16'sd0;
                            state <= FINISH;
                        end else begin
                            // Even length
                            odd_flag <= 1'b0;
                            mid_idx <= (len >> 1) - 4'd1;  // len/2 - 1
                            sum <= 16'sd0;
                            state <= FINISH;
                        end
                    end
                end
                
                FINISH: begin
                    if (odd_flag) begin
                        // Odd: middle element as Q8.8 (integer part only)
                        result <= {mem[mid_idx], 8'b00000000};
                    end else begin
                        // Even: average of two middle elements
                        sum <= mem[mid_idx] + mem[mid_idx + 4'd1];
                        
                        // Calculate Q8.8: (sum/2) with fractional .5 if sum is odd
                        // result[15:8] = sum[8:1] (integer part)
                        // result[7:0] = {sum[0], 7'd0} (fractional part, .5 or .0)
                        result <= {sum[8:1], {sum[0], 7'b0000000}};
                    end
                    
                    done_pending <= 1'b1;
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule