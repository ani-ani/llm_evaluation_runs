module sum_squares(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr [0:15],
    output reg signed [31:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [4:0] index;
    reg signed [31:0] accumulator;
    
    // Combinational Transformation Logic
    wire signed [7:0] current_element = arr[index];
    wire [1:0] mod3 = index % 3;
    wire [1:0] mod4 = index % 4;
    wire is_mod3 = (mod3 == 2'd0);
    wire is_mod4_only = (mod4 == 2'd0) && (mod3 != 2'd0);
    
    wire signed [15:0] square = current_element * current_element;
    wire signed [23:0] cube = square * current_element;
    
    wire signed [31:0] transformed_value = 
        is_mod3       ? { {16{square[15]} }, square} :
        is_mod4_only  ? { {8{cube[23]} }, cube} :
                        { {24{current_element[7]} }, current_element};  // Unchanged
    
    // Next State Logic
    reg [1:0] next_state;
    
    always @(*) begin
        next_state = state;
        case(state)
            IDLE: next_state = start ? PROCESSING : IDLE;
            PROCESSING: next_state = (index == 5'd15) ? DONE_STATE : PROCESSING;
            DONE_STATE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            accumulator <= 32'd0;
            done <= 1'b0;
            result <= 32'd0;
            index <= 5'd0;
        end
        else begin
            state <= next_state;
            done <= 1'b0;
            
            case(state)
                IDLE: begin
                    if (start) begin
                        accumulator <= 32'd0;
                        index <= 5'd0;
                    end
                end
                
                PROCESSING: begin
                    accumulator <= accumulator + transformed_value;
                    index <= index + 5'd1;
                end
                
                DONE_STATE: begin
                    result <= accumulator;
                    done <= 1'b1;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule