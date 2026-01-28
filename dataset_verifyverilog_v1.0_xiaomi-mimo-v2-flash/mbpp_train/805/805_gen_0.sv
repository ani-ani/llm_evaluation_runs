module max_sum_list_finder (
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

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LIST_SELECT = 2'd1;
    localparam [1:0] SUMMING = 2'd2;
    localparam [1:0] COMPARE = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [3:0] list_index;        // Current list being processed (0-15)
    reg [3:0] element_index;     // Current element within list
    reg [15:0] current_sum;      // Sum of current list
    reg [3:0] max_sum_index_reg; // Index of list with max sum
    reg [15:0] max_sum_reg;      // Maximum sum found so far
    reg [7:0] temp_list [0:15];  // Temp storage for current list being read
    
    // One-hot counter for list selection
    wire [15:0] list_mask;
    assign list_mask = (1'b1 << list_index);

    // Cycle counter to prevent infinite loops (max 256 cycles)
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd256;

    integer i;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LIST_SELECT;
                else
                    next_state = IDLE;
            end
            LIST_SELECT: begin
                next_state = SUMMING;
            end
            SUMMING: begin
                if (element_index < lengths[list_index])
                    next_state = SUMMING;
                else
                    next_state = COMPARE;
            end
            COMPARE: begin
                if (list_index < (num_lists - 1) && cycle_count < MAX_CYCLES)
                    next_state = LIST_SELECT;
                else
                    next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            max_sum <= 16'd0;
            result_index <= 4'd0;
            list_index <= 4'd0;
            element_index <= 4'd0;
            current_sum <= 16'd0;
            max_sum_index_reg <= 4'd0;
            max_sum_reg <= 16'd0;
            cycle_count <= 9'd0;
            for (i = 0; i < 16; i = i + 1) begin
                result_list[i] <= 8'd0;
                temp_list[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    list_index <= 4'd0;
                    element_index <= 4'd0;
                    current_sum <= 16'd0;
                    max_sum_index_reg <= 4'd0;
                    max_sum_reg <= 16'd0;
                    cycle_count <= 9'd0;
                end
                
                LIST_SELECT: begin
                    // Read the current list into temp storage
                    for (i = 0; i < 16; i = i + 1) begin
                        temp_list[i] <= lists[list_index][i];
                    end
                    element_index <= 4'd0;
                    current_sum <= 16'd0;
                    cycle_count <= cycle_count + 9'd1;
                end
                
                SUMMING: begin
                    // Add current element to sum
                    current_sum <= current_sum + temp_list[element_index];
                    element_index <= element_index + 4'd1;
                end
                
                COMPARE: begin
                    // Compare current sum with max
                    if (current_sum > max_sum_reg) begin
                        max_sum_reg <= current_sum;
                        max_sum_index_reg <= list_index;
                        // Copy temp_list to result_list
                        for (i = 0; i < 16; i = i + 1) begin
                            result_list[i] <= temp_list[i];
                        end
                    end
                    
                    // Move to next list
                    list_index <= list_index + 4'd1;
                    
                    // Check if done
                    if (list_index >= (num_lists - 1) || cycle_count >= MAX_CYCLES) begin
                        // Update final outputs
                        max_sum <= max_sum_reg;
                        result_index <= max_sum_index_reg;
                        done <= 1'b1;
                        // Note: state will transition to IDLE next cycle
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule