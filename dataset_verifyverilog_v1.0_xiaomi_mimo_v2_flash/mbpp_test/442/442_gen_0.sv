module positive_ratio(
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
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COUNT = 3'd1;
    localparam [2:0] CALC = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] idx;
    reg [3:0] pos_count;
    reg [15:0] numerator;
    reg [15:0] quotient;
    reg [5:0] bit_idx;
    reg start_deasserted;
    reg [7:0] current_val;
    
    // Combinational logic for array element selection
    always @(*) begin
        case (idx)
            4'd0: current_val = arr_0;
            4'd1: current_val = arr_1;
            4'd2: current_val = arr_2;
            4'd3: current_val = arr_3;
            4'd4: current_val = arr_4;
            4'd5: current_val = arr_5;
            4'd6: current_val = arr_6;
            default: current_val = arr_7;
        endcase
    end
    
    // Next state logic
    always @(*) begin
        next_state = IDLE;  // Default
        case (state)
            IDLE: begin
                if (start && !start_deasserted) begin
                    next_state = COUNT;
                end else begin
                    next_state = IDLE;
                end
            end
            
            COUNT: begin
                if (idx < len) begin
                    next_state = COUNT;
                end else begin
                    next_state = CALC;
                end
            end
            
            CALC: begin
                if (bit_idx > 0) begin
                    next_state = CALC;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                next_state = OUTPUT;  // Stay in output until start is low
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // State register and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            pos_count <= 4'd0;
            numerator <= 16'd0;
            quotient <= 16'd0;
            bit_idx <= 6'd0;
            result <= 16'd0;
            done <= 1'b0;
            start_deasserted <= 1'b0;
        end else begin
            state <= next_state;
            
            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                    start_deasserted <= 1'b0;
                end
                
                COUNT: begin
                    if (state == IDLE) begin
                        // Starting new count
                        idx <= 4'd0;
                        pos_count <= 4'd0;
                    end else if (idx < len) begin
                        // Check if positive (signed value > 0)
                        if (current_val[7] == 1'b0 && current_val != 8'h00) begin
                            pos_count <= pos_count + 1'b1;
                        end
                        idx <= idx + 1'b1;
                    end
                end
                
                CALC: begin
                    if (state == COUNT) begin
                        // Prepare for division: (pos_count << 8) / len
                        numerator <= {8'd0, pos_count} << 8;
                        quotient <= 16'd0;
                        bit_idx <= 6'd16;
                    end else if (bit_idx > 0) begin
                        // Restore division algorithm
                        quotient <= quotient << 1;
                        if (numerator[15:8] >= {1'b0, len}) begin
                            quotient[0] <= 1'b1;
                            numerator[15:8] <= numerator[15:8] - {1'b0, len};
                        end
                        numerator <= numerator << 1;
                        bit_idx <= bit_idx - 1'b1;
                    end
                end
                
                OUTPUT: begin
                    if (state == CALC) begin
                        result <= quotient;
                        done <= 1'b1;
                    end
                    // Deassert done when start is low
                    if (!start) begin
                        done <= 1'b0;
                        start_deasserted <= 1'b1;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule