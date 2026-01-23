module stack_operations #(
    parameter MAX_OPS = 16,
    parameter MAX_STACK_SIZE = 8,
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 4
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] op_type,
    input wire [ADDR_WIDTH-1:0] v,
    input wire [ADDR_WIDTH-1:0] w,
    output reg [15:0] result,
    output reg done
);

    reg [DATA_WIDTH-1:0] stacks [0:MAX_OPS-1][0:MAX_STACK_SIZE-1];
    reg [2:0] stack_len [0:MAX_OPS-1];
    reg [ADDR_WIDTH-1:0] op_counter;
    reg [ADDR_WIDTH-1:0] current_idx;
    
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] EXECUTE = 3'd1;
    localparam [2:0] TYPE_C_CALC = 3'd2;
    localparam [2:0] DONE = 3'd3;
    reg [2:0] state;
    
    reg [2:0] c_i;
    reg [3:0] c_count;
    reg c_match_found;
    
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

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            op_counter <= 0;
            current_idx <= 0;
            done <= 0;
            result <= 0;
            c_i <= 0;
            c_count <= 0;
            c_match_found <= 0;
            for (integer i = 0; i < MAX_OPS; i = i + 1) begin
                stack_len[i] <= 0;
            end
        end else begin
            done <= 0;
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= EXECUTE;
                    end
                end
                
                EXECUTE: begin
                    case (op_type)
                        2'b00: begin
                            if (current_idx < MAX_OPS) begin
                                stack_len[current_idx] <= stack_len[v] + 1;
                                for (integer i = 0; i < MAX_STACK_SIZE; i = i + 1) begin
                                    if (i < stack_len[v]) begin
                                        stacks[current_idx][i] <= stacks[v][i];
                                    end
                                end
                                if (stack_len[v] < MAX_STACK_SIZE) begin
                                    stacks[current_idx][stack_len[v]] <= op_counter;
                                end
                                op_counter <= op_counter + 1;
                                current_idx <= current_idx + 1;
                            end
                            state <= DONE;
                        end
                        
                        2'b01: begin
                            if (current_idx < MAX_OPS && stack_len[v] > 0) begin
                                stack_len[current_idx] <= stack_len[v] - 1;
                                for (integer i = 0; i < MAX_STACK_SIZE; i = i + 1) begin
                                    if (i < stack_len[v] - 1) begin
                                        stacks[current_idx][i] <= stacks[v][i];
                                    end
                                end
                                result <= stacks[v][stack_len[v] - 1];
                                op_counter <= op_counter + 1;
                                current_idx <= current_idx + 1;
                            end
                            state <= DONE;
                        end
                        
                        2'b10: begin
                            c_i <= 0;
                            c_count <= 0;
                            c_match_found <= 0;
                            state <= TYPE_C_CALC;
                        end
                        
                        default: begin
                            state <= DONE;
                        end
                    endcase
                end
                
                TYPE_C_CALC: begin
                    if (c_i < stack_len[v]) begin
                        if (exists_in_w && !c_match_found) begin
                            c_count <= c_count + 1;
                            c_match_found <= 1;
                        end
                        c_i <= c_i + 1;
                        if (c_i + 1 < stack_len[v]) begin
                            c_match_found <= 0;
                        end
                    end else begin
                        result <= c_count;
                        op_counter <= op_counter + 1;
                        current_idx <= current_idx + 1;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule