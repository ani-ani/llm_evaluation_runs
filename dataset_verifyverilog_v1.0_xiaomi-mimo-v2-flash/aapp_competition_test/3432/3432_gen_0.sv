module min_max_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [6:0] A,
    input wire [6:0] B,
    input wire valid_in,
    output reg [15:0] result,
    output reg done,
    output reg ready
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] ACCEPTING  = 3'd1;
    localparam [2:0] SORTING    = 3'd2;
    localparam [2:0] COMPUTING  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Maximum number of rounds (N <= 16 for simulation)
    localparam [4:0] MAX_N = 5'd16;

    // Internal registers
    reg [2:0] state, next_state;
    reg [4:0] count, next_count;
    reg [4:0] input_count, next_input_count;
    reg [4:0] sort_count, next_sort_count;
    reg [4:0] compute_count, next_compute_count;
    
    // Arrays for storing A and B values (16 elements, 8-bit each)
    reg [7:0] A_vals [0:15];
    reg [7:0] B_vals [0:15];
    
    // Intermediate signals for sorting
    reg [7:0] temp_A [0:15];
    reg [7:0] temp_B [0:15];
    reg [7:0] next_temp_A [0:15];
    reg [7:0] next_temp_B [0:15];
    
    // Compute stage signals
    reg [15:0] sum [0:15];  // A[i] + B[i]
    reg [15:0] next_sum [0:15];
    reg [15:0] max_sum, next_max_sum;
    
    // Helper signals for sorting
    integer i;
    reg [7:0] swap_A;
    reg [7:0] swap_B;
    reg do_swap;

    // State transition and register update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 5'd0;
            input_count <= 5'd0;
            sort_count <= 5'd0;
            compute_count <= 5'd0;
            result <= 16'd0;
            done <= 1'b0;
            ready <= 1'b1;
            
            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                A_vals[i] <= 8'd0;
                B_vals[i] <= 8'd0;
                temp_A[i] <= 8'd0;
                temp_B[i] <= 8'd0;
                sum[i] <= 16'd0;
            end
            max_sum <= 16'd0;
        end else begin
            state <= next_state;
            count <= next_count;
            input_count <= next_input_count;
            sort_count <= next_sort_count;
            compute_count <= next_compute_count;
            result <= next_state == DONE_STATE ? max_sum : result;
            done <= (state == DONE_STATE);
            ready <= (next_state == IDLE) || (next_state == ACCEPTING);
            
            // Update arrays
            for (i = 0; i < 16; i = i + 1) begin
                if (state == ACCEPTING && valid_in && ready && (input_count < MAX_N)) begin
                    if (i == input_count) begin
                        A_vals[i] <= {1'b0, A};
                        B_vals[i] <= {1'b0, B};
                    end
                end else if (state == SORTING) begin
                    temp_A[i] <= next_temp_A[i];
                    temp_B[i] <= next_temp_B[i];
                end else if (state == COMPUTING) begin
                    sum[i] <= next_sum[i];
                end
            end
            
            max_sum <= next_max_sum;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_count = count;
        next_input_count = input_count;
        next_sort_count = sort_count;
        next_compute_count = compute_count;
        
        // Default outputs
        for (i = 0; i < 16; i = i + 1) begin
            next_temp_A[i] = temp_A[i];
            next_temp_B[i] = temp_B[i];
            next_sum[i] = sum[i];
        end
        next_max_sum = max_sum;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = ACCEPTING;
                    next_input_count = 5'd0;
                end
                next_count = 5'd0;
                next_sort_count = 5'd0;
                next_compute_count = 5'd0;
                next_max_sum = 16'd0;
            end
            
            ACCEPTING: begin
                if (valid_in && ready && (input_count < MAX_N)) begin
                    next_input_count = input_count + 5'd1;
                end
                
                if (input_count >= MAX_N) begin
                    next_state = SORTING;
                    next_sort_count = 5'd0;
                    // Copy initial values to temp arrays
                    for (i = 0; i < 16; i = i + 1) begin
                        next_temp_A[i] = A_vals[i];
                        next_temp_B[i] = B_vals[i];
                    end
                end
            end
            
            SORTING: begin
                // Bubble sort: sort A ascending, B descending
                // Each iteration processes one pass through the array
                if (sort_count < 5'd15) begin
                    for (i = 0; i < 15; i = i + 1) begin
                        // Sort A ascending
                        if (temp_A[i] > temp_A[i + 1]) begin
                            swap_A = temp_A[i];
                            next_temp_A[i] = temp_A[i + 1];
                            next_temp_A[i + 1] = swap_A;
                        end else begin
                            next_temp_A[i] = temp_A[i];
                            next_temp_A[i + 1] = temp_A[i + 1];
                        end
                        
                        // Sort B descending
                        if (temp_B[i] < temp_B[i + 1]) begin
                            swap_B = temp_B[i];
                            next_temp_B[i] = temp_B[i + 1];
                            next_temp_B[i + 1] = swap_B;
                        end else begin
                            next_temp_B[i] = temp_B[i];
                            next_temp_B[i + 1] = temp_B[i + 1];
                        end
                    end
                    next_sort_count = sort_count + 5'd1;
                end else begin
                    next_state = COMPUTING;
                    next_compute_count = 5'd0;
                    next_max_sum = 16'd0;
                    // Initialize compute stage
                    for (i = 0; i < 16; i = i + 1) begin
                        next_sum[i] = 16'd0;
                    end
                end
            end
            
            COMPUTING: begin
                // Calculate A[i] + B[i] and find maximum
                if (compute_count < MAX_N) begin
                    next_sum[compute_count] = {8'd0, temp_A[compute_count]} + {8'd0, temp_B[compute_count]};
                    
                    // Update max
                    if (next_sum[compute_count] > next_max_sum) begin
                        next_max_sum = next_sum[compute_count];
                    end
                    
                    next_compute_count = compute_count + 5'd1;
                end else begin
                    next_state = DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule