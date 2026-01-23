module digit_product_distribution (
    input clk,
    input rst_n,
    input start,
    input [15:0] L,
    input [15:0] R,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam ITERATE = 3'b001;
    localparam PROCESS_NUMBER = 3'b010;
    localparam UPDATE_COUNT = 3'b011;
    localparam CHECK_DONE = 3'b100;
    localparam DONE_STATE = 3'b101;

    // Registers
    reg [2:0] state;
    reg [15:0] current_x;
    reg [15:0] temp_val; // Holds the current number or intermediate product
    reg [3:0] counts [8:0]; // 9 counters for digits 1-9 (index 0 is digit 1)
    
    // Temporary calculation registers
    reg [3:0] digit;
    reg [15:0] product;
    reg [15:0] remaining;
    reg product_valid;

    // Variable for loop iterations (combinational logic within FSM)
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'b0;
            done <= 1'b0;
            current_x <= 16'b0;
            temp_val <= 16'b0;
            product_valid <= 1'b0;
            // Reset counters
            for (i = 0; i < 9; i = i + 1) begin
                counts[i] <= 4'b0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'b0;
                    if (start) begin
                        // Reset counters on start
                        for (i = 0; i < 9; i = i + 1) begin
                            counts[i] <= 4'b0;
                        end
                        current_x <= L;
                        state <= ITERATE;
                    end
                end

                ITERATE: begin
                    // Check if current_x exceeds R
                    if (current_x > R) begin
                        state <= DONE_STATE;
                    end else begin
                        // Start processing the number
                        temp_val <= current_x;
                        product_valid <= 1'b0;
                        state <= PROCESS_NUMBER;
                    end
                end

                PROCESS_NUMBER: begin
                    // Extract digits, filter zeros, and multiply
                    if (!product_valid) begin
                        // First pass: isolate digits and multiply
                        product <= 1'b1; // Initialize product to 1
                        remaining <= temp_val;
                        // Need multiple cycles to process digits of temp_val
                        // Let's use a counter or state to iterate digits
                        // Since 16-bit max 5 digits, we can unroll or use a sub-state
                        // For simplicity and efficiency, we unroll logic over cycles
                        
                        // We will extract digits one by one. 
                        // Let's use 'remaining' to track what's left.
                        // We can use 'digit' reg to hold current digit.
                        
                        // We need a sub-step to handle digit extraction loop
                        // To avoid complex sub-states, we can perform extraction in a single cycle
                        // if we assume 'temp_val' is stable. 
                        // Let's use a 'calc_step' counter or just assume extraction happens here.
                        
                        // However, since it's sequential, we need to handle the multiplication loop.
                        // We can use temp_val directly. 
                        // Let's do: Extract digits, multiply. If result >= 10, repeat.
                        
                        // Since we are in PROCESS_NUMBER, let's do the digit product logic.
                        // We will use 'temp_val' as the number we are reducing.
                        
                        // Step 1: Extract digits and multiply
                        // We can compute the product of nonzero digits of temp_val in one cycle
                        // using combinational logic inferred here.
                        // Let's assume standard single-cycle combinational block for digit product.
                        // If temp_val < 10, we are done with this number.
                        
                        if (temp_val < 10) begin
                            // Single digit found
                            if (temp_val >= 1 && temp_val <= 9) begin
                                // Valid digit 1-9, prepare to update count
                                digit <= temp_val[3:0];
                                state <= UPDATE_COUNT;
                            end else begin
                                // Should not happen for >= 1, but skip 0
                                state <= CHECK_DONE;
                            end
                        end else begin
                            // Need to multiply digits
                            // Calculate product of nonzero digits of temp_val
                            // We use a temporary accumulator for this cycle
                            reg [15:0] p;
                            reg [3:0] d;
                            reg [15:0] t;
                            integer k;
                            p = 1;
                            t = temp_val;
                            // Unrolled loop for digit extraction (max 5 digits)
                            for (k = 0; k < 5; k = k + 1) begin
                                d = t % 10;
                                t = t / 10;
                                if (d != 0) p = p * d;
                            end
                            
                            temp_val <= p; // Update temp_val with new product
                            // Stay in PROCESS_NUMBER to check if p < 10 in next cycle
                        end
                    end
                end

                UPDATE_COUNT: begin
                    // Increment the counter for 'digit'
                    // digit is 1-9. counts index is 0-8.
                    // Use a case statement or if/else
                    // To avoid large combinational logic in always block, we use if/else
                    if (digit == 1) counts[0] <= counts[0] + 1;
                    else if (digit == 2) counts[1] <= counts[1] + 1;
                    else if (digit == 3) counts[2] <= counts[2] + 1;
                    else if (digit == 4) counts[3] <= counts[3] + 1;
                    else if (digit == 5) counts[4] <= counts[4] + 1;
                    else if (digit == 6) counts[5] <= counts[5] + 1;
                    else if (digit == 7) counts[6] <= counts[6] + 1;
                    else if (digit == 8) counts[7] <= counts[7] + 1;
                    else if (digit == 9) counts[8] <= counts[8] + 1;
                    
                    state <= CHECK_DONE;
                end

                CHECK_DONE: begin
                    // Increment current_x and go back to ITERATE
                    current_x <= current_x + 1;
                    state <= ITERATE;
                end

                DONE_STATE: begin
                    // Pack the results into 16-bit output
                    // {a1[3:0], a2[3:0], ..., a9[3:0]} -> 36 bits. 
                    // Requirement says "Result output is 16-bit", mapping to 9 counts.
                    // Since 16 bits cannot hold 9 nibbles, we must truncate or pack as much as possible.
                    // Usually, this implies packing the first few counts.
                    // Let's pack counts 1, 2, 3, 4 into the 16 bits (4 nibbles = 16 bits).
                    // Or maybe just sum them? No, "Packed count".
                    // Let's pack count1 (digit '1') through count4 (digit '4').
                    result <= {counts[3], counts[2], counts[1], counts[0]};
                    done <= 1'b1;
                    state <= IDLE; // Or stay here until reset? Usually IDLE allows restart.
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule