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
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPARE = 3'd1;
    localparam [2:0] OUTPUT_A = 3'd2;
    localparam [2:0] OUTPUT_B = 3'd3;
    localparam [2:0] DONE = 3'd4;
    
    // Combinational comparison result
    wire a_smaller;
    
    // Comparator: returns 1 if sequence A (from ptr_a) is lexicographically smaller than B
    assign a_smaller = compare_sequences();
    
    function automatic logic compare_sequences;
        logic [7:0] val_a, val_b;
    begin
        // Default: A is smaller (tie-breaker)
        compare_sequences = 1'b1;
        
        // Handle empty sequences
        if (ptr_a >= len_a && ptr_b >= len_b) begin
            compare_sequences = 1'b1;
        end
        else if (ptr_a >= len_a) begin
            compare_sequences = 1'b1;  // A empty
        end
        else if (ptr_b >= len_b) begin
            compare_sequences = 1'b0;  // B empty
        end
        else begin
            // Get current values
            case (ptr_a)
                0: val_a = a0;
                1: val_a = a1;
                2: val_a = a2;
                3: val_a = a3;
                default: val_a = 8'hXX;
            endcase
            
            case (ptr_b)
                0: val_b = b0;
                1: val_b = b1;
                2: val_b = b2;
                3: val_b = b3;
                default: val_b = 8'hXX;
            endcase
            
            // Compare current element
            if (val_a < val_b) begin
                compare_sequences = 1'b1;
            end
            else if (val_a > val_b) begin
                compare_sequences = 1'b0;
            end
            else begin
                // Look ahead: position 1
                if (ptr_a + 1 < len_a && ptr_b + 1 < len_b) begin
                    logic [7:0] next_a, next_b;
                    case (ptr_a + 1)
                        0: next_a = a0;
                        1: next_a = a1;
                        2: next_a = a2;
                        3: next_a = a3;
                    endcase
                    case (ptr_b + 1)
                        0: next_b = b0;
                        1: next_b = b1;
                        2: next_b = b2;
                        3: next_b = b3;
                    endcase
                    
                    if (next_a < next_b) compare_sequences = 1'b1;
                    else if (next_a > next_b) compare_sequences = 1'b0;
                    else begin
                        // Look ahead: position 2
                        if (ptr_a + 2 < len_a && ptr_b + 2 < len_b) begin
                            logic [7:0] next_a2, next_b2;
                            case (ptr_a + 2)
                                0: next_a2 = a0;
                                1: next_a2 = a1;
                                2: next_a2 = a2;
                                3: next_a2 = a3;
                            endcase
                            case (ptr_b + 2)
                                0: next_b2 = b0;
                                1: next_b2 = b1;
                                2: next_b2 = b2;
                                3: next_b2 = b3;
                            endcase
                            
                            if (next_a2 < next_b2) compare_sequences = 1'b1;
                            else if (next_a2 > next_b2) compare_sequences = 1'b0;
                            else begin
                                // Look ahead: position 3
                                if (ptr_a + 3 < len_a && ptr_b + 3 < len_b) begin
                                    logic [7:0] next_a3, next_b3;
                                    case (ptr_a + 3)
                                        0: next_a3 = a0;
                                        1: next_a3 = a1;
                                        2: next_a3 = a2;
                                        3: next_a3 = a3;
                                    endcase
                                    case (ptr_b + 3)
                                        0: next_b3 = b0;
                                        1: next_b3 = b1;
                                        2: next_b3 = b2;
                                        3: next_b3 = b3;
                                    endcase
                                    
                                    if (next_a3 < next_b3) compare_sequences = 1'b1;
                                    else if (next_a3 > next_b3) compare_sequences = 1'b0;
                                    else begin
                                        // All equal, compare remaining lengths
                                        compare_sequences = (len_a - ptr_a) < (len_b - ptr_b);
                                    end
                                end
                                else begin
                                    compare_sequences = (len_a - ptr_a) < (len_b - ptr_b);
                                end
                            end
                        end
                        else begin
                            compare_sequences = (len_a - ptr_a) < (len_b - ptr_b);
                        end
                    end
                end
                else begin
                    compare_sequences = (len_a - ptr_a) < (len_b - ptr_b);
                end
            end
        end
    end
    endfunction
    
    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            ptr_a <= 3'b0;
            ptr_b <= 3'b0;
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
                        state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    result_valid <= 1'b0;
                    if (ptr_a >= len_a && ptr_b >= len_b) begin
                        state <= DONE;
                    end
                    else if (ptr_a >= len_a) begin
                        state <= OUTPUT_B;
                    end
                    else if (ptr_b >= len_b) begin
                        state <= OUTPUT_A;
                    end
                    else begin
                        if (a_smaller) begin
                            state <= OUTPUT_A;
                        end
                        else begin
                            state <= OUTPUT_B;
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