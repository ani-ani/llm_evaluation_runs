module max_subarray_sum_swaps(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    input wire [3:0] k,
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] DONE_STATE = 3'd2;
    
    reg [2:0] state;
    reg [7:0] l_reg, r_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10000;

    // Registers for current subarray and outside elements
    reg signed [7:0] subarray [0:15];
    reg signed [7:0] outside [0:15];
    reg signed [7:0] sorted_sub [0:15];
    reg signed [7:0] sorted_out [0:15];
    
    // Current max sum tracking
    reg signed [15:0] current_max;
    
    // Sorting network control
    reg [3:0] sort_iter;
    reg [3:0] swap_iter;
    
    // Odd-even sort for subarray (ascending)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            l_reg <= 8'd0;
            r_reg <= 8'd0;
            cycle_count <= 8'd0;
            current_max <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            sort_iter <= 4'd0;
            swap_iter <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        l_reg <= 8'd0;
                        r_reg <= 8'd0;
                        current_max <= 16'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Extract subarray and outside elements
                    integer i, j, m, n;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i >= l_reg && i <= r_reg) begin
                            subarray[i - l_reg] <= arr[i];
                        end else begin
                            outside[i - (i > r_reg ? r_reg + 1 : 0)] <= arr[i];
                        end
                    end
                    
                    // Sort subarray in ascending order (odd-even sort)
                    if (sort_iter < 4'd16) begin
                        for (i = 0; i < 15; i = i + 1) begin
                            if ((sort_iter % 2 == 0 && i % 2 == 0) || (sort_iter % 2 == 1 && i % 2 == 1)) begin
                                if (subarray[i] > subarray[i + 1]) begin
                                    reg signed [7:0] temp;
                                    temp <= subarray[i];
                                    subarray[i] <= subarray[i + 1];
                                    subarray[i + 1] <= temp;
                                end
                            end
                        end
                        sort_iter <= sort_iter + 4'd1;
                    end else begin
                        sort_iter <= 4'd0;
                        
                        // Sort outside in descending order
                        if (sort_iter < 4'd16) begin
                            for (i = 0; i < 15; i = i + 1) begin
                                if ((sort_iter % 2 == 0 && i % 2 == 0) || (sort_iter % 2 == 1 && i % 2 == 1)) begin
                                    if (outside[i] < outside[i + 1]) begin
                                        reg signed [7:0] temp;
                                        temp <= outside[i];
                                        outside[i] <= outside[i + 1];
                                        outside[i + 1] <= temp;
                                    end
                                end
                            end
                            sort_iter <= sort_iter + 4'd1;
                        end else begin
                            sort_iter <= 4'd0;
                            
                            // Perform up to k swaps
                            if (swap_iter < k) begin
                                if (outside[swap_iter] > subarray[swap_iter]) begin
                                    reg signed [7:0] temp;
                                    temp <= subarray[swap_iter];
                                    subarray[swap_iter] <= outside[swap_iter];
                                    outside[swap_iter] <= temp;
                                end
                                swap_iter <= swap_iter + 4'd1;
                            end else begin
                                swap_iter <= 4'd0;
                                
                                // Calculate sum
                                reg signed [15:0] sum;
                                sum <= 16'd0;
                                for (i = 0; i < 16; i = i + 1) begin
                                    if (i <= r_reg - l_reg) begin
                                        sum <= sum + subarray[i];
                                    end
                                end
                                
                                // Update max
                                if (sum > current_max) begin
                                    current_max <= sum;
                                end
                                
                                // Move to next subarray
                                if (r_reg == 15) begin
                                    if (l_reg == 15) begin
                                        state <= DONE_STATE;
                                    end else begin
                                        l_reg <= l_reg + 8'd1;
                                        r_reg <= l_reg;
                                    end
                                end else begin
                                    r_reg <= r_reg + 8'd1;
                                end
                            end
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= current_max;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule