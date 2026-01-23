module combinations_generator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] n,
    input wire [1:0] symbols [0:2],
    output reg [5:0] tuple_out,
    output reg tuple_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] GEN  = 3'd1;
    localparam [2:0] NEXT = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Combination storage (max 3 elements)
    reg [1:0] indices [0:2];  // Current combination indices
    reg [1:0] next_indices [0:2];
    reg [3:0] count;          // Combination counter
    reg [3:0] max_count;      // Total combinations based on n
    
    integer i, j;
    
    // FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tuple_out <= 6'd0;
            tuple_valid <= 1'b0;
            done <= 1'b0;
            count <= 4'd0;
            max_count <= 4'd0;
            for (i = 0; i < 3; i = i + 1) begin
                indices[i] <= 2'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    tuple_valid <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        // Initialize indices
                        for (i = 0; i < 3; i = i + 1) begin
                            indices[i] <= 2'd0;
                        end
                        
                        // Set max count based on n
                        case (n)
                            2'd1: max_count <= 4'd3;
                            2'd2: max_count <= 4'd6;
                            2'd3: max_count <= 4'd10;
                            default: max_count <= 4'd0;
                        endcase
                        
                        count <= 4'd1;
                        next_state <= GEN;
                    end
                end
                
                GEN: begin
                    // Map indices to symbols and pack
                    case (n)
                        2'd1: tuple_out <= {4'd0, symbols[indices[0]]};
                        2'd2: tuple_out <= {2'd0, symbols[indices[1]], symbols[indices[0]]};
                        2'd3: tuple_out <= {symbols[indices[2]], symbols[indices[1]], symbols[indices[0]]};
                        default: tuple_out <= 6'd0;
                    endcase
                    
                    tuple_valid <= 1'b1;
                    next_state <= NEXT;
                end
                
                NEXT: begin
                    tuple_valid <= 1'b0;
                    
                    // Calculate next combination
                    if (count == max_count) begin
                        next_state <= DONE_STATE;
                    end else begin
                        // Update indices for next combination
                        for (i = 0; i < 3; i = i + 1) begin
                            indices[i] <= next_indices[i];
                        end
                        
                        count <= count + 4'd1;
                        next_state <= GEN;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
    
    // Combinational logic for next indices
    always @(*) begin
        for (i = 0; i < 3; i = i + 1) begin
            next_indices[i] = indices[i];
        end
        
        if (state == NEXT && count != max_count) begin
            // Find rightmost index that can be incremented
            reg found;
            found = 1'b0;
            for (j = n-1; j >= 0; j = j - 1) begin
                if (!found && indices[j] < 2'd2) begin
                    next_indices[j] = indices[j] + 2'd1;
                    found = 1'b1;
                end 
                else if (found) begin
                    next_indices[j] = next_indices[j+1];
                end
            end
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? GEN : IDLE;
            GEN: next_state = NEXT;
            NEXT: next_state = (count == max_count) ? DONE_STATE : GEN;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
endmodule
