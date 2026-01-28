module max_sum_finder(
    input clk,
    input rst_n,
    input start,
    input [7:0] lists [0:15][0:15],
    input [3:0] lengths [0:15],
    input [3:0] num_lists,
    output reg [7:0] result_list [0:15],
    output reg [3:0] result_index,
    output reg done,
    output reg [15:0] max_sum
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LIST_SELECT = 2'd1;
    localparam [1:0] SUMMING = 2'd2;
    localparam [1:0] COMPARE = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Counters and registers
    reg [3:0] list_index;
    reg [3:0] element_index;
    reg [15:0] current_sum;
    reg [3:0] max_sum_index;
    reg [15:0] max_sum_reg;
    reg [7:0] result_list_reg [0:15];
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            list_index <= 4'd0;
            element_index <= 4'd0;
            current_sum <= 16'd0;
            max_sum_index <= 4'd0;
            max_sum_reg <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize result_list to 0
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result_list_reg[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LIST_SELECT;
                        list_index <= 4'd0;
                        element_index <= 4'd0;
                        current_sum <= 16'd0;
                        max_sum_index <= 4'd0;
                        max_sum_reg <= 16'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LIST_SELECT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (list_index < num_lists) begin
                        element_index <= 4'd0;
                        current_sum <= 16'd0;
                        next_state <= SUMMING;
                    end else begin
                        next_state <= COMPARE;
                    end
                end
                
                SUMMING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (element_index < lengths[list_index]) begin
                        current_sum <= current_sum + lists[list_index][element_index];
                        element_index <= element_index + 4'd1;
                        next_state <= SUMMING;
                    end else begin
                        next_state <= COMPARE;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_sum > max_sum_reg) begin
                        max_sum_reg <= current_sum;
                        max_sum_index <= list_index;
                        
                        // Copy current list to result
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            result_list_reg[i] <= lists[list_index][i];
                        end
                    end
                    
                    list_index <= list_index + 4'd1;
                    if (list_index < num_lists) begin
                        next_state <= LIST_SELECT;
                    end else begin
                        next_state <= IDLE;
                        done <= 1'b1;
                    end
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

    // Output assignments
    always @(posedge clk) begin
        result_index <= max_sum_index;
        max_sum <= max_sum_reg;
        
        integer i;
        for (i = 0; i < 16; i = i + 1) begin
            result_list[i] <= result_list_reg[i];
        end
    end

endmodule