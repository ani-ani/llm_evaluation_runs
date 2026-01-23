module max_length_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input array of strings (sublists). Each string is up to 8 characters.
    // Individual port interface for sublists.
    input wire [7:0] sublist_0,
    input wire [7:0] sublist_1,
    input wire [7:0] sublist_2,
    input wire [3:0] sublist_len_0,
    input wire [3:0] sublist_len_1,
    input wire [3:0] sublist_len_2,
    input wire [3:0] num_sublists,  // Number of valid sublists (1-3)
    
    output reg [7:0] max_sublist_out,
    output reg [3:0] max_len_out,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] UPDATE = 2'd2;
    localparam [1:0] FINISH = 2'd3;
    
    reg [1:0] state, next_state;
    reg [3:0] idx, next_idx;
    reg [3:0] max_len_reg, next_max_len;
    reg [7:0] max_sublist_reg, next_max_sublist;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            max_len_reg <= 4'd0;
            max_sublist_reg <= 8'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            idx <= next_idx;
            max_len_reg <= next_max_len;
            max_sublist_reg <= next_max_sublist;
            cycle_count <= cycle_count + 8'd1;
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        next_idx = idx;
        next_max_len = max_len_reg;
        next_max_sublist = max_sublist_reg;
        
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = COMPARE;
                    next_idx = 4'd0;
                    next_max_len = 4'd0;
                    next_max_sublist = 8'd0;
                end
            end
            
            COMPARE: begin
                if (idx < num_sublists) begin
                    // Get current sublist length
                    reg [3:0] curr_len;
                    case (idx)
                        4'd0: curr_len = sublist_len_0;
                        4'd1: curr_len = sublist_len_1;
                        4'd2: curr_len = sublist_len_2;
                        default: curr_len = 4'd0;
                    endcase
                    
                    if (curr_len > max_len_reg) begin
                        next_state = UPDATE;
                    end else begin
                        next_state = COMPARE;
                        next_idx = idx + 4'd1;
                    end
                end else begin
                    next_state = FINISH;
                end
            end
            
            UPDATE: begin
                // Update max values
                case (idx)
                    4'd0: begin
                        next_max_len = sublist_len_0;
                        next_max_sublist = sublist_0;
                    end
                    4'd1: begin
                        next_max_len = sublist_len_1;
                        next_max_sublist = sublist_1;
                    end
                    4'd2: begin
                        next_max_len = sublist_len_2;
                        next_max_sublist = sublist_2;
                    end
                    default: begin
                        next_max_len = 4'd0;
                        next_max_sublist = 8'd0;
                    end
                endcase
                next_state = COMPARE;
                next_idx = idx + 4'd1;
            end
            
            FINISH: begin
                done = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                end
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Output assignments
    always @(posedge clk) begin
        if (state == FINISH) begin
            max_sublist_out <= max_sublist_reg;
            max_len_out <= max_len_reg;
        end
    end
    
endmodule