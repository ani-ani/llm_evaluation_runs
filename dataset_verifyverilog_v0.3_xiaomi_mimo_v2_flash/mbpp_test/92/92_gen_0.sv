module is_undulating (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] digit_0,
    input wire [3:0] digit_1,
    input wire [3:0] digit_2,
    input wire [3:0] digit_3,
    input wire [3:0] digit_4,
    input wire [3:0] digit_5,
    input wire [3:0] digit_6,
    input wire [3:0] digit_7,
    input wire [3:0] length,
    output reg result,
    output reg done
);

    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    localparam [1:0] INIT = 2'd3;
    
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg temp_result;
    reg [2:0] cycle_count;
    
    // Array to access digits easily
    wire [3:0] digits [0:7];
    assign digits[0] = digit_0;
    assign digits[1] = digit_1;
    assign digits[2] = digit_2;
    assign digits[3] = digit_3;
    assign digits[4] = digit_4;
    assign digits[5] = digit_5;
    assign digits[6] = digit_6;
    assign digits[7] = digit_7;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            index <= 4'd0;
            temp_result <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 3'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                INIT: begin
                    index <= 4'd2;
                    temp_result <= 1'b1;
                    next_state <= CHECK;
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 3'd1;
                    
                    if (index < length) begin
                        if (digits[index] != digits[index - 2]) begin
                            temp_result <= 1'b0;
                        end
                        index <= index + 1'b1;
                        next_state <= CHECK;
                    end else begin
                        next_state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    result <= temp_result && (length > 4'd2);
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule