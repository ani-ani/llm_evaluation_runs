module find_first_odd(
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
    input [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCANNING = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [3:0] index;
    reg [7:0] current_element;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            index <= 4'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= SCANNING;
                        index <= 4'd0;
                    end
                end

                SCANNING: begin
                    cycle_count <= cycle_count + 4'd1;

                    // Select current element based on index
                    case (index)
                        4'd0: current_element = arr_0;
                        4'd1: current_element = arr_1;
                        4'd2: current_element = arr_2;
                        4'd3: current_element = arr_3;
                        4'd4: current_element = arr_4;
                        4'd5: current_element = arr_5;
                        4'd6: current_element = arr_6;
                        4'd7: current_element = arr_7;
                        default: current_element = 8'd0;
                    endcase

                    // Check if current element is odd
                    if (current_element[0] == 1'b1) begin
                        result <= current_element;
                        state <= FINISH;
                    end else begin
                        // Move to next index
                        index <= index + 4'd1;
                        
                        // Check if we've reached the end
                        if (index >= len || cycle_count >= MAX_CYCLES) begin
                            result <= 8'd255;  // 0xFF for no odd found
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule