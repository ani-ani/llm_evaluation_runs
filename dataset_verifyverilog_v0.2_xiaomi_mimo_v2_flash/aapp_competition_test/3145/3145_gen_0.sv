module multiples_counter (
    input clk,
    input rst_n,
    input start,
    input [7:0] X,
    input [7:0] A,
    input [13:0] B,
    input [9:0] allowed,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam IDLE      = 3'b000;
    localparam INIT      = 3'b001;
    localparam CHECK     = 3'b010;
    localparam CHECK_DIGITS = 3'b011;
    localparam INCREMENT = 3'b100;
    localparam COMPLETE  = 3'b101;

    reg [2:0] current_state, next_state;
    reg [13:0] current_num;
    reg [13:0] temp_num;
    reg [15:0] result_reg;
    reg [13:0] next_num;
    reg [15:0] next_result;
    reg valid_digits;
    reg [3:0] digit;

    // Sequential Logic for State and Registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            current_num <= 14'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            current_state <= next_state;
            
            // Update registers based on state logic
            if (current_state == INIT) begin
                current_num <= {6'b0, A};
                result <= 16'd0;
            end else if (current_state == CHECK) begin
                // Wait state for combinational logic to settle or check divisibility
            end else if (current_state == CHECK_DIGITS) begin
                // Update temp_num and check validity
                // This state handles the digit extraction loop if implemented sequentially
                // However, based on the instructions, we can implement digit check as a combinational block
                // triggered by the CHECK state. To ensure robustness and clear FSM, let's use a sub-state
                // or calculate it combinationally. Given the prompt asks for sub-process or auxiliary state:
                // We will handle the digit check logic combinationally in the CHECK state transition.
                // The CHECK_DIGITS state will be used to latch the result update if we needed multiple cycles,
                // but for this implementation, we will do the digit check in one cycle using combinational logic
                // inside the CHECK state or a dedicated combinational block.
                // To strictly follow "Use combinational logic for digit checking", we do it in the next_state logic.
            end else if (current_state == INCREMENT) begin
                current_num <= next_num;
                result <= next_result;
            end else if (current_state == COMPLETE) begin
                done <= 1'b1;
            end else if (current_state == IDLE && start) begin
                done <= 1'b0; // Clear done when starting new operation
            end
        end
    end

    // Combinational Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start) next_state = INIT;
                else next_state = IDLE;
            end
            INIT: begin
                next_state = CHECK;
            end
            CHECK: begin
                if (current_num > B) begin
                    next_state = COMPLETE;
                end else begin
                    // Check divisibility
                    if (current_num % X != 0) begin
                        next_state = INCREMENT;
                    end else begin
                        // Check digits (combinational logic)
                        // We compute valid_digits combinationally here
                        // To avoid combinatorial loop if logic is complex, we split or assume FPGA logic allows it.
                        // Given the max number is 16384 (5 digits), the loop is very short.
                        
                        // Combinational digit check
                        temp_num = current_num;
                        valid_digits = 1'b1;
                        if (temp_num == 0) valid_digits = 1'b1; // 0 is valid if allowed[0] is set, but logic handles it
                        
                        while (temp_num > 0) begin
                            digit = temp_num % 10;
                            if (!allowed[digit]) valid_digits = 1'b0;
                            temp_num = temp_num / 10;
                        end

                        if (valid_digits) begin
                            // Result increment happens in INCREMENT state or here. 
                            // Let's prepare next_result in CHECK state to transition to INCREMENT cleanly.
                            next_result = result + 1;
                        end else begin
                            next_result = result;
                        end
                        
                        next_state = INCREMENT;
                    end
                end
            end
            INCREMENT: begin
                next_state = CHECK;
                next_num = current_num + 1;
            end
            COMPLETE: begin
                next_state = COMPLETE;\            end
            default: next_state = IDLE;
        endcase
    end

endmodule