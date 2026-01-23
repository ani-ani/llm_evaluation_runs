module max_product_subarray (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State encoding
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPUTE   = 3'd1;
    localparam [2:0] FINISH    = 3'd2;
    localparam [2:0] ERROR     = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] index;
    reg signed [15:0] max_ending_here;
    reg signed [15:0] min_ending_here;
    reg signed [15:0] max_so_far;
    reg has_non_zero;
    reg signed [7:0] current_element;
    reg signed [15:0] temp_max;
    reg signed [15:0] temp_min;
    reg signed [31:0] max_times_current;
    reg signed [31:0] min_times_current;
    reg signed [31:0] current_max_val;
    reg signed [31:0] current_min_val;
    
    // Helper signals for multiplication
    wire signed [15:0] max_result;
    wire signed [15:0] min_result;
    wire signed [31:0] max_mult;
    wire signed [31:0] min_mult;
    
    assign max_mult = max_ending_here * current_element;
    assign min_mult = min_ending_here * current_element;
    assign max_result = (max_mult[31:15] == 0) ? max_mult[15:0] : 16'h7FFF;
    assign min_result = (min_mult[31:15] == 0) ? min_mult[15:0] : 16'h7FFF;

    // Current element selection
    always @(*) begin
        case(index)
            4'd0: current_element = $signed(arr_0);
            4'd1: current_element = $signed(arr_1);
            4'd2: current_element = $signed(arr_2);
            4'd3: current_element = $signed(arr_3);
            4'd4: current_element = $signed(arr_4);
            4'd5: current_element = $signed(arr_5);
            4'd6: current_element = $signed(arr_6);
            4'd7: current_element = $signed(arr_7);
            default: current_element = 8'sd0;
        endcase
    end

    // Next state logic
    always @(*) begin
        case(state)
            IDLE: begin
                if (start)
                    next_state = COMPUTE;
                else
                    next_state = IDLE;
            end
            COMPUTE: begin
                if (index >= len)
                    next_state = FINISH;
                else
                    next_state = COMPUTE;
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    // Main computation logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            index <= 4'd0;
            max_ending_here <= 16'sd1;
            min_ending_here <= 16'sd1;
            max_so_far <= 16'sd0;
            has_non_zero <= 1'b0;
            result <= 16'd0;
            done <= 1'b0;
            max_times_current <= 32'sd0;
            min_times_current <= 32'sd0;
            current_max_val <= 32'sd0;
            current_min_val <= 32'sd0;
            temp_max <= 16'sd0;
            temp_min <= 16'sd0;
        end else begin
            case(state)
                IDLE: begin
                    if (start) begin
                        index <= 4'd0;
                        max_ending_here <= 16'sd1;
                        min_ending_here <= 16'sd1;
                        max_so_far <= 16'sd0;
                        has_non_zero <= 1'b0;
                        done <= 1'b0;
                    end
                end
                
                COMPUTE: begin
                    if (index < len) begin
                        // Calculate products
                        max_times_current <= max_ending_here * current_element;
                        min_times_current <= min_ending_here * current_element;
                        
                        // Check for zero in next cycle
                        if (current_element == 8'sd0) begin
                            max_ending_here <= 16'sd1;
                            min_ending_here <= 16'sd1;
                            has_non_zero <= 1'b0;
                        end else begin
                            has_non_zero <= 1'b1;
                        end
                        
                        // Update based on sign in next cycle
                        if (current_element > 8'sd0) begin
                            if (max_times_current[31:16] == 0)
                                max_ending_here <= max_times_current[15:0];
                            else
                                max_ending_here <= 16'h7FFF;
                            
                            if (min_times_current[31:16] == 0 && min_times_current != 0)
                                min_ending_here <= min_times_current[15:0];
                            else
                                min_ending_here <= 16'sd1;
                            
                            // Update max_so_far
                            if (max_times_current[31:16] == 0) begin
                                if (max_so_far < max_times_current[15:0])
                                    max_so_far <= max_times_current[15:0];
                            end
                        end else if (current_element < 8'sd0) begin
                            // Swap min and max
                            temp_max <= (min_times_current[31:16] == 0) ? min_times_current[15:0] : 16'h7FFF;
                            temp_min <= max_times_current[15:0];
                            
                            // Update max_so_far with new max
                            if (min_times_current[31:16] == 0) begin
                                if (max_so_far < min_times_current[15:0])
                                    max_so_far <= min_times_current[15:0];
                            end
                        end
                        
                        index <= index + 1'b1;
                    end
                end
                
                FINISH: begin
                    if (has_non_zero && max_so_far > 16'sd0)
                        result <= max_so_far;
                    else if (!has_non_zero)
                        result <= 16'sd0;
                    else
                        result <= 16'sd0;
                    done <= 1'b1;
                end
                
                default: begin
                    index <= 4'd0;
                    max_ending_here <= 16'sd1;
                    min_ending_here <= 16'sd1;
                    max_so_far <= 16'sd0;
                    has_non_zero <= 1'b0;
                    result <= 16'd0;
                    done <= 1'b0;
                    max_times_current <= 32'sd0;
                    min_times_current <= 32'sd0;
                    current_max_val <= 32'sd0;
                    current_min_val <= 32'sd0;
                    temp_max <= 16'sd0;
                    temp_min <= 16'sd0;
                end
            endcase
        end
    end

endmodule