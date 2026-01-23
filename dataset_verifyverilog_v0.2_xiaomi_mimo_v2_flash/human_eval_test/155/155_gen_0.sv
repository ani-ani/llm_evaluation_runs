module even_odd_count (
    input clk,
    input rst_n,
    input start,
    input signed [31:0] num,
    output reg [4:0] even_count,
    output reg [4:0] odd_count,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [31:0] temp, next_temp;
    reg [3:0] digit_count, next_digit_count;
    reg [4:0] next_even_count, next_odd_count;
    reg next_done;

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            temp <= 32'b0;
            digit_count <= 4'b0;
            even_count <= 5'b0;
            odd_count <= 5'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            temp <= next_temp;
            digit_count <= next_digit_count;
            even_count <= next_even_count;
            odd_count <= next_odd_count;
            done <= next_done;
        end
    end

    // Combinational next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_temp = temp;
        next_digit_count = digit_count;
        next_even_count = even_count;
        next_odd_count = odd_count;
        next_done = done;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    next_state = PROCESSING;
                    next_even_count = 5'b0;
                    next_odd_count = 5'b0;
                    next_digit_count = 4'b0;
                    // Take absolute value of num
                    if (num[31]) begin
                        next_temp = -num;
                    end else begin
                        next_temp = num;
                    end
                    // Special case for 0: needs to count as 1 even digit
                    if (num == 32'sd0) begin
                        next_even_count = 5'd1;
                        next_state = DONE;
                    end
                end else begin
                    next_temp = 32'b0;
                end
            end

            PROCESSING: begin
                if (temp != 32'b0 && digit_count < 10) begin
                    // Extract last digit
                    // Using subtraction algorithm is implicitly handled by % operator in synthesis
                    // for powers of 2, but for 10 it's sequential. However, the spec implies
                    // using the operator is acceptable or needs to be sequential.
                    // Let's use a simple extraction logic.
                    // To be fully sequential without division, we would need a loop.
                    // Given the 10 cycle requirement, we extract one digit per cycle.
                    
                    // We need to implement modulo and division manually or use operators.
                    // Let's assume synthesis handles % and / with reasonable latency,
                    // but to meet the exact 10 cycles for digits, we need to do it iteratively.
                    // A simple implementation using operators will likely take more than 1 cycle,
                    // but for this specific problem structure, we will use operators and 
                    // assume the synthesis tool optimizes it or we count the digit processing
                    // as a single state iteration.
                    
                    // However, to be strictly sequential and efficient, let's use subtraction.
                    // Actually, the simplest way to be strictly 1 cycle per digit is:
                    // 1. Check digit (temp % 10)
                    // 2. Divide (temp / 10)
                    // But since division by 10 is complex, the prompt suggests using operators
                    // OR a subtraction method. Given the timing (12 cycles total), 
                    // we will treat one PROCESSING state as one digit extraction.
                    
                    // Logic to extract digit without division operator (more hardware friendly for sequential):
                    // We can't easily do it in one combinational block for arbitrary 32-bit numbers without operators.
                    // So we will use the standard % and / operators. Modern synthesis tools implement these efficiently.
                    // If strictly sequential iterative logic is required, it would look like a loop in the FSM, 
                    // but that would take many states per digit. 
                    // Given the explicit "10 cycles for digits" requirement, we process one digit per cycle.
                    
                    // Note: The prompt allows assuming compiler synthesis handles /10. 
                    // So we use the operators.
                    
                    if (temp % 10 == 0 || temp % 10 == 2 || temp % 10 == 4 || temp % 10 == 6 || temp % 10 == 8) begin
                        next_even_count = even_count + 1;
                    end else begin
                        next_odd_count = odd_count + 1;
                    end
                    
                    next_temp = temp / 10;
                    next_digit_count = digit_count + 1;
                    
                    // Check if done after this extraction
                    if (temp / 10 == 32'b0) begin
                        next_state = DONE;
                    end
                end else begin
                    // If temp is 0 or we reached 10 digits, go to DONE
                    next_state = DONE;
                end
            end

            DONE: begin
                next_done = 1'b1;
                // Wait for start to go low to return to IDLE, or reset
                if (!start) begin
                    next_state = IDLE;
                    next_done = 1'b0;
                end
            end

            default: begin
                next_state = IDLE;
                next_temp = 32'b0;
                next_digit_count = 4'b0;
                next_even_count = 5'b0;
                next_odd_count = 5'b0;
                next_done = 1'b0;
            end
        endcase
    end

endmodule