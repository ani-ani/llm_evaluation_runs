module NenScriptProcessor #(
    parameter NUM_VARS = 4,
    parameter MAX_STR_LEN = 16,
    parameter MAX_NESTING = 2,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Command interface (pre-parsed from input text)
    input wire [2:0] cmd_type,      // 0: LOAD, 1: COPY, 2: CONCAT, 3: PRINT, 4: END
    input wire [1:0] var_idx,       // Primary variable index
    input wire [1:0] var_idx2,      // Secondary variable index (for COPY)
    input wire [MAX_STR_LEN*DATA_WIDTH-1:0] literal_data,
    input wire [$clog2(MAX_STR_LEN+1)-1:0] literal_len,
    input wire [MAX_STR_LEN*DATA_WIDTH-1:0] prefix_data,
    input wire [$clog2(MAX_STR_LEN+1)-1:0] prefix_len,
    input wire [MAX_STR_LEN*DATA_WIDTH-1:0] suffix_data,
    input wire [$clog2(MAX_STR_LEN+1)-1:0] suffix_len,
    
    // Output interface
    output reg done,
    output reg [MAX_STR_LEN*DATA_WIDTH-1:0] print_data,
    output reg [$clog2(MAX_STR_LEN+1)-1:0] print_len,
    output reg print_valid
);

    // Variable storage with length tracking
    reg [MAX_STR_LEN*DATA_WIDTH-1:0] vars_data [0:NUM_VARS-1];
    reg [$clog2(MAX_STR_LEN+1)-1:0] vars_len [0:NUM_VARS-1];
    
    // Stack for nested template evaluation
    reg [MAX_STR_LEN*DATA_WIDTH-1:0] stack_data [0:MAX_NESTING-1];
    reg [$clog2(MAX_STR_LEN+1)-1:0] stack_len [0:MAX_NESTING-1];
    reg [$clog2(MAX_NESTING)-1:0] stack_ptr;
    
    // State machine
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] EXECUTE   = 3'd1;
    localparam [2:0] CONCATENATE = 3'd2;
    localparam [2:0] PRINTING  = 3'd3;
    localparam [2:0] FINISHED = 3'd4;
    
    reg [2:0] current_state, next_state;
    reg [$clog2(MAX_STR_LEN+1)-1:0] concat_pos;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            print_valid <= 1'b0;
            print_data <= {MAX_STR_LEN*DATA_WIDTH{1'b0}};
            print_len <= {$clog2(MAX_STR_LEN+1){1'b0}};
            stack_ptr <= {$clog2(MAX_NESTING){1'b0}};
            concat_pos <= {$clog2(MAX_STR_LEN+1){1'b0}};
            
            integer i;
            for (i = 0; i < NUM_VARS; i = i + 1) begin
                vars_data[i] <= {MAX_STR_LEN*DATA_WIDTH{1'b0}};
                vars_len[i] <= {$clog2(MAX_STR_LEN+1){1'b0}};
            end
            
            for (i = 0; i < MAX_NESTING; i = i + 1) begin
                stack_data[i] <= {MAX_STR_LEN*DATA_WIDTH{1'b0}};
                stack_len[i] <= {$clog2(MAX_STR_LEN+1){1'b0}};
            end
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    print_valid <= 1'b0;
                end
                
                EXECUTE: begin
                    done <= 1'b0;
                    print_valid <= 1'b0;
                    case (cmd_type)
                        3'd0: // LOAD
                            begin
                                vars_data[var_idx] <= literal_data;
                                vars_len[var_idx] <= literal_len;
                            end
                        3'd1: // COPY
                            begin
                                vars_data[var_idx] <= vars_data[var_idx2];
                                vars_len[var_idx] <= vars_len[var_idx2];
                            end
                        3'd2: // CONCAT
                            begin
                                // Initialize concatenation
                                concat_pos <= {$clog2(MAX_STR_LEN+1){1'b0}};
                                next_state = CONCATENATE;
                            end
                        3'd3: // PRINT
                            begin
                                print_data <= vars_data[var_idx];
                                print_len <= vars_len[var_idx];
                                print_valid <= 1'b1;
                            end
                        3'd4: // END
                            begin
                                done <= 1'b1;
                            end
                        default: begin
                                done <= 1'b1;
                            end
                    endcase
                end
                
                CONCATENATE: begin
                    case (concat_pos)
                        {$clog2(MAX_STR_LEN+1){1'b0}}: begin // Copy prefix to stack
                            stack_data[stack_ptr] <= prefix_data;
                            stack_len[stack_ptr] <= prefix_len;
                            concat_pos <= concat_pos + 1'b1;
                        end
                        1'b1: begin // Append variable
                            stack_data[stack_ptr] <= stack_data[stack_ptr] | 
                                (vars_data[var_idx] << (prefix_len * DATA_WIDTH));
                            stack_len[stack_ptr] <= prefix_len + vars_len[var_idx];
                            concat_pos <= concat_pos + 1'b1;
                        end
                        2'b10: begin // Append suffix
                            stack_data[stack_ptr] <= stack_data[stack_ptr] | 
                                (suffix_data << ((prefix_len + vars_len[var_idx]) * DATA_WIDTH));
                            stack_len[stack_ptr] <= prefix_len + vars_len[var_idx] + suffix_len;
                            // Store result
                            vars_data[var_idx] <= stack_data[stack_ptr];
                            vars_len[var_idx] <= stack_len[stack_ptr];
                            concat_pos <= {$clog2(MAX_STR_LEN+1){1'b0}};
                            done <= 1'b1;
                        end
                        default: begin
                            concat_pos <= {$clog2(MAX_STR_LEN+1){1'b0}};
                            done <= 1'b1;
                        end
                    endcase
                end
                
                PRINTING: begin
                    case (concat_pos)
                        {$clog2(MAX_STR_LEN+1){1'b0}}: begin // Initialize print buffer with prefix
                            print_data <= prefix_data;
                            print_len <= prefix_len;
                            concat_pos <= concat_pos + 1'b1;
                        end
                        1'b1: begin // Append variable
                            print_data <= print_data | (vars_data[var_idx] << (print_len * DATA_WIDTH));
                            print_len <= print_len + vars_len[var_idx];
                            concat_pos <= concat_pos + 1'b1;
                        end
                        2'b10: begin // Append suffix and finalize
                            print_data <= print_data | (suffix_data << (print_len * DATA_WIDTH));
                            print_len <= print_len + suffix_len;
                            print_valid <= 1'b1;
                            concat_pos <= {$clog2(MAX_STR_LEN+1){1'b0}};
                            done <= 1'b1;
                        end
                        default: begin
                            concat_pos <= {$clog2(MAX_STR_LEN+1){1'b0}};
                            done <= 1'b1;
                        end
                    endcase
                end
                
                FINISHED: begin
                    done <= 1'b1;
                    print_valid <= 1'b0;
                end
                
                default: begin
                    current_state <= IDLE;
                    done <= 1'b0;
                    print_valid <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    case (cmd_type)
                        3'd0, 3'd1, 3'd3, 3'd4: next_state = EXECUTE;
                        3'd2: next_state = CONCATENATE;
                        default: next_state = IDLE;
                    endcase
                end else begin
                    next_state = IDLE;
                end
            end
            EXECUTE: next_state = IDLE;
            CONCATENATE: begin
                if (concat_pos == 2'b10) 
                    next_state = IDLE;
                else
                    next_state = CONCATENATE;
            end
            PRINTING: begin
                if (concat_pos == 2'b10) 
                    next_state = IDLE;
                else
                    next_state = PRINTING;
            end
            FINISHED: next_state = FINISHED;
            default: next_state = IDLE;
        endcase
    end

endmodule