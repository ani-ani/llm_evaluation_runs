module string_explosion #(
    parameter MAX_STR_LEN = 8,
    parameter MAX_EXP_LEN = 4
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_str [0:MAX_STR_LEN-1],
    input wire [3:0] input_len,
    input wire [7:0] explosion_str [0:MAX_EXP_LEN-1],
    input wire [2:0] explosion_len,
    output reg [7:0] result_str [0:MAX_STR_LEN-1],
    output reg [3:0] result_len,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] input_idx;           // Current character index being processed
    reg [3:0] sp;                  // Stack pointer (points to next free position)
    reg [MAX_STR_LEN*8-1:0] stack; // Packed stack: stack[7:0] = element 0, stack[15:8] = element 1, etc.
    reg [3:0] cycle_count;         // Prevent infinite loops
    localparam [3:0] MAX_CYCLES = 4'd12; // Max input_len + some overhead

    // Combinational signals for explosion check
    wire [7:0] stack_element [0:MAX_STR_LEN-1];
    wire match_flag;
    wire [MAX_STR_LEN*8-1:0] match_mask;

    // Unpack stack for comparison (combinational)
    genvar g;
    generate
        for (g = 0; g < MAX_STR_LEN; g = g + 1) begin : unpack_stack
            assign stack_element[g] = stack[g*8 +: 8];
        end
    endgenerate

    // Combinational explosion match logic
    // Check if top explosion_len characters match explosion_str
    assign match_flag = (
        (sp >= explosion_len) &&
        ((explosion_len >= 1 && stack_element[sp-1] == explosion_str[0]) || (explosion_len < 1)) &&
        ((explosion_len >= 2 && stack_element[sp-2] == explosion_str[1]) || (explosion_len < 2)) &&
        ((explosion_len >= 3 && stack_element[sp-3] == explosion_str[2]) || (explosion_len < 3)) &&
        ((explosion_len >= 4 && stack_element[sp-4] == explosion_str[3]) || (explosion_len < 4))
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            input_idx <= 4'd0;
            sp <= 4'd0;
            stack <= {MAX_STR_LEN{8'd0}};
            cycle_count <= 4'd0;
            result_len <= 4'd0;
            done <= 1'b0;
            // Initialize result_str array
            for (int i = 0; i < MAX_STR_LEN; i = i + 1) begin
                result_str[i] <= 8'd0;
            end
        end else begin
            // Default values
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    // Clear internal state when idle
                    input_idx <= 4'd0;
                    sp <= 4'd0;
                    stack <= {MAX_STR_LEN{8'd0}};
                    cycle_count <= 4'd0;
                    result_len <= 4'd0;
                    
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check if we've processed all characters or exceeded max cycles
                    if (input_idx >= input_len || cycle_count >= MAX_CYCLES) begin
                        // Done processing, copy to output
                        for (int i = 0; i < MAX_STR_LEN; i = i + 1) begin
                            if (i < sp) begin
                                result_str[i] <= stack_element[i];
                            end else begin
                                result_str[i] <= 8'd0;
                            end
                        end
                        result_len <= sp;
                        state <= DONE_STATE;
                    end else begin
                        // Push character onto stack
                        if (sp < MAX_STR_LEN) begin
                            // Insert new character at position sp
                            // We need to shift the packed register
                            stack <= {stack[MAX_STR_LEN*8-1:8], input_str[input_idx]};
                            sp <= sp + 4'd1;
                        end
                        
                        // Increment input index for next cycle
                        input_idx <= input_idx + 4'd1;
                        
                        // Note: Explosion check happens in combinational logic
                        // and removal will happen in the next cycle if needed.
                        // However, to handle multiple explosions in sequence,
                        // we need a separate state or logic. For simplicity,
                        // we'll handle removal in PROCESS state by checking
                        // the match_flag from previous push.
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Additional combinational logic to handle explosion removal
    // This needs to override the PROCESS state logic for proper sequential removal
    // Re-writing the always block to handle sequential removal properly
    
    // Revised sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_idx <= 4'd0;
            sp <= 4'd0;
            stack <= {MAX_STR_LEN{8'd0}};
            cycle_count <= 4'd0;
            result_len <= 4'd0;
            done <= 1'b0;
            for (int i = 0; i < MAX_STR_LEN; i = i + 1) begin
                result_str[i] <= 8'd0;
            end
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    input_idx <= 4'd0;
                    sp <= 4'd0;
                    stack <= {MAX_STR_LEN{8'd0}};
                    cycle_count <= 4'd0;
                    result_len <= 4'd0;
                    
                    if (start) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check if explosion occurred on previous push
                    if (match_flag && sp >= explosion_len && explosion_len > 0) begin
                        // Remove explosion from stack
                        sp <= sp - explosion_len;
                        // Stack contents shift automatically as we only use sp to index
                    end else if (input_idx < input_len && cycle_count < MAX_CYCLES && sp < MAX_STR_LEN) begin
                        // Push current character
                        stack <= {stack[MAX_STR_LEN*8-1:8], input_str[input_idx]};
                        sp <= sp + 4'd1;
                        input_idx <= input_idx + 4'd1;
                    end else begin
                        // Either done with input or stack full or max cycles reached
                        // But need to check for final explosion one more time
                        if (match_flag && sp >= explosion_len && explosion_len > 0) begin
                            sp <= sp - explosion_len;
                        end else if (input_idx >= input_len) begin
                            // All done, copy to output
                            for (int i = 0; i < MAX_STR_LEN; i = i + 1) begin
                                if (i < sp) begin
                                    result_str[i] <= stack_element[i];
                                end else begin
                                    result_str[i] <= 8'd0;
                                end
                            end
                            result_len <= sp;
                            state <= DONE_STATE;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule