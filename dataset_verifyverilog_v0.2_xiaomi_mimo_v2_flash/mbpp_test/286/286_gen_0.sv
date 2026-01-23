module max_subarray_repeated(
    input clk,
    input rst_n,
    input start,
    input [1:0] n,
    input [1:0] k,
    input signed [31:0] a [0:3],
    output reg [31:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam CHECK_DONE = 2'b10;
    localparam DONE_STATE = 2'b11;

    reg [1:0] state;
    reg [31:0] max_so_far;
    reg signed [31:0] max_ending_here;
    reg [31:0] i; // Index from 0 to n*k-1 (max 12, but using 32-bit for safety)
    reg signed [31:0] current_val;
    
    // Helper signals for comparisons
    wire [31:0] n_k_mult;
    assign n_k_mult = n * k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 0;
            done <= 0;
            max_so_far <= 32'h80000000; // Min signed 32-bit value
            max_ending_here <= 0;
            i <= 0;
            current_val <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Reset state for new computation
                        // Max so far needs to be initialized to min value to handle all negative arrays
                        max_so_far <= 32'h80000000;
                        max_ending_here <= 0;
                        i <= 0;
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    // Access array element a[i % n]
                    // Assuming n=2,3,4 maps to indices 0,1,2,3
                    current_val <= a[i % n];
                    state <= CHECK_DONE;
                end

                CHECK_DONE: begin
                    // Perform Kadane's algorithm update
                    // max_ending_here = max_ending_here + current_val
                    // If max_ending_here < 0, reset to 0
                    // max_so_far = max(max_so_far, max_ending_here)
                    
                    if ($signed(max_ending_here + current_val) < 0) begin
                        max_ending_here <= 0;
                    end else begin
                        max_ending_here <= max_ending_here + current_val;
                    end

                    // Update max_so_far
                    // We compare the potential new value of max_ending_here with current max_so_far
                    // Note: max_ending_here logic is combinational in concept, but we are pipelining it
                    // So we calculate the potential value here or rely on previous logic. 
                    // Let's use the calculated value.
                    
                    if ($signed(max_ending_here + current_val) > $signed(max_so_far)) begin
                        max_so_far <= max_ending_here + current_val;
                    end
                    
                    // Increment index
                    i <= i + 1;
                    
                    // Check if done
                    if (i + 1 >= n_k_mult) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= PROCESSING;
                    end
                end

                DONE_STATE: begin
                    result <= max_so_far;
                    done <= 1;
                    if (!start) begin // Wait for start to go low before returning to IDLE
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule