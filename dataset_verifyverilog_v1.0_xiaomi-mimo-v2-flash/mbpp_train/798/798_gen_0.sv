module array_sum_accumulator (
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
    input [7:0] arr_8,
    input [7:0] arr_9,
    input [7:0] arr_10,
    input [7:0] arr_11,
    input [7:0] arr_12,
    input [7:0] arr_13,
    input [7:0] arr_14,
    input [7:0] arr_15,
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] FETCH = 2'd1;
    localparam [1:0] ADD   = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [3:0] len_reg;           // Store length
    reg [3:0] index;             // Current array index
    reg [3:0] counter;           // Elements remaining
    reg [15:0] accumulator;
    reg [7:0] current_element;   // Registered current element
    
    // Control flags
    reg processing;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            len_reg <= 4'd0;
            index <= 4'd0;
            counter <= 4'd0;
            accumulator <= 16'd0;
            current_element <= 8'd0;
            processing <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    processing <= 1'b0;
                    if (start) begin
                        // Load length and check if zero
                        len_reg <= len;
                        index <= 4'd0;
                        accumulator <= 16'd0;
                        
                        if (len == 4'd0) begin
                            // Zero-length case: immediate done
                            result <= 16'd0;
                            state <= FINISH;
                            done <= 1'b1;
                        end else begin
                            counter <= len;
                            state <= FETCH;
                        end
                    end
                end
                
                FETCH: begin
                    // Load current array element based on index
                    case (index)
                        4'd0:  current_element <= arr_0;
                        4'd1:  current_element <= arr_1;
                        4'd2:  current_element <= arr_2;
                        4'd3:  current_element <= arr_3;
                        4'd4:  current_element <= arr_4;
                        4'd5:  current_element <= arr_5;
                        4'd6:  current_element <= arr_6;
                        4'd7:  current_element <= arr_7;
                        4'd8:  current_element <= arr_8;
                        4'd9:  current_element <= arr_9;
                        4'd10: current_element <= arr_10;
                        4'd11: current_element <= arr_11;
                        4'd12: current_element <= arr_12;
                        4'd13: current_element <= arr_13;
                        4'd14: current_element <= arr_14;
                        4'd15: current_element <= arr_15;
                        default: current_element <= 8'd0;
                    endcase
                    state <= ADD;
                end
                
                ADD: begin
                    // Add to accumulator (16-bit unsigned, wraps on overflow)
                    accumulator <= accumulator + {8'd0, current_element};
                    index <= index + 4'd1;
                    counter <= counter - 4'd1;
                    
                    if (counter == 4'd1) begin
                        // Last element, finish
                        state <= FINISH;
                        processing <= 1'b1;
                    end else begin
                        state <= FETCH;
                    end
                end
                
                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;
                    state <= IDLE;
                    processing <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule