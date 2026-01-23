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
    
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg temp_result;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            temp_result <= 1'b0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        index <= 4'd2;
                        temp_result <= 1'b1;
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (index < length) begin
                        if (digit_0 != digit_2 || digit_1 != digit_3 || digit_2 != digit_4 || 
                            digit_3 != digit_5 || digit_4 != digit_6 || digit_5 != digit_7) begin
                            temp_result <= 1'b0;
                        end
                        index <= index + 4'd1;
                    end
                end
                
                COMPLETE: begin
                    result <= temp_result && (length > 4'd2);
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK;
                else
                    next_state = IDLE;
            end
            
            CHECK: begin
                if (index >= length || cycle_count >= MAX_CYCLES)
                    next_state = COMPLETE;
                else
                    next_state = CHECK;
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule