module combinations_generator(
    input clk,
    input rst_n,
    input start,
    input [1:0] n,
    input [1:0] symbols [0:2],
    output reg [5:0] tuple_out,
    output reg tuple_valid,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] GEN = 2'd1;
    localparam [1:0] NEXT = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state;
    reg [5:0] indices;  // Packed: indices[5:4] for pos2, [3:2] for pos1, [1:0] for pos0
    reg [1:0] pos;  // Current position being incremented
    reg [5:0] count;  // Total combinations generated
    reg [5:0] max_count;  // Total combinations for given n
    reg [5:0] next_max_count;  // Combinational next for max_count
    reg [5:0] next_count;  // Combinational next for count
    reg [5:0] next_indices;  // Combinational next for indices
    reg [1:0] tuple_valid_next;  // Combinational next for tuple_valid
    reg done_next;  // Combinational next for done

    // Decode n to max_count: C(3+n-1, n)
    // n=1: C(3,1)=3
    // n=2: C(4,2)=6
    // n=3: C(5,3)=10
    always @(*) begin
        case (n)
            2'd1: next_max_count = 6'd3;
            2'd2: next_max_count = 6'd6;
            2'd3: next_max_count = 6'd10;
            default: next_max_count = 6'd0;
        endcase
    end

    // Combinational logic for next state and outputs
    always @(*) begin
        // Defaults
        next_count = count;
        next_indices = indices;
        tuple_valid_next = 1'b0;
        done_next = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_count = 6'd0;
                    next_indices = 6'd0;  // All indices start at 0
                    tuple_valid_next = 1'b1;  // Output first tuple
                end
            end
            
            GEN: begin
                // Output current tuple (tuple_valid already 1 from NEXT or IDLE)
                if (count == max_count - 6'd1) begin
                    // Last tuple, go to DONE
                end else begin
                    // Need to generate next tuple
                end
            end
            
            NEXT: begin
                // Compute next indices (lexicographic order)
                // Start from rightmost position and increment
                next_indices = indices;
                
                // Check positions from right to left
                if (n == 2'd1) begin
                    // n=1: simple increment
                    next_indices[1:0] = indices[1:0] + 2'd1;
                end else if (n == 2'd2) begin
                    // n=2: [a,b] where a<=b
                    // Try to increment b first
                    if (indices[1:0] < 2'd2) begin
                        next_indices[1:0] = indices[1:0] + 2'd1;
                    end else begin
                        // b at max, increment a and reset b
                        next_indices[1:0] = indices[3:2];
                        next_indices[3:2] = indices[3:2] + 2'd1;
                    end
                end else begin
                    // n=3: [a,b,c] where a<=b<=c
                    // Try to increment c first
                    if (indices[1:0] < 2'd2) begin
                        next_indices[1:0] = indices[1:0] + 2'd1;
                    end else if (indices[3:2] < 2'd2) begin
                        // c at max, try b
                        if (indices[3:2] < 2'd2 && indices[3:2] + 2'd1 <= indices[5:4]) begin
                            next_indices[3:2] = indices[3:2] + 2'd1;
                            next_indices[1:0] = next_indices[3:2];
                        end else begin
                            // b at max or would exceed a, try a
                            if (indices[5:4] < 2'd2) begin
                                next_indices[5:4] = indices[5:4] + 2'd1;
                                next_indices[3:2] = next_indices[5:4];
                                next_indices[1:0] = next_indices[5:4];
                            end else begin
                                // Should not reach here if counting correctly
                                next_indices = 6'd0;
                            end
                        end
                    end else begin
                        // More complex case handling
                        // Simplify: if c=max and b<c, increment b, reset c
                        if (indices[1:0] == 2'd2 && indices[3:2] < 2'd2 && indices[3:2] < indices[5:4]) begin
                            next_indices[3:2] = indices[3:2] + 2'd1;
                            next_indices[1:0] = next_indices[3:2];
                        end else if (indices[3:2] == 2'd2 || indices[3:2] >= indices[5:4]) begin
                            // b at max or at a, try a
                            if (indices[5:4] < 2'd2) begin
                                next_indices[5:4] = indices[5:4] + 2'd1;
                                next_indices[3:2] = next_indices[5:4];
                                next_indices[1:0] = next_indices[5:4];
                            end else begin
                                next_indices = 6'd0;  // Wrap
                            end
                        end
                    end
                end
                
                next_count = count + 6'd1;
            end
            
            DONE_STATE: begin
                done_next = 1'b1;
            end
            
            default: begin
                next_count = 6'd0;
                next_indices = 6'd0;
            end
        endcase
    end

    // Combinational output generation (tuple_out)
    always @(*) begin
        tuple_out = 6'd0;
        
        case (n)
            2'd1: begin
                tuple_out[1:0] = indices[1:0];  // First position
                // Bits 5:2 remain 0
            end
            2'd2: begin
                tuple_out[1:0] = indices[1:0];  // b
                tuple_out[3:2] = indices[3:2];  // a
                // Bits 5:4 remain 0
            end
            2'd3: begin
                tuple_out[1:0] = indices[1:0];  // c
                tuple_out[3:2] = indices[3:2];  // b
                tuple_out[5:4] = indices[5:4];  // a
            end
            default: tuple_out = 6'd0;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            indices <= 6'd0;
            count <= 6'd0;
            max_count <= 6'd0;
            tuple_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            tuple_valid <= tuple_valid_next;
            done <= done_next;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= GEN;
                        count <= next_count;
                        indices <= next_indices;
                        max_count <= next_max_count;
                    end
                end
                
                GEN: begin
                    if (count == max_count - 6'd1) begin
                        state <= DONE_STATE;
                    end else begin
                        state <= NEXT;
                    end
                end
                
                NEXT: begin
                    state <= GEN;
                    count <= next_count;
                    indices <= next_indices;
                end
                
                DONE_STATE: begin
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule