module max_sum_inc_subseq (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_in,
    input wire [1:0] index,
    input wire [1:0] k,
    input wire write_en,
    output reg [15:0] result,
    output reg done,
    output reg arr_ready
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Array storage (8 elements, 8-bit signed)
    reg signed [7:0] arr [0:7];
    reg [2:0] arr_index;
    
    // DP table (8x8, 16-bit signed)
    reg signed [15:0] dp [0:7][0:7];
    
    // Loop counters
    reg [2:0] i, j;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Control signals
    reg load_complete;
    reg computation_complete;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            arr_index <= 3'd0;
            load_complete <= 1'b0;
            computation_complete <= 1'b0;
            i <= 3'd0;
            j <= 3'd0;
            cycle_count <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
            arr_ready <= 1'b0;
            
            // Initialize array
            integer idx;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                arr[idx] <= 8'd0;
            end
            
            // Initialize DP table
            integer x, y;
            for (x = 0; x < 8; x = x + 1) begin
                for (y = 0; y < 8; y = y + 1) begin
                    dp[x][y] <= 16'd0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    arr_ready <= load_complete;
                    if (start && load_complete) begin
                        next_state <= COMPUTE;
                        computation_complete <= 1'b0;
                        i <= 3'd0;
                        j <= 3'd0;
                        cycle_count <= 8'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD: begin
                    if (write_en) begin
                        arr[arr_index] <= arr_in;
                        arr_index <= arr_index + 3'd1;
                        
                        if (arr_index == 3'd7) begin
                            load_complete <= 1'b1;
                            arr_ready <= 1'b1;
                            next_state <= IDLE;
                        end else begin
                            next_state <= LOAD;
                        end
                    end else begin
                        next_state <= LOAD;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Initialize base case for i=0
                    if (i == 3'd0) begin
                        if (j == 3'd0) begin
                            dp[0][0] <= arr[0];
                        end else if (j < 3'd4) begin
                            if (arr[j] > arr[0]) begin
                                dp[0][j] <= arr[0] + arr[j];
                            end else begin
                                dp[0][j] <= arr[j];
                            end
                        end
                        
                        j <= j + 3'd1;
                        if (j == 3'd4) begin
                            j <= 3'd0;
                            i <= i + 3'd1;
                        end
                    end
                    // Main DP computation
                    else if (i < 3'd4) begin
                        if (j == 3'd0) begin
                            dp[i][0] <= dp[i-1][0];
                            j <= j + 3'd1;
                        end else if (j < 3'd4) begin
                            if (arr[j] > arr[i] && j > i) begin
                                if (dp[i-1][i] + arr[j] > dp[i-1][j]) begin
                                    dp[i][j] <= dp[i-1][i] + arr[j];
                                end else begin
                                    dp[i][j] <= dp[i-1][j];
                                end
                            end else begin
                                dp[i][j] <= dp[i-1][j];
                            end
                            
                            j <= j + 3'd1;
                            if (j == 3'd4) begin
                                j <= 3'd0;
                                i <= i + 3'd1;
                            end
                        end
                    end
                    
                    // Check completion
                    if (i == 3'd4 || cycle_count >= MAX_CYCLES) begin
                        computation_complete <= 1'b1;
                        next_state <= FINISH;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end
                
                FINISH: begin
                    result <= dp[index][k];
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    arr_ready <= 1'b0;
                end
            endcase
        end
    end
    
    // Start loading when write_en is asserted
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            next_state <= IDLE;
        end else begin
            if (state == IDLE && write_en && !load_complete) begin
                next_state <= LOAD;
                arr_ready <= 1'b0;
            end
        end
    end
    
    // Clear done after one cycle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state != FINISH) begin
                done <= 1'b0;
            end
        end
    end
    
    // Clear arr_ready after one cycle
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arr_ready <= 1'b0;
        end else begin
            if (state != LOAD || !load_complete) begin
                arr_ready <= 1'b0;
            end
        end
    end

endmodule