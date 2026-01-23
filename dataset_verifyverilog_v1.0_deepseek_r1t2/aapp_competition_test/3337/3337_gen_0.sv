module stack_operations #(
    parameter MAX_OPS = 16,          // Maximum operations
    parameter MAX_STACK_SIZE = 8,    // Maximum stack depth
    parameter DATA_WIDTH = 8,        // Number width
    parameter ADDR_WIDTH = 4         // Stack address width
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] op_type,       // 00=push, 01=pop, 10=count
    input wire [ADDR_WIDTH-1:0] v,  // First stack operand
    input wire [ADDR_WIDTH-1:0] w,  // Second stack operand (type 10 only)
    output reg [15:0] result,       // Result for pop and count operations
    output reg done                 // Operation complete pulse
);

// Internal memory
reg [DATA_WIDTH-1:0] stacks [0:MAX_OPS-1] [0:MAX_STACK_SIZE-1];
reg [2:0] stack_len [0:MAX_OPS-1];

// Operation tracking
reg [ADDR_WIDTH-1:0] op_counter;
reg [ADDR_WIDTH-1:0] current_idx;

// FSM states
localparam [2:0] IDLE = 3'd0;
localparam [2:0] EXECUTE = 3'd1;
localparam [2:0] TYPE_C_CALC = 3'd2;
localparam [2:0] DONE_STATE = 3'd3;
reg [2:0] state;

// Type C calculation
reg [2:0] c_i;
reg [3:0] c_count;
reg c_match_found;

// Combinational existence check
wire exists_in_w;
assign exists_in_w = (
    (c_i < stack_len[v]) && (
        (stack_len[w] > 0 && stacks[v][c_i] == stacks[w][0]) ||
        (stack_len[w] > 1 && stacks[v][c_i] == stacks[w][1]) ||
        (stack_len[w] > 2 && stacks[v][c_i] == stacks[w][2]) ||
        (stack_len[w] > 3 && stacks[v][c_i] == stacks[w][3]) ||
        (stack_len[w] > 4 && stacks[v][c_i] == stacks[w][4]) ||
        (stack_len[w] > 5 && stacks[v][c_i] == stacks[w][5]) ||
        (stack_len[w] > 6 && stacks[v][c_i] == stacks[w][6]) ||
        (stack_len[w] > 7 && stacks[v][c_i] == stacks[w][7])
    )
);

// FSM implementation
integer i;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Initialize ALL registers
        state <= IDLE;
        op_counter <= 4'd1;
        current_idx <= 4'd1;
        done <= 1'b0;
        result <= 16'd0;
        c_i <= 3'd0;
        c_count <= 4'd0;
        c_match_found <= 1'b0;
        
        // Initialize stack lengths
        for (i = 0; i < MAX_OPS; i = i + 1) begin
            stack_len[i] <= 3'd0;
        end
    end else begin
        done <= 1'b0;  // Clear done signal

        case (state)
            IDLE: begin
                if (start) begin
                    state <= EXECUTE;
                end
            end
            
            EXECUTE: begin
                case (op_type)
                    2'b00: begin  // Type A: Push
                        if (current_idx < MAX_OPS && stack_len[v] < MAX_STACK_SIZE) begin
                            // Copy stack v + push op number
                            stack_len[current_idx] <= stack_len[v] + 3'd1;
                            for (i = 0; i < MAX_STACK_SIZE; i = i + 1) begin
                                if (i < stack_len[v]) begin
                                    stacks[current_idx][i] <= stacks[v][i];
                                end
                            end
                            stacks[current_idx][stack_len[v]] <= op_counter;
                            op_counter <= op_counter + 4'd1;
                            current_idx <= current_idx + 4'd1;
                        end
                        state <= DONE_STATE;
                    end
                    
                    2'b01: begin  // Type B: Pop
                        if (current_idx < MAX_OPS && stack_len[v] > 0) begin
                            // Copy stack v - top element
                            stack_len[current_idx] <= stack_len[v] - 3'd1;
                            for (i = 0; i < MAX_STACK_SIZE; i = i + 1) begin
                                if (i < stack_len[v] - 1) begin
                                    stacks[current_idx][i] <= stacks[v][i];
                                end
                            end
                            result <= stacks[v][stack_len[v] - 3'd1];
                            op_counter <= op_counter + 4'd1;
                            current_idx <= current_idx + 4'd1;
                        end
                        state <= DONE_STATE;
                    end
                    
                    2'b10: begin  // Type C: Count common elements
                        c_i <= 3'd0;
                        c_count <= 4'd0;
                        c_match_found <= 1'b0;
                        state <= TYPE_C_CALC;
                    end
                    
                    default: state <= DONE_STATE;
                endcase
            end
            
            TYPE_C_CALC: begin
                if (c_i < stack_len[v]) begin
                    if (exists_in_w && !c_match_found) begin
                        c_count <= c_count + 4'd1;
                        c_match_found <= 1'b1;
                    end
                    
                    if (c_i + 3'd1 < stack_len[v]) begin
                        c_i <= c_i + 3'd1;
                        c_match_found <= 1'b0;
                    end else begin
                        state <= DONE_STATE;
                        result <= c_count;
                        op_counter <= op_counter + 4'd1;
                        current_idx <= current_idx + 4'd1;
                    end
                end else begin
                    state <= DONE_STATE;
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