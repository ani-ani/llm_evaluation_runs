module FlattenList (
    input clk,
    input rst_n,
    input start,
    input [3:0] list_0 [0:3],
    input [3:0] list_1 [0:3],
    input [3:0] list_2 [0:3],
    input [2:0] list_0_valid,
    input [2:0] list_1_valid,
    input [2:0] list_2_valid,
    output reg [3:0] result [0:7],
    output reg [3:0] result_count,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD_LIST  = 3'd1;
    localparam [2:0] CHECK_ELEM = 3'd2;
    localparam [2:0] ADD_ELEM   = 3'd3;
    localparam [2:0] NEXT_ELEM  = 3'd4;
    localparam [2:0] NEXT_LIST  = 3'd5;
    localparam [2:0] FINISH     = 3'd6;

    reg [2:0] state, next_state;
    
    // Tracking counters and indices
    reg [1:0] list_idx;  // 0, 1, 2
    reg [1:0] elem_idx;  // 0, 1, 2, 3 within list
    reg [2:0] result_idx; // 0-7 in result array
    reg [3:0] current_elem;  // Element being processed
    reg [3:0] valid_limit;  // Max elements in current list
    reg [3:0] valid_count;  // Current element count
    
    // Lookup table for seen elements (8 entries, 4-bit each)
    reg [3:0] seen_table [0:7];
    reg [2:0] seen_idx;  // Index in seen table
    reg found;  // Flag for element found in seen table
    reg [3:0] i;  // Loop variable
    reg [3:0] max_elem;  // Maximum elements in result
    
    // FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_count <= 4'd0;
            list_idx <= 2'd0;
            elem_idx <= 2'd0;
            result_idx <= 3'd0;
            current_elem <= 4'd0;
            valid_limit <= 4'd0;
            valid_count <= 4'd0;
            seen_idx <= 3'd0;
            found <= 1'b0;
            // Initialize seen table
            for (i = 0; i < 8; i = i + 1) begin
                seen_table[i] <= 4'd0;
            end
            // Initialize result array
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                    list_idx <= 2'd0;
                    elem_idx <= 2'd0;
                    result_idx <= 3'd0;
                    result_count <= 4'd0;
                    valid_count <= 4'd0;
                    // Clear seen table (optional, but good practice)
                    for (i = 0; i < 8; i = i + 1) begin
                        seen_table[i] <= 4'd0;
                    end
                    // Clear result array
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i] <= 4'd0;
                    end
                end
                
                LOAD_LIST: begin
                    // Determine which list to process and its valid limit
                    case (list_idx)
                        2'd0: begin
                            current_elem <= list_0[elem_idx];
                            valid_limit <= {1'b0, list_0_valid};
                        end
                        2'd1: begin
                            current_elem <= list_1[elem_idx];
                            valid_limit <= {1'b0, list_1_valid};
                        end
                        2'd2: begin
                            current_elem <= list_2[elem_idx];
                            valid_limit <= {1'b0, list_2_valid};
                        end
                        default: begin
                            current_elem <= 4'd0;
                            valid_limit <= 4'd0;
                        end
                    endcase
                end
                
                CHECK_ELEM: begin
                    // Check if current_elem is in seen_table
                    found <= 1'b0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (seen_table[i] == current_elem) begin
                            found <= 1'b1;
                        end
                    end
                end
                
                ADD_ELEM: begin
                    // Add to seen_table
                    if (result_count < 8) begin
                        seen_table[result_idx] <= current_elem;
                        result[result_idx] <= current_elem;
                        result_idx <= result_idx + 3'd1;
                        result_count <= result_count + 4'd1;
                    end
                end
                
                NEXT_ELEM: begin
                    elem_idx <= elem_idx + 2'd1;
                end
                
                NEXT_LIST: begin
                    list_idx <= list_idx + 2'd1;
                    elem_idx <= 2'd0;
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_LIST;
                end
            end
            
            LOAD_LIST: begin
                // Check if we need to process this list
                if (list_idx < 3 && valid_limit > 0 && elem_idx < valid_limit) begin
                    next_state = CHECK_ELEM;
                end else if (list_idx < 3 && (valid_limit == 0 || elem_idx >= valid_limit)) begin
                    // Move to next list or finish
                    if (list_idx == 3'd2) begin
                        next_state = FINISH;
                    end else begin
                        next_state = NEXT_LIST;
                    end
                end else if (list_idx >= 3) begin
                    next_state = FINISH;
                end
            end
            
            CHECK_ELEM: begin
                // After checking, add if not found and not duplicate
                if (!found && result_count < 8) begin
                    next_state = ADD_ELEM;
                end else begin
                    next_state = NEXT_ELEM;
                end
            end
            
            ADD_ELEM: begin
                next_state = NEXT_ELEM;
            end
            
            NEXT_ELEM: begin
                if (elem_idx >= valid_limit || elem_idx >= 4) begin
                    // Move to next list or finish
                    if (list_idx == 3'd2) begin
                        next_state = FINISH;
                    end else begin
                        next_state = NEXT_LIST;
                    end
                end else begin
                    next_state = LOAD_LIST;
                end
            end
            
            NEXT_LIST: begin
                // Determine next list's limit
                next_state = LOAD_LIST;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule