module sum_odd_numbers (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] l,
    input wire [7:0] r,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [7:0] current_num;
    reg [15:0] accumulator;
    reg processing_done;
    
    // State register and synchronous reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            current_num <= 8'd0;
            accumulator <= 16'd0;
            processing_done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    processing_done <= 1'b0;
                    if (start) begin
                        current_num <= l;
                        accumulator <= 16'd0;
                    end
                end
                
                COMPUTING: begin
                    // Check if current number is odd
                    if (current_num[0]) begin
                        accumulator <= accumulator + {8'd0, current_num};
                    end
                    
                    // Check if we've reached the end
                    if (current_num >= r) begin
                        processing_done <= 1'b1;
                    end else begin
                        current_num <= current_num + 8'd1;
                    end
                end
                
                DONE_STATE: begin
                    result <= accumulator;
                    done <= 1'b1;
                    processing_done <= 1'b0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTING;
                end else begin
                    next_state = IDLE;
                end
            end
            
            COMPUTING: begin
                if (processing_done) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = COMPUTING;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule