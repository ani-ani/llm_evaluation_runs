module kth_element_finder (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] k,
    input [3:0] array_size,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] LOAD        = 3'd1;
    localparam [2:0] INIT_SORT   = 3'd2;
    localparam [2:0] COMPARE     = 3'd3;
    localparam [2:0] CHECK_PASS  = 3'd4;
    localparam [2:0] OUTPUT      = 3'd5;
    localparam [2:0] FINISH      = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] arr_internal [0:7];
    reg [3:0] pass_counter;      // Pass count (0 to n-2)
    reg [3:0] compare_counter;   // Comparison within pass
    reg [3:0] current_size;      // Array size for current pass
    reg [7:0] temp_swap;
    reg [7:0] result_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    integer i;

    // State transition and register updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            pass_counter <= 4'd0;
            compare_counter <= 4'd0;
            current_size <= 4'd0;
            result_reg <= 8'd0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                arr_internal[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    pass_counter <= 4'd0;
                    compare_counter <= 4'd0;
                    current_size <= 4'd0;
                    result_reg <= 8'd0;
                end
                
                LOAD: begin
                    arr_internal[0] <= arr_0;
                    arr_internal[1] <= arr_1;
                    arr_internal[2] <= arr_2;
                    arr_internal[3] <= arr_3;
                    arr_internal[4] <= arr_4;
                    arr_internal[5] <= arr_5;
                    arr_internal[6] <= arr_6;
                    arr_internal[7] <= arr_7;
                    result_reg <= 8'd0;
                end
                
                INIT_SORT: begin
                    pass_counter <= 4'd0;
                    compare_counter <= 4'd0;
                    current_size <= array_size - 4'd1;
                    cycle_count <= 8'd0;
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compare arr_internal[compare_counter] and arr_internal[compare_counter+1]
                    if (arr_internal[compare_counter] > arr_internal[compare_counter + 1]) begin
                        temp_swap <= arr_internal[compare_counter];
                        // Swap will be done in next state or combinational logic
                    end
                end
                
                CHECK_PASS: begin
                    // Perform swap if needed (comb logic below handles, just update counters here)
                    if (compare_counter < current_size - 1) begin
                        compare_counter <= compare_counter + 4'd1;
                    end else begin
                        pass_counter <= pass_counter + 4'd1;
                        compare_counter <= 4'd0;
                        current_size <= array_size - pass_counter - 4'd2;
                    end
                end
                
                OUTPUT: begin
                    // result_reg already set in combinational logic
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= result_reg;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            
            LOAD: begin
                next_state = INIT_SORT;
            end
            
            INIT_SORT: begin
                if (array_size <= 4'd1) begin
                    next_state = OUTPUT;  // Already sorted
                end else begin
                    next_state = COMPARE;
                end
            end
            
            COMPARE: begin
                next_state = CHECK_PASS;
            end
            
            CHECK_PASS: begin
                // Check if comparison is complete in this pass
                if (compare_counter < current_size - 1) begin
                    next_state = COMPARE;
                end else begin
                    // Check if all passes are complete
                    // Pass complete when pass_counter >= (array_size - 2) or current_size <= 0
                    if (pass_counter >= (array_size - 2) || current_size <= 4'd0) begin
                        next_state = OUTPUT;
                    end else begin
                        next_state = COMPARE;
                    end
                end
            end
            
            OUTPUT: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Swap operation (combinational assignment to registers)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already reset above
        end else if (state == COMPARE) begin
            if (arr_internal[compare_counter] > arr_internal[compare_counter + 1]) begin
                arr_internal[compare_counter] <= arr_internal[compare_counter + 1];
                arr_internal[compare_counter + 1] <= temp_swap;
            end
        end
    end

    // Result extraction (combinational logic)
    always @(*) begin
        if (state == OUTPUT) begin
            // k is 1-based, need k-1 index (0-based)
            if (k == 4'd1) result_reg = arr_internal[0];
            else if (k == 4'd2) result_reg = arr_internal[1];
            else if (k == 4'd3) result_reg = arr_internal[2];
            else if (k == 4'd4) result_reg = arr_internal[3];
            else if (k == 4'd5) result_reg = arr_internal[4];
            else if (k == 4'd6) result_reg = arr_internal[5];
            else if (k == 4'd7) result_reg = arr_internal[6];
            else if (k == 4'd8) result_reg = arr_internal[7];
            else result_reg = 8'd0;  // Default
        end else begin
            result_reg = result_reg;  // Hold value
        end
    end

endmodule