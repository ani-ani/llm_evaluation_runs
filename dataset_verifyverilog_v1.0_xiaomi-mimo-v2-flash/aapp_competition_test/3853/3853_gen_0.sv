module container_box (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] in_k,
    input wire [31:0] in_a,
    input wire in_valid,
    output reg [31:0] result_p,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] PROPAGATE    = 3'd1;
    localparam [2:0] PROCESS_INPUT = 3'd2;
    localparam [2:0] FINAL_PROP   = 3'd3;
    localparam [2:0] FINISH       = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [31:0] current_level;
    reg [31:0] current_level_next;
    reg [63:0] carry;
    reg [63:0] carry_next;
    reg [63:0] total;
    reg [31:0] result_p_next;
    reg done_next;

    // Temp storage for inputs
    reg [31:0] temp_k;
    reg [31:0] temp_a;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_level <= 32'd0;
            carry <= 64'd0;
            result_p <= 32'd0;
            done <= 1'b0;
            temp_k <= 32'd0;
            temp_a <= 32'd0;
        end else begin
            state <= next_state;
            current_level <= current_level_next;
            carry <= carry_next;
            result_p <= result_p_next;
            done <= done_next;
            if (state == IDLE && start) begin
                // Initialize on start
                current_level_next <= 32'd0;
                carry_next <= 64'd0;
            end
            if (in_valid && state == IDLE) begin
                temp_k <= in_k;
                temp_a <= in_a;
            end
        end
    end

    always @(*) begin
        next_state = state;
        current_level_next = current_level;
        carry_next = carry;
        result_p_next = result_p;
        done_next = 1'b0;

        case (state)
            IDLE: begin
                done_next = 1'b0;
                if (start) begin
                    // Reset logic handled in sequential block for start
                    current_level_next = 32'd0;
                    carry_next = 64'd0;
                end
                if (in_valid) begin
                    // Process first input immediately if available
                    if (current_level < in_k) begin
                        next_state = PROPAGATE;
                        temp_k = in_k;
                        temp_a = in_a;
                    end else begin
                        next_state = PROCESS_INPUT;
                        temp_k = in_k;
                        temp_a = in_a;
                    end
                end
            end

            PROPAGATE: begin
                // Propagate carry until current_level reaches input k
                // This handles gaps between levels
                if (current_level < temp_k) begin
                    // carry = ceil(carry / 4)
                    // Integer division rounding up: (x + 3) >> 2
                    carry_next = (carry + 64'd3) >> 2;
                    current_level_next = current_level + 32'd1;
                end else begin
                    // Reached level k
                    next_state = PROCESS_INPUT;
                end
            end

            PROCESS_INPUT: begin
                // Merge input count with current carry
                // total = carry + in_a (temp_a)
                total = carry + temp_a;
                
                // Update carry for next level: ceil(total / 4)
                carry_next = (total + 64'd3) >> 2;
                
                // Update current level to k + 1
                current_level_next = temp_k + 32'd1;

                // Check if this input was the last one
                // If so, go to final propagation. Otherwise return to IDLE.
                // NOTE: We assume external testbench provides 'last' signal or we detect end of stream.
                // Since spec doesn't provide 'last', we must assume the stream ends when in_valid is low.
                // However, strictly following the prompt's state machine description, we should
                // process until done. The problem is detecting the end of input stream.
                // Let's assume the testbench provides inputs continuously until done is expected.
                // To handle this correctly, we need a way to know if more inputs are coming.
                // The prompt says: "Use a state machine to consume inputs."
                // And "Iteration bounds: Process inputs sequentially."
                // A common pattern is to use a `last` input or stop when `in_valid` is low.
                // However, the interface provided is `in_valid`. 
                // Let's implement a logic where we stay in IDLE waiting for more inputs,
                // but if `start` is asserted again, we interpret that as "process remaining carry" -> DONE.
                // Or, we can rely on the fact that `in_valid` is a stream.
                // Let's look at the expected behavior: The result is computed after all inputs.
                // If `start` is a single pulse, we process until `in_valid` goes low, then finish.
                // But Verilog streams usually have `valid` and `last`.
                // Let's assume the testbench drives `in_valid` low when stream ends.
                // If we are in IDLE and `in_valid` is low, we proceed to FINAL_PROP.
                
                // Modification: In IDLE, if !in_valid and carry > 0 (and we have processed something), go to FINAL_PROP.
                // Or simpler: Assume the testbench signals the end by not sending more inputs.
                // We will go to IDLE. If we are in IDLE and no valid input and carry > 0, we go to FINAL_PROP.
                // But we need a trigger. Let's add a small logic in IDLE.
                // If in IDLE and !in_valid and carry > 0, next_state = FINAL_PROP.
                // BUT, `carry` is updated in PROCESS_INPUT.
                
                // Refined strategy:
                // In IDLE:
                //   if in_valid: process input
                //   else if carry > 0: go to FINAL_PROP (no more inputs)
                //   else: stay IDLE (empty)
                
                // So in PROCESS_INPUT, we always return to IDLE.
                next_state = IDLE;
            end

            FINAL_PROP: begin
                // Propagate remaining carry until it becomes 1
                if (carry > 64'd1) begin
                    carry_next = (carry + 64'd3) >> 2;
                    current_level_next = current_level + 32'd1;
                end else begin
                    // carry is 1 (or 0, but 0 is impossible if we entered here with valid data)
                    // Result is current_level if carry == 1
                    // If carry == 0 (should not happen), result is 0 or previous level
                    if (carry == 64'd1) begin
                        result_p_next = current_level;
                    end else begin
                        // Edge case: empty set? Result 0.
                        result_p_next = 32'd0;
                    end
                    next_state = FINISH;
                end
            end

            FINISH: begin
                done_next = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase

        // Logic correction for IDLE transition to FINAL_PROP
        if (state == IDLE) begin
            if (!in_valid && carry > 64'd0 && start == 1'b0) begin
                // We have pending carry and no new input
                next_state = FINAL_PROP;
            end
        end
    end

endmodule