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
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] index;
    reg [15:0] max_ending_here;
    reg [15:0] min_ending_here;
    reg [15:0] max_so_far;
    reg [7:0] current_element;
    reg [15:0] temp_max;
    reg [15:0] temp_min;
    
    // Current element selection
    always @(*) begin
        case(index)
            3'd0: current_element = arr_0;
            3'd1: current_element = arr_1;
            3'd2: current_element = arr_2;
            3'd3: current_element = arr_3;
            3'd4: current_element = arr_4;
            3'd5: current_element = arr_5;
            3'd6: current_element = arr_6;
            3'd7: current_element = arr_7;
            default: current_element = 8'd0;
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
            index <= 3'd0;
            max_ending_here <= 16'd1;
            min_ending_here <= 16'd1;
            max_so_far <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case(state)
                IDLE: begin
                    if (start) begin
                        index <= 3'd0;
                        max_ending_here <= 16'd1;
                        min_ending_here <= 16'd1;
                        max_so_far <= 16'd0;
                        done <= 1'b0;
                    end
                end
                
                COMPUTE: begin
                    if (index < len) begin
                        // Update max_ending_here and min_ending_here
                        if (current_element > 8'd0) begin
                            // Positive number
                            max_ending_here <= max_ending_here * current_element;
                            min_ending_here <= min_ending_here * current_element;
                        end else if (current_element == 8'd0) begin
                            // Zero
                            max_ending_here <= 16'd1;
                            min_ending_here <= 16'd1;
                        end else begin
                            // Negative number
                            temp_max <= min_ending_here * current_element;
                            temp_min <= max_ending_here * current_element;
                            max_ending_here <= temp_max;
                            min_ending_here <= temp_min;
                        end
                        
                        // Update max_so_far
                        if (max_ending_here > max_so_far)
                            max_so_far <= max_ending_here;
                        
                        index <= index + 1'b1;
                    end
                end
                
                FINISH: begin
                    result <= max_so_far;
                    done <= 1'b1;
                end
                
                default: begin
                    index <= 3'd0;
                    max_ending_here <= 16'd1;
                    min_ending_here <= 16'd1;
                    max_so_far <= 16'd0;
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule