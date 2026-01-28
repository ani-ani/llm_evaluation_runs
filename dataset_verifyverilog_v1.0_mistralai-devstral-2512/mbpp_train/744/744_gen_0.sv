module NoneChecker(
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
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] DONE  = 2'd2;

    // Internal signals
    reg [1:0] state;
    reg [2:0] index;
    reg [7:0] current_element;
    reg element_is_none;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    // Array element selection
    always @(*) begin
        case (index)
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

    // Check if current element is None (0xFF)
    assign element_is_none = (current_element == 8'd255);

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK;
                        index <= 3'd0;
                        result <= 1'b0;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current element is None
                    if (element_is_none) begin
                        result <= 1'b1;
                    end
                    
                    // Move to next element or finish
                    if (index == len - 1 || cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end else begin
                        index <= index + 3'd1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule