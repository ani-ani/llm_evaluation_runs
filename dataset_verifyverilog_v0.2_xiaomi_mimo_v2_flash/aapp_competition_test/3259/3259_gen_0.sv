module aladin_box_sim (
    input clk,
    input rst_n,
    input start,
    input [2:0] op_type,
    input [2:0] L,
    input [2:0] R,
    input [7:0] A,
    input [7:0] B,
    output reg [7:0] result,
    output reg done
);

    // Internal registers for 8 boxes
    reg [7:0] boxes [0:7];
    
    // State definitions
    localparam IDLE = 3'b000;
    localparam CALCULATE = 3'b001;
    localparam MODULO = 3'b010;
    localparam STORE_SUM = 3'b011;
    localparam INCREMENT = 3'b100;
    localparam DONE = 3'b101;
    
    // Current state and next state
    reg [2:0] current_state;
    reg [2:0] next_state;
    
    // Datapath registers
    reg [2:0] current_idx; // Current index from L to R
    reg [15:0] temp_mult;  // Holds (i - L + 1) * A
    reg [15:0] temp_val;   // Holds value for modulo operation
    reg [7:0]  temp_sum;   // Holds accumulated sum
    reg [7:0]  multiplier; // (i - L + 1)
    
    // Control signals
    reg rst_idx;
    reg inc_idx;
    reg load_mult;
    reg dec_mod;
    reg store_box;
    reg add_sum;
    reg res_done;
    reg res_clear;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = CALCULATE;
                else
                    next_state = IDLE;
            end
            
            CALCULATE: begin
                // We need one cycle for 16-bit multiplication
                next_state = (B == 8'd0) ? DONE : MODULO; // Handle B=0 case if necessary, though assumed valid
                // If B is 0, modulo is undefined, assume B > 0. If B=1, modulo is always 0.
            end
            
            MODULO: begin
                // Subtraction loop for modulo: if val >= B, subtract B
                if (temp_val[15:8] != 0 || temp_val[7:0] >= B) begin
                    next_state = MODULO;
                end else begin
                    if (op_type == 3'b000) // Update
                        next_state = STORE_SUM;
                    else // Query
                        next_state = STORE_SUM; // Reuse logic for add
                end
            end
            
            STORE_SUM: begin
                // One cycle to write to array or add to sum
                next_state = INCREMENT;
            end
            
            INCREMENT: begin
                if (current_idx == R)
                    next_state = DONE;
                else
                    next_state = CALCULATE;
            end
            
            DONE: begin
                if (start) // Wait for start to go low to avoid re-triggering
                    next_state = DONE;
                else
                    next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Output and Datapath logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            for (i = 0; i < 8; i = i + 1) begin
                boxes[i] <= 8'b0;
            end
            result <= 8'b0;
            done <= 1'b0;
            current_idx <= 3'b0;
            temp_mult <= 16'b0;
            temp_val <= 16'b0;
            temp_sum <= 8'b0;
            multiplier <= 8'b0;
        end else begin
            // Default control signals behavior (de-assert)
            rst_idx <= 1'b0;
            inc_idx <= 1'b0;
            load_mult <= 1'b0;
            dec_mod <= 1'b0;
            store_box <= 1'b0;
            add_sum <= 1'b0;
            res_done <= 1'b0;
            res_clear <= 1'b0;
            
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        current_idx <= L;
                        // Pre-calculate multiplier for first index (i = L -> mult = 1)
                        multiplier <= 8'd1;
                        // Clear result for query
                        if (op_type == 3'b001) begin
                            result <= 8'b0;
                            temp_sum <= 8'b0;
                        end
                    end
                end
                
                CALCULATE: begin
                    // Perform: (multiplier * A) -> 16 bit
                    temp_mult <= multiplier * A;
                    // Prepare multiplier for next cycle
                    // Note: This is pipelined slightly relative to index logic, but safe.
                end
                
                MODULO: begin
                    // Logic: temp_val = temp_mult initially (handled by transition from CALC)
                    // Wait, in state CALC we calculated temp_mult.
                    // We need temp_val to start as temp_mult. 
                    // We can load temp_val in CALC state or here. Let's load in CALC->MODULO transition or first cycle of MODULO.
                    // Actually, let's just use temp_mult directly for subtraction if we are careful, or a dedicated register.
                    // Let's use temp_val as the working register. We need to initialize it before entering MODULO.
                    
                    // Correction: The previous state (CALC) put result in temp_mult.
                    // We need to copy to temp_val if we just entered MODULO.
                    // But we are in a state machine, so we check the previous state or use a flag.
                    // Easier: Modify CALC state to load temp_val.
                    // Let's stick to the current flow: 
                    // CALC does multiplication. 
                    // MODULO does subtraction.
                    // We need to load temp_val once.
                end
            endcase
            
            // Split logic for clarity
            // Handle specific state actions that require sequencing
            if (current_state == CALCULATE) begin
                temp_val <= temp_mult; // Load value for modulo
            end
            
            if (current_state == MODULO) begin
                if (temp_val[15:8] != 0 || temp_val[7:0] >= B) begin
                    // Subtract B from temp_val (16-bit safe)
                    if (temp_val >= B) begin
                        temp_val <= temp_val - B;
                    end else begin
                        // High byte implies value > 255, so subtract B from 16-bit value
                        temp_val <= temp_val - B;
                    end
                end
            end
            
            if (current_state == STORE_SUM) begin
                if (op_type == 3'b000) begin // Update
                    boxes[current_idx] <= temp_val[7:0];
                end else begin // Query
                    // Add current box value to sum
                    result <= result + boxes[current_idx];
                end
                
                // Increment multiplier for next index
                if (current_idx < R) begin
                    multiplier <= multiplier + 8'd1;
                end
            end
            
            if (current_state == INCREMENT) begin
                if (current_idx < R)
                    current_idx <= current_idx + 3'd1;
            end
            
            if (current_state == DONE) begin
                done <= 1'b1;
            end
            
            // Handle modulo loop carefully: 
            // The constraint says "optimize" if possible. 
            // The state MODULO loops until temp_val < B.
            // The state machine transition handles this loop.
        end
    end
    
    // Output assignment
    // result is updated continuously in the always block
    // done is updated in the always block

endmodule

// Note: The above state machine implements the control flow.
// To ensure the modulo loop works correctly within the state machine:
// The transition condition for MODULO relies on the updated temp_val.
// 
// Revision for robustness:
// The B input is 8-bit. temp_val is 16-bit.
// Subtraction: temp_val = temp_val - B.
// This is correct logic for unsigned modulo.
// 
// Constraint Check:
// "Assume all inputs are of type reg unless otherwise specified." - Input ports are inputs, cannot be reg in port list. The "assign" to internal signals handles this if needed, but standard practice is using wire for inputs. I will follow standard Verilog (wire for inputs).
// "Do not assume a clock signal unless it is explicitly given." - clk is given.

endmodule