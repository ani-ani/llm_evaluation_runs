module MaxPathAverage(
    input clk,
    input rst_n,
    input start,
    input [63:0] cost,
    input valid_input,
    output reg signed [15:0] result,
    output reg done,
    output reg overflow
);
    
    // Parameters
    localparam [2:0] N = 3'd8;
    localparam [3:0] DATA_WIDTH = 4'd8;
    localparam [3:0] DP_WIDTH = 4'd16;
    localparam [3:0] OUT_WIDTH = 4'd16;
    localparam [3:0] PATH_LEN = 4'd15; // 2*N-1
    
    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_ROW0 = 3'd1;
    localparam [2:0] LOAD_ROWS = 3'd2;
    localparam [2:0] COMPUTE_AVG = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;
    
    // State registers
    reg [2:0] state, next_state;
    
    // DP registers (current and previous row)
    reg signed [DP_WIDTH-1:0] dp_prev [0:N-1];
    reg signed [DP_WIDTH-1:0] dp_curr [0:N-1];
    
    // Row and column counters
    reg [2:0] row;
    reg [2:0] col;
    
    // Intermediate sum and overflow detection
    reg signed [DP_WIDTH:0] sum_temp; // Extra bit for overflow detection
    reg overflow_detected;
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            overflow <= 1'b0;
            cycle_count <= 8'd0;
            row <= 3'd0;
            col <= 3'd0;
            overflow_detected <= 1'b0;
            
            // Initialize DP arrays
            integer i;
            for (i = 0; i < N; i = i + 1) begin
                dp_prev[i] <= 16'd0;
                dp_curr[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    overflow <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start && valid_input) begin
                        next_state <= LOAD_ROW0;
                        row <= 3'd0;
                        col <= 3'd0;
                        overflow_detected <= 1'b0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LOAD_ROW0: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process first row (left to right)
                    if (col == 3'd0) begin
                        // First cell
                        dp_curr[0] <= cost[7:0];
                        col <= col + 3'd1;
                    end else if (col < N) begin
                        // Accumulate along first row
                        sum_temp <= {1'b0, dp_curr[col-1]} + cost[(col*8)-1:(col-1)*8];
                        
                        // Check for overflow
                        if (sum_temp[DP_WIDTH]) begin
                            overflow_detected <= 1'b1;
                        end
                        
                        dp_curr[col] <= sum_temp[DP_WIDTH-1:0];
                        col <= col + 3'd1;
                    end else begin
                        // Move to next state
                        next_state <= LOAD_ROWS;
                        row <= row + 3'd1;
                        col <= 3'd0;
                        
                        // Copy current to previous for next row
                        integer i;
                        for (i = 0; i < N; i = i + 1) begin
                            dp_prev[i] <= dp_curr[i];
                        end
                    end
                end
                
                LOAD_ROWS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (row < N) begin
                        if (col == 3'd0) begin
                            // First column of row
                            sum_temp <= {1'b0, dp_prev[col]} + cost[(row*8)+7:(row*8)];
                            
                            if (sum_temp[DP_WIDTH]) begin
                                overflow_detected <= 1'b1;
                            end
                            
                            dp_curr[col] <= sum_temp[DP_WIDTH-1:0];
                            col <= col + 3'd1;
                        end else if (col < N) begin
                            // Middle columns
                            reg signed [DP_WIDTH-1:0] max_val;
                            
                            if (dp_prev[col] > dp_curr[col-1]) begin
                                max_val <= dp_prev[col];
                            end else begin
                                max_val <= dp_curr[col-1];
                            end
                            
                            sum_temp <= {1'b0, max_val} + cost[(row*8)+7+(col*8):(row*8)+(col*8)];
                            
                            if (sum_temp[DP_WIDTH]) begin
                                overflow_detected <= 1'b1;
                            end
                            
                            dp_curr[col] <= sum_temp[DP_WIDTH-1:0];
                            col <= col + 3'd1;
                        end else begin
                            // Last column
                            sum_temp <= {1'b0, dp_prev[col]} + cost[(row*8)+7+(col*8):(row*8)+(col*8)];
                            
                            if (sum_temp[DP_WIDTH]) begin
                                overflow_detected <= 1'b1;
                            end
                            
                            dp_curr[col] <= sum_temp[DP_WIDTH-1:0];
                            col <= 3'd0;
                            row <= row + 3'd1;
                            
                            // Copy current to previous for next row
                            integer i;
                            for (i = 0; i < N; i = i + 1) begin
                                dp_prev[i] <= dp_curr[i];
                            end
                        end
                    end else begin
                        next_state <= COMPUTE_AVG;
                    end
                end
                
                COMPUTE_AVG: begin
                    // Final result is in dp_curr[N-1] (bottom-right corner)
                    // Compute average: sum * 256 / 15 (Q8.8 format)
                    reg signed [31:0] mult_temp;
                    reg signed [31:0] div_temp;
                    
                    // Multiply by 256 (shift left by 8)
                    mult_temp <= {dp_curr[N-1], 8'd0};
                    
                    // Divide by 15 (PATH_LEN)
                    div_temp <= mult_temp / PATH_LEN;
                    
                    result <= div_temp[15:0];
                    overflow <= overflow_detected;
                    next_state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    overflow <= 1'b0;
                end
            endcase
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
                overflow <= 1'b1; // Indicate timeout as overflow
            end
        end
    end
endmodule