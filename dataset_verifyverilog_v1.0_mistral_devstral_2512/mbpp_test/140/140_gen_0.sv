module FlattenedListWithOrderPreservation(
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

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS_LIST0 = 3'd1;
    localparam [2:0] PROCESS_LIST1 = 3'd2;
    localparam [2:0] PROCESS_LIST2 = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state, next_state;

    // Counters and pointers
    reg [2:0] list0_ptr;
    reg [2:0] list1_ptr;
    reg [2:0] list2_ptr;
    reg [2:0] result_ptr;

    // Seen elements lookup table (8 entries, 4-bit each)
    reg [3:0] seen_elements [0:7];
    reg [2:0] seen_count;

    // Current element being processed
    reg [3:0] current_element;
    reg element_seen;

    // Cycle counter for timeout
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd25;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            list0_ptr <= 3'd0;
            list1_ptr <= 3'd0;
            list2_ptr <= 3'd0;
            result_ptr <= 3'd0;
            seen_count <= 3'd0;
            current_element <= 4'd0;
            element_seen <= 1'b0;
            cycle_count <= 5'd0;
            done <= 1'b0;
            result_count <= 4'd0;

            // Initialize result array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 4'd0;
            end

            // Initialize seen elements table
            for (i = 0; i < 8; i = i + 1) begin
                seen_elements[i] <= 4'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    if (start) begin
                        next_state <= PROCESS_LIST0;
                        list0_ptr <= 3'd0;
                        list1_ptr <= 3'd0;
                        list2_ptr <= 3'd0;
                        result_ptr <= 3'd0;
                        seen_count <= 3'd0;
                        result_count <= 4'd0;
                        
                        // Clear result array
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            result[i] <= 4'd0;
                        end
                        
                        // Clear seen elements table
                        for (i = 0; i < 8; i = i + 1) begin
                            seen_elements[i] <= 4'd0;
                        end
                    end
                end

                PROCESS_LIST0: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Check if we've processed all valid elements in list0
                    if (list0_ptr < list_0_valid) begin
                        current_element <= list_0[list0_ptr];
                        
                        // Check if element is already seen
                        element_seen <= 1'b0;
                        integer i;
                        for (i = 0; i < seen_count; i = i + 1) begin
                            if (seen_elements[i] == current_element) begin
                                element_seen <= 1'b1;
                            end
                        end
                        
                        // If not seen, add to result and mark as seen
                        if (!element_seen && seen_count < 8) begin
                            result[result_ptr] <= current_element;
                            seen_elements[seen_count] <= current_element;
                            seen_count <= seen_count + 3'd1;
                            result_ptr <= result_ptr + 3'd1;
                            result_count <= result_count + 4'd1;
                        end
                        
                        list0_ptr <= list0_ptr + 3'd1;
                    end else begin
                        next_state <= PROCESS_LIST1;
                    end
                end

                PROCESS_LIST1: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Check if we've processed all valid elements in list1
                    if (list1_ptr < list_1_valid) begin
                        current_element <= list_1[list1_ptr];
                        
                        // Check if element is already seen
                        element_seen <= 1'b0;
                        integer i;
                        for (i = 0; i < seen_count; i = i + 1) begin
                            if (seen_elements[i] == current_element) begin
                                element_seen <= 1'b1;
                            end
                        end
                        
                        // If not seen, add to result and mark as seen
                        if (!element_seen && seen_count < 8) begin
                            result[result_ptr] <= current_element;
                            seen_elements[seen_count] <= current_element;
                            seen_count <= seen_count + 3'd1;
                            result_ptr <= result_ptr + 3'd1;
                            result_count <= result_count + 4'd1;
                        end
                        
                        list1_ptr <= list1_ptr + 3'd1;
                    end else begin
                        next_state <= PROCESS_LIST2;
                    end
                end

                PROCESS_LIST2: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Check if we've processed all valid elements in list2
                    if (list2_ptr < list_2_valid) begin
                        current_element <= list_2[list2_ptr];
                        
                        // Check if element is already seen
                        element_seen <= 1'b0;
                        integer i;
                        for (i = 0; i < seen_count; i = i + 1) begin
                            if (seen_elements[i] == current_element) begin
                                element_seen <= 1'b1;
                            end
                        end
                        
                        // If not seen, add to result and mark as seen
                        if (!element_seen && seen_count < 8) begin
                            result[result_ptr] <= current_element;
                            seen_elements[seen_count] <= current_element;
                            seen_count <= seen_count + 3'd1;
                            result_ptr <= result_ptr + 3'd1;
                            result_count <= result_count + 4'd1;
                        end
                        
                        list2_ptr <= list2_ptr + 3'd1;
                    end else begin
                        next_state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end
endmodule