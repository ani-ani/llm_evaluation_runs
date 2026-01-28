module gcd_table_solver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire num_valid,
    input wire [31:0] num_in,
    input wire [7:0] table_len,
    output reg result_valid,
    output reg [15:0][31:0] result_array,
    output reg [3:0] result_len,
    output reg busy,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] ACCUMULATE = 3'd1;
    localparam [2:0] RECONSTRUCT = 3'd2;
    localparam [2:0] COMPLETE = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Input FIFO (256x32-bit)
    reg [31:0] fifo [0:255];
    reg [7:0] fifo_wr_ptr, fifo_rd_ptr;
    reg [7:0] fifo_count;
    
    // Counter table (256-entry)
    reg [7:0] counter_table [0:255];
    
    // Result array and length
    reg [31:0] result_reg [0:15];
    reg [3:0] result_count;
    
    // GCD computation unit
    reg [31:0] gcd_a, gcd_b;
    reg [31:0] gcd_result;
    reg [4:0] gcd_iter;
    reg gcd_busy;
    
    // Sorting network for unique values
    reg [31:0] sort_values [0:15];
    reg [3:0] sort_count;
    
    // Cycle counter for timeout
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd4095;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            
            // Reset FIFO
            fifo_wr_ptr <= 8'd0;
            fifo_rd_ptr <= 8'd0;
            fifo_count <= 8'd0;
            
            // Reset counter table
            integer i;
            for (i = 0; i < 256; i = i + 1) begin
                counter_table[i] <= 8'd0;
            end
            
            // Reset result array
            for (i = 0; i < 16; i = i + 1) begin
                result_reg[i] <= 32'd0;
            end
            result_count <= 4'd0;
            
            // Reset GCD unit
            gcd_a <= 32'd0;
            gcd_b <= 32'd0;
            gcd_result <= 32'd0;
            gcd_iter <= 5'd0;
            gcd_busy <= 1'b0;
            
            // Reset sorting
            for (i = 0; i < 16; i = i + 1) begin
                sort_values[i] <= 32'd0;
            end
            sort_count <= 4'd0;
            
            // Reset outputs
            result_valid <= 1'b0;
            result_len <= 4'd0;
            busy <= 1'b0;
            done <= 1'b0;
            
            cycle_count <= 12'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    
                    if (start) begin
                        next_state <= ACCUMULATE;
                        busy <= 1'b1;
                    end
                end
                
                ACCUMULATE: begin
                    if (num_valid && fifo_count < table_len) begin
                        fifo[fifo_wr_ptr] <= num_in;
                        fifo_wr_ptr <= fifo_wr_ptr + 8'd1;
                        fifo_count <= fifo_count + 8'd1;
                        
                        // Update counter table
                        counter_table[num_in[7:0]] <= counter_table[num_in[7:0]] + 8'd1;
                    end
                    
                    if (fifo_count == table_len) begin
                        next_state <= RECONSTRUCT;
                    end
                end
                
                RECONSTRUCT: begin
                    cycle_count <= cycle_count + 12'd1;
                    
                    // Extract unique values and sort
                    if (sort_count == 4'd0) begin
                        integer i, j;
                        reg [31:0] temp_values [0:255];
                        reg [3:0] temp_count;
                        
                        // Collect non-zero counters
                        temp_count = 4'd0;
                        for (i = 0; i < 256; i = i + 1) begin
                            if (counter_table[i] > 8'd0) begin
                                temp_values[temp_count] = {24'd0, i};
                                temp_count = temp_count + 4'd1;
                            end
                        end
                        
                        // Simple bubble sort (for <=16 values)
                        for (i = 0; i < temp_count - 4'd1; i = i + 1) begin
                            for (j = 0; j < temp_count - 4'd1 - i; j = j + 1) begin
                                if (temp_values[j] < temp_values[j + 4'd1]) begin
                                    reg [31:0] temp;
                                    temp = temp_values[j];
                                    temp_values[j] = temp_values[j + 4'd1];
                                    temp_values[j + 4'd1] = temp;
                                end
                            end
                        end
                        
                        // Copy to sort_values
                        for (i = 0; i < temp_count; i = i + 1) begin
                            sort_values[i] = temp_values[i];
                        end
                        sort_count = temp_count;
                    end
                    
                    // Process each candidate
                    if (sort_count > 4'd0 && result_count < 4'd16) begin
                        reg [31:0] candidate = sort_values[sort_count - 4'd1];
                        reg [7:0] candidate_val = candidate[7:0];
                        
                        if (counter_table[candidate_val] > 8'd0) begin
                            reg [3:0] i;
                            reg valid = 1'b1;
                            
                            // Check GCD with existing results
                            for (i = 0; i < result_count; i = i + 1) begin
                                gcd_a = result_reg[i];
                                gcd_b = candidate;
                                gcd_busy = 1'b1;
                                gcd_iter = 5'd0;
                                
                                // Iterative GCD computation
                                while (gcd_busy && gcd_iter < 5'd32) begin
                                    if (gcd_b == 32'd0) begin
                                        gcd_result = gcd_a;
                                        gcd_busy = 1'b0;
                                    end else begin
                                        if (gcd_a > gcd_b) begin
                                            gcd_a = gcd_a - gcd_b;
                                        end else begin
                                            gcd_b = gcd_b - gcd_a;
                                        end
                                        gcd_iter = gcd_iter + 5'd1;
                                    end
                                end
                                
                                if (counter_table[gcd_result[7:0]] == 8'd0) begin
                                    valid = 1'b0;
                                end
                            end
                            
                            if (valid) begin
                                result_reg[result_count] = candidate;
                                result_count = result_count + 4'd1;
                                
                                // Decrement counters
                                for (i = 0; i < result_count; i = i + 1) begin
                                    gcd_a = result_reg[i];
                                    gcd_b = candidate;
                                    gcd_busy = 1'b1;
                                    gcd_iter = 5'd0;
                                    
                                    while (gcd_busy && gcd_iter < 5'd32) begin
                                        if (gcd_b == 32'd0) begin
                                            gcd_result = gcd_a;
                                            gcd_busy = 1'b0;
                                        end else begin
                                            if (gcd_a > gcd_b) begin
                                                gcd_a = gcd_a - gcd_b;
                                            end else begin
                                                gcd_b = gcd_b - gcd_a;
                                            end
                                            gcd_iter = gcd_iter + 5'd1;
                                        end
                                    end
                                    
                                    if (counter_table[gcd_result[7:0]] > 8'd0) begin
                                        counter_table[gcd_result[7:0]] = counter_table[gcd_result[7:0]] - 8'd1;
                                    end
                                end
                            end
                            
                            sort_count = sort_count - 4'd1;
                        end
                    end
                    
                    // Check completion
                    if (result_count == table_len[3:0] || cycle_count >= MAX_CYCLES) begin
                        next_state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    // Output results
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        result_array[i] = result_reg[i];
                    end
                    result_len = result_count;
                    result_valid <= 1'b1;
                    done <= 1'b1;
                    next_state <= IDLE;
                    busy <= 1'b0;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

    // Output assignments
    always @(*) begin
        if (state == COMPLETE) begin
            result_valid = 1'b1;
            done = 1'b1;
        end else begin
            result_valid = 1'b0;
            done = 1'b0;
        end
    end

endmodule