module NenScriptProcessor #(
    parameter NUM_VARS = 4,
    parameter MAX_STR_LEN = 16,
    parameter MAX_NESTING = 2,
    parameter DATA_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Command interface
    input wire [2:0] cmd_type,
    input wire [1:0] var_idx,
    input wire [1:0] var_idx2,
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

    // State declaration
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] EXECUTE   = 3'd1;
    localparam [2:0] CONCATENATE = 3'd2;
    localparam [2:0] PRINTING  = 3'd3;
    localparam [2:0] FINISHED  = 3'd4;
    
    reg [2:0] current_state, next_state;
    
    // Variable storage
    reg [MAX_STR_LEN*DATA_WIDTH-1:0] vars_data [0:NUM_VARS-1];
    reg [$clog2(MAX_STR_LEN+1)-1:0] vars_len [0:NUM_VARS-1];
    
    // Stack storage
    reg [MAX_STR_LEN*DATA_WIDTH-1:0] stack_data [0:MAX_NESTING-1];
    reg [$clog2(MAX_STR_LEN+1)-1:0] stack_len [0:MAX_NESTING-1];
    reg [$clog2(MAX_NESTING)-1:0] stack_ptr;
    
    // Control signals
    reg [$clog2(MAX_STR_LEN+1)-1:0] concat_pos;
    integer i;

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
            
            // Initialize variable arrays
            for (i = 0; i < NUM_VARS; i = i + 1) begin
                vars_data[i] <= {MAX_STR_LEN*DATA_WIDTH{1'b0}};
                vars_len[i] <= {$clog2(MAX_STR_LEN+1){1'b0}};
            end
            
            // Initialize stack arrays
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
                    case (cmd_type)
                        3'b000: begin // LOAD
                            vars_data[var_idx] <= literal_data;
                            vars_len[var_idx] <= literal_len;
                            done <= 1'b1;
                        end
                        3'b001: begin // COPY
                            vars_data[var_idx] <= vars_data[var_idx2];
                            vars_len[var_idx] <= vars_len[var_idx2];
                            done <= 1'b1;
                        end
                        3'b010: begin // PRINT
                            print_data <= vars_data[var_idx];
                            print_len <= vars_len[var_idx];
                            print_valid <= 1'b1;
                            done <= 1'b1;
                        end
                        3'b100: begin // END
                            done <= 1'b1;
                        end
                        default: done <= 1'b0;
                    endcase
                end
                
                CONCATENATE: begin
                    case (concat_pos)
                        0: begin // Load prefix
                            stack_data[stack_ptr] <= prefix_data;
                            stack_len[stack_ptr] <= prefix_len;
                            concat_pos <= concat_pos + 1;
                        end
                        1: begin // Append variable
                            stack_data[stack_ptr] <= stack_data[stack_ptr] | 
                                (vars_data[var_idx] << (prefix_len * DATA_WIDTH));
                            stack_len[stack_ptr] <= prefix_len + vars_len[var_idx];
                            concat_pos <= concat_pos + 1;
                        end
                        2: begin // Append suffix
                            stack_data[stack_ptr] <= stack_data[stack_ptr] | 
                                (suffix_data << ((stack_len[stack_ptr] * DATA_WIDTH)));
                            stack_len[stack_ptr] <= stack_len[stack_ptr] + suffix_len;
                            vars_data[var_idx] <= stack_data[stack_ptr];
                            vars_len[var_idx] <= stack_len[stack_ptr];
                            stack_ptr <= stack_ptr - 1;
                            done <= 1'b1;
                            concat_pos <= 0;
                        end
                        default: concat_pos <= 0;
                    endcase
                end
                
                PRINTING: begin
                    case (concat_pos)
                        0: begin // Load prefix
                            print_data <= prefix_data;
                            print_len <= prefix_len;
                            concat_pos <= concat_pos + 1;
                        end
                        1: begin // Append variable
                            print_data <= print_data | 
                                (vars_data[var_idx] << (print_len * DATA_WIDTH));
                            print_len <= print_len + vars_len[var_idx];
                            concat_pos <= concat_pos + 1;
                        end
                        2: begin // Append suffix and finalize
                            print_data <= print_data | 
                                (suffix_data << (print_len * DATA_WIDTH));
                            print_len <= print_len + suffix_len;
                            print_valid <= 1'b1;
                            done <= 1'b1;
                            concat_pos <= 0;
                        end
                        default: concat_pos <= 0;
                    endcase
                end
                
                FINISHED: begin
                    done <= 1'b0;
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
                        3'b010: next_state = PRINTING;
                        3'b011: next_state = CONCATENATE;
                        3'b100: next_state = FINISHED;
                        default: next_state = EXECUTE;
                    endcase
                end
            end
            
            EXECUTE: next_state = IDLE;
            
            CONCATENATE: begin
                if (done) next_state = IDLE;
                else next_state = CONCATENATE;
            end
            
            PRINTING: begin
                if (done) next_state = IDLE;
                else next_state = PRINTING;
            end
            
            FINISHED: next_state = FINISHED;
            
            default: next_state = IDLE;
        endcase
    end

endmodule