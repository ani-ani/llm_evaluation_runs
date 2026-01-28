module find_even_sum (
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

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] COMPUTING  = 2'd1;
    localparam [1:0] FINISH     = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] index;
    reg [15:0] accumulator;
    reg [7:0] current_element;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers on reset
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            index <= 4'd0;
            accumulator <= 16'd0;
            current_element <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    index <= 4'd0;
                    accumulator <= 16'd0;
                    
                    if (start) begin
                        state <= COMPUTING;
                    end
                end

                COMPUTING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get element based on index
                    case (index)
                        4'd0: current_element <= arr_0;
                        4'd1: current_element <= arr_1;
                        4'd2: current_element <= arr_2;
                        4'd3: current_element <= arr_3;
                        4'd4: current_element <= arr_4;
                        4'd5: current_element <= arr_5;
                        4'd6: current_element <= arr_6;
                        4'd7: current_element <= arr_7;
                        default: current_element <= 8'd0;
                    endcase
                    
                    // Process even indices only
                    if (index[0] == 1'b0) begin
                        // Check if index is within valid length
                        if (index < len) begin
                            // Check if element is even (bit 0 is 0)
                            if (current_element[0] == 1'b0) begin
                                accumulator <= accumulator + {8'd0, current_element};
                            end
                        end
                    end
                    
                    // Move to next index
                    if (index < 4'd7) begin
                        index <= index + 4'd1;
                    end
                    
                    // Completion conditions
                    if (index >= 4'd7 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result <= accumulator;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule