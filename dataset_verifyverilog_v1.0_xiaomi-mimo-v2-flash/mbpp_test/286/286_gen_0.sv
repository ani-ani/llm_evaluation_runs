module max_subarray_kadane (
    input clk,
    input rst_n,
    input start,
    input [63:0] a,
    input [3:0] n,
    input [4:0] k,
    output reg signed [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Registers
    reg [1:0] state, next_state;
    reg signed [15:0] max_so_far, next_max_so_far;
    reg signed [15:0] max_ending_here, next_max_ending_here;
    reg [7:0] loop_counter, next_loop_counter;
    reg [15:0] total_length, next_total_length;
    reg [7:0] mod_n, next_mod_n;
    reg signed [7:0] current_val;
    reg [7:0] i;

    // Combinational logic for array access and calculations
    always @(*) begin
        // Default assignments
        next_state = state;
        next_max_so_far = max_so_far;
        next_max_ending_here = max_ending_here;
        next_loop_counter = loop_counter;
        next_total_length = total_length;
        next_mod_n = mod_n;
        done = 1'b0;
        
        // Calculate current value from flattened array 'a'
        // a is [63:0], each element is 8 bits
        // We need to access a[mod_n * 8 +: 8]
        current_val = 8'sd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i == mod_n) begin
                current_val = a[i*8 +: 8];
            end
        end

        case (state)
            IDLE: begin
                if (start) begin
                    next_loop_counter = 8'd0;
                    next_total_length = n * k;
                    next_mod_n = 8'd0;
                    
                    // Initialize Kadane's algorithm
                    // For first element, max_so_far = max_ending_here = a[0]
                    current_val = a[7:0];
                    next_max_ending_here = { {8{a[7]}}, a[7:0] }; // Sign extend 8 to 16 bits
                    next_max_so_far = { {8{a[7]}}, a[7:0] };
                    
                    if (total_length > 1) begin
                        next_state = COMPUTE;
                    end else begin
                        // Single element case
                        next_state = FINISH;
                    end
                end
            end
            
            COMPUTE: begin
                // Sign extend current_val to 16 bits
                wire signed [15:0] val_extended;
                assign val_extended = { {8{current_val[7]}}, current_val };
                
                // Kadane's algorithm logic
                if (max_ending_here + val_extended > val_extended) begin
                    next_max_ending_here = max_ending_here + val_extended;
                end else begin
                    next_max_ending_here = val_extended;
                end
                
                if (next_max_ending_here > max_so_far) begin
                    next_max_so_far = next_max_ending_here;
                end else begin
                    next_max_so_far = max_so_far;
                end
                
                // Increment loop counter
                next_loop_counter = loop_counter + 8'd1;
                
                // Update mod_n for next iteration
                if (loop_counter + 8'd1 >= total_length) begin
                    next_state = FINISH;
                end else begin
                    next_mod_n = (loop_counter + 8'd1) % n;
                end
            end
            
            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_so_far <= 16'sd0;
            max_ending_here <= 16'sd0;
            loop_counter <= 8'd0;
            total_length <= 16'd0;
            mod_n <= 8'd0;
            result <= 16'sd0;
        end else begin
            state <= next_state;
            max_so_far <= next_max_so_far;
            max_ending_here <= next_max_ending_here;
            loop_counter <= next_loop_counter;
            total_length <= next_total_length;
            mod_n <= next_mod_n;
            
            if (state == FINISH) begin
                result <= max_so_far;
            end
        end
    end

endmodule