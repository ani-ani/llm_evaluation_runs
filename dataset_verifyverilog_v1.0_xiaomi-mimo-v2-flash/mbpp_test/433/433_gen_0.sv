module check_greater_than_all(
    input clk,
    input rst_n,
    input start,
    input [15:0] number,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input valid_in,
    output reg result,
    output reg done
);

    // State machine declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] CHECK     = 2'd1;
    localparam [1:0] COMPLETE  = 2'd2;
    
    reg [1:0] state, next_state;
    reg result_reg;
    reg start_latched;
    reg valid_latched;
    
    // Computation logic: check if number > all array elements
    wire all_greater;
    wire comp_0, comp_1, comp_2, comp_3, comp_4, comp_5, comp_6, comp_7;
    
    // Individual comparisons (number is 16-bit, arr elements are 8-bit)
    // Number > arr[i] if upper 8 bits are non-zero OR lower 8 bits > arr[i]
    assign comp_0 = (number[15:8] != 8'd0) || (number[7:0] > arr_0);
    assign comp_1 = (number[15:8] != 8'd0) || (number[7:0] > arr_1);
    assign comp_2 = (number[15:8] != 8'd0) || (number[7:0] > arr_2);
    assign comp_3 = (number[15:8] != 8'd0) || (number[7:0] > arr_3);
    assign comp_4 = (number[15:8] != 8'd0) || (number[7:0] > arr_4);
    assign comp_5 = (number[15:8] != 8'd0) || (number[7:0] > arr_5);
    assign comp_6 = (number[15:8] != 8'd0) || (number[7:0] > arr_6);
    assign comp_7 = (number[15:8] != 8'd0) || (number[7:0] > arr_7);
    
    // Logical AND of all comparisons
    assign all_greater = comp_0 && comp_1 && comp_2 && comp_3 && 
                        comp_4 && comp_5 && comp_6 && comp_7;
    
    // State transition logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: begin
                if (start && valid_in) begin
                    next_state = CHECK;
                end else begin
                    next_state = IDLE;
                end
            end
            CHECK: begin
                // One cycle to complete the parallel comparison
                next_state = COMPLETE;
            end
            COMPLETE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            result_reg <= 1'b0;
            done <= 1'b0;
            start_latched <= 1'b0;
            valid_latched <= 1'b0;
        end else begin
            state <= next_state;
            
            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && valid_in) begin
                        start_latched <= 1'b1;
                        valid_latched <= 1'b1;
                    end else begin
                        start_latched <= 1'b0;
                        valid_latched <= 1'b0;
                    end
                end
                
                CHECK: begin
                    // Perform comparison and latch result
                    result_reg <= all_greater;
                    start_latched <= 1'b0;
                    valid_latched <= 1'b0;
                end
                
                COMPLETE: begin
                    // Output result and assert done
                    result <= result_reg;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    result_reg <= 1'b0;
                    done <= 1'b0;
                    start_latched <= 1'b0;
                    valid_latched <= 1'b0;
                end
            endcase
        end
    end

endmodule