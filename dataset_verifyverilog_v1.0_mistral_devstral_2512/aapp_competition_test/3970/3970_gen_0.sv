module k_multiple_free_subset(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [15:0] k,
    input [15:0] arr_0,
    input [15:0] arr_1,
    input [15:0] arr_2,
    input [15:0] arr_3,
    input [15:0] arr_4,
    input [15:0] arr_5,
    input [15:0] arr_6,
    input [15:0] arr_7,
    input [15:0] arr_8,
    input [15:0] arr_9,
    input [15:0] arr_10,
    input [15:0] arr_11,
    input [15:0] arr_12,
    input [15:0] arr_13,
    input [15:0] arr_14,
    input [15:0] arr_15,
    output reg [4:0] count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] MARK = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    // Array storage
    reg [15:0] arr [0:15];
    reg [15:0] sorted_arr [0:15];
    reg [15:0] temp;
    reg [3:0] i, j;
    reg [3:0] outer, inner;
    reg [3:0] mark_ptr;
    reg [3:0] result_count;
    reg [15:0] current_x;
    reg [15:0] target;
    reg [3:0] inner_ptr;
    reg [3:0] valid_elements;

    // Bubble sort control
    reg [3:0] sort_outer;
    reg [3:0] sort_inner;
    reg sort_done;

    // Marking control
    reg [3:0] mark_outer;
    reg [3:0] mark_inner;
    reg mark_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            count <= 5'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize arrays
            for (i = 0; i < 16; i = i + 1) begin
                arr[i] <= 16'd0;
                sorted_arr[i] <= 16'd0;
            end
            
            // Initialize counters
            outer <= 4'd0;
            inner <= 4'd0;
            mark_ptr <= 4'd0;
            result_count <= 4'd0;
            current_x <= 16'd0;
            target <= 16'd0;
            inner_ptr <= 4'd0;
            valid_elements <= 4'd0;
            
            // Sort control
            sort_outer <= 4'd0;
            sort_inner <= 4'd0;
            sort_done <= 1'b0;
            
            // Mark control
            mark_outer <= 4'd0;
            mark_inner <= 4'd0;
            mark_done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load input array
                    arr[0] <= arr_0;
                    arr[1] <= arr_1;
                    arr[2] <= arr_2;
                    arr[3] <= arr_3;
                    arr[4] <= arr_4;
                    arr[5] <= arr_5;
                    arr[6] <= arr_6;
                    arr[7] <= arr_7;
                    arr[8] <= arr_8;
                    arr[9] <= arr_9;
                    arr[10] <= arr_10;
                    arr[11] <= arr_11;
                    arr[12] <= arr_12;
                    arr[13] <= arr_13;
                    arr[14] <= arr_14;
                    arr[15] <= arr_15;
                    
                    // Initialize sorted array
                    for (i = 0; i < 16; i = i + 1) begin
                        sorted_arr[i] <= arr[i];
                    end
                    
                    // Initialize sort control
                    sort_outer <= 4'd0;
                    sort_inner <= 4'd0;
                    sort_done <= 1'b0;
                    
                    next_state <= SORT;
                end

                SORT: begin
                    // Bubble sort implementation
                    if (!sort_done) begin
                        if (sort_inner < 15 - sort_outer) begin
                            // Compare and swap
                            if (sorted_arr[sort_inner] > sorted_arr[sort_inner + 1]) begin
                                temp <= sorted_arr[sort_inner];
                                sorted_arr[sort_inner] <= sorted_arr[sort_inner + 1];
                                sorted_arr[sort_inner + 1] <= temp;
                            end
                            sort_inner <= sort_inner + 1;
                        end else begin
                            sort_inner <= 4'd0;
                            if (sort_outer < 14) begin
                                sort_outer <= sort_outer + 1;
                            end else begin
                                sort_done <= 1'b1;
                            end
                        end
                    end else begin
                        // Sort complete, move to marking
                        mark_outer <= 4'd0;
                        mark_inner <= 4'd0;
                        mark_done <= 1'b0;
                        result_count <= 4'd0;
                        valid_elements <= n;
                        next_state <= MARK;
                    end
                end

                MARK: begin
                    // Marking phase
                    if (!mark_done) begin
                        if (mark_outer < valid_elements) begin
                            current_x <= sorted_arr[mark_outer];
                            
                            // Check if this element should be included
                            if (current_x != 16'd0) begin
                                result_count <= result_count + 1;
                                
                                // Mark multiples of current_x
                                target <= current_x * k;
                                mark_inner <= mark_outer + 1;
                                
                                // Inner loop to mark multiples
                                if (mark_inner < valid_elements) begin
                                    if (sorted_arr[mark_inner] == target) begin
                                        sorted_arr[mark_inner] <= 16'd0;  // Mark as excluded
                                    end
                                    mark_inner <= mark_inner + 1;
                                end else begin
                                    mark_outer <= mark_outer + 1;
                                end
                            end else begin
                                mark_outer <= mark_outer + 1;
                            end
                        end else begin
                            mark_done <= 1'b1;
                        end
                    end else begin
                        count <= result_count;
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
            
            // Cycle counter for timeout
            if (cycle_count < MAX_CYCLES) begin
                cycle_count <= cycle_count + 1;
            end else begin
                cycle_count <= 8'd0;
                next_state <= IDLE;
                done <= 1'b0;
            end
        end
    end

endmodule