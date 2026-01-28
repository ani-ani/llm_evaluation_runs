module solitaire_merger (
    input clk,
    input rst_n,
    input start,
    
    // Sequence A (max 4 elements, 8-bit values)
    input [7:0] a0, a1, a2, a3,
    input [2:0] len_a,
    
    // Sequence B (max 4 elements, 8-bit values)
    input [7:0] b0, b1, b2, b3,
    input [2:0] len_b,
    
    output reg [7:0] result,
    output reg result_valid,
    output reg done
);

    // Internal state
    reg [2:0] state;
    reg [2:0] ptr_a, ptr_b;
    reg [2:0] compare_count;
    reg [2:0] a_smaller_reg;
    reg [2:0] ptr_a_temp, ptr_b_temp;
    reg [7:0] val_a_reg, val_b_reg;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPARE = 3'd1;
    localparam [2:0] COMPARE_CONTINUE = 3'd2;
    localparam [2:0] OUTPUT_A = 3'd3;
    localparam [2:0] OUTPUT_B = 3'd4;
    localparam [2:0] DONE = 3'd5;
    
    // Get value functions
    function automatic [7:0] get_a_val;
        input [2:0] idx;
    begin
        case (idx)
            0: get_a_val = a0;
            1: get_a_val = a1;
            2: get_a_val = a2;
            3: get_a_val = a3;
            default: get_a_val = 8'd0;
        endcase
    end
    endfunction
    
    function automatic [7:0] get_b_val;
        input [2:0] idx;
    begin
        case (idx)
            0: get_b_val = b0;
            1: get_b_val = b1;
            2: get_b_val = b2;
            3: get_b_val = b3;
            default: get_b_val = 8'd0;
        endcase
    end
    endfunction
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ptr_a <= 3'b0;
            ptr_b <= 3'b0;
            ptr_a_temp <= 3'b0;
            ptr_b_temp <= 3'b0;
            compare_count <= 3'b0;
            a_smaller_reg <= 1'b0;
            val_a_reg <= 8'b0;
            val_b_reg <= 8'b0;
            result <= 8'b0;
            result_valid <= 1'b0;
            done <= 1'b0;
        end
        else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        ptr_a <= 3'b0;
                        ptr_b <= 3'b0;
                        ptr_a_temp <= 3'b0;
                        ptr_b_temp <= 3'b0;
                        compare_count <= 3'b0;
                        state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    
                    // Check if sequences are exhausted
                    if (ptr_a >= len_a && ptr_b >= len_b) begin
                        state <= DONE;
                    end
                    else if (ptr_a >= len_a) begin
                        // A is exhausted, output B
                        state <= OUTPUT_B;
                    end
                    else if (ptr_b >= len_b) begin
                        // B is exhausted, output A
                        state <= OUTPUT_A;
                    end
                    else begin
                        // Both have elements, start comparison
                        ptr_a_temp <= ptr_a;
                        ptr_b_temp <= ptr_b;
                        val_a_reg <= get_a_val(ptr_a);
                        val_b_reg <= get_b_val(ptr_b);
                        compare_count <= 3'd1;
                        state <= COMPARE_CONTINUE;
                    end
                end
                
                COMPARE_CONTINUE: begin
                    // Compare current values
                    if (val_a_reg < val_b_reg) begin
                        a_smaller_reg <= 1'b1;
                        state <= OUTPUT_A;
                    end
                    else if (val_a_reg > val_b_reg) begin
                        a_smaller_reg <= 1'b0;
                        state <= OUTPUT_B;
                    end
                    else begin
                        // Values are equal, check if we need to look ahead
                        if (compare_count >= 3'd4) begin
                            // Max lookahead reached, compare lengths
                            if ((len_a - ptr_a_temp) < (len_b - ptr_b_temp)) begin
                                state <= OUTPUT_A;
                            end
                            else begin
                                state <= OUTPUT_B;
                            end
                        end
                        else begin
                            // Continue lookahead
                            ptr_a_temp <= ptr_a_temp + 1;
                            ptr_b_temp <= ptr_b_temp + 1;
                            compare_count <= compare_count + 1;
                            
                            // Check if we can look ahead further
                            if (ptr_a_temp + 1 >= len_a && ptr_b_temp + 1 >= len_b) begin
                                // Both will be exhausted after this
                                if ((len_a - ptr_a_temp) < (len_b - ptr_b_temp)) begin
                                    state <= OUTPUT_A;
                                end
                                else begin
                                    state <= OUTPUT_B;
                                end
                            end
                            else if (ptr_a_temp + 1 >= len_a) begin
                                // A will be exhausted
                                state <= OUTPUT_B;
                            end
                            else if (ptr_b_temp + 1 >= len_b) begin
                                // B will be exhausted
                                state <= OUTPUT_A;
                            end
                            else begin
                                // Get next values
                                val_a_reg <= get_a_val(ptr_a_temp + 1);
                                val_b_reg <= get_b_val(ptr_b_temp + 1);
                                state <= COMPARE_CONTINUE;
                            end
                        end
                    end
                end
                
                OUTPUT_A: begin
                    case (ptr_a)
                        0: result <= a0;
                        1: result <= a1;
                        2: result <= a2;
                        3: result <= a3;
                    endcase
                    result_valid <= 1'b1;
                    ptr_a <= ptr_a + 1;
                    state <= COMPARE;
                end
                
                OUTPUT_B: begin
                    case (ptr_b)
                        0: result <= b0;
                        1: result <= b1;
                        2: result <= b2;
                        3: result <= b3;
                    endcase
                    result_valid <= 1'b1;
                    ptr_b <= ptr_b + 1;
                    state <= COMPARE;
                end
                
                DONE: begin
                    result_valid <= 1'b0;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule