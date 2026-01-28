module tribonacci (
    input clk,
    input rst_n,
    input start,
    input [4:0] n_in,
    output reg [31:0] result,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] OUT_0      = 4'd1;
    localparam [3:0] OUT_1      = 4'd2;
    localparam [3:0] LOOP_START = 4'd3;
    localparam [3:0] OUT_EVEN   = 4'd4;
    localparam [3:0] CALC_ODD   = 4'd5;
    localparam [3:0] OUT_ODD    = 4'd6;
    localparam [3:0] NEXT_ITER  = 4'd7;
    localparam [3:0] DONE_STATE = 4'd8;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Internal registers
    reg [4:0] target_n;
    reg [4:0] current_index;
    reg [31:0] prev_odd;
    reg [31:0] k;
    reg [31:0] temp_odd;
    reg done_reg;
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = OUT_0;
                else
                    next_state = IDLE;
            end
            
            OUT_0: begin
                if (target_n == 5'd0)
                    next_state = DONE_STATE;
                else
                    next_state = OUT_1;
            end
            
            OUT_1: begin
                if (target_n == 5'd1)
                    next_state = DONE_STATE;
                else
                    next_state = LOOP_START;
            end
            
            LOOP_START: begin
                next_state = OUT_EVEN;
            end
            
            OUT_EVEN: begin
                if (current_index == target_n)
                    next_state = DONE_STATE;
                else
                    next_state = CALC_ODD;
            end
            
            CALC_ODD: begin
                next_state = OUT_ODD;
            end
            
            OUT_ODD: begin
                if (current_index == target_n)
                    next_state = DONE_STATE;
                else
                    next_state = NEXT_ITER;
            end
            
            NEXT_ITER: begin
                next_state = OUT_EVEN;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // State register and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            valid <= 1'b0;
            done_reg <= 1'b0;
            done <= 1'b0;
            target_n <= 5'd0;
            current_index <= 5'd0;
            prev_odd <= 32'd0;
            k <= 32'd0;
            temp_odd <= 32'd0;
        end else begin
            // Default outputs
            valid <= 1'b0;
            done <= 1'b0;
            
            // Update state
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        target_n <= n_in;
                        current_index <= 5'd0;
                    end
                end
                
                OUT_0: begin
                    result <= 32'd1;
                    valid <= 1'b1;
                    current_index <= 5'd1;
                end
                
                OUT_1: begin
                    result <= 32'd3;
                    valid <= 1'b1;
                    current_index <= 5'd2;
                end
                
                LOOP_START: begin
                    k <= 32'd1;
                    prev_odd <= 32'd3;
                end
                
                OUT_EVEN: begin
                    // tri(2k) = 1 + k
                    result <= 32'd1 + k;
                    valid <= 1'b1;
                    current_index <= current_index + 5'd2;
                end
                
                CALC_ODD: begin
                    // tri(2k+1) = 3 + 2k + prev_odd
                    temp_odd <= 32'd3 + (k << 1) + prev_odd;
                end
                
                OUT_ODD: begin
                    result <= temp_odd;
                    valid <= 1'b1;
                    current_index <= current_index + 5'd2;
                end
                
                NEXT_ITER: begin
                    k <= k + 32'd1;
                    prev_odd <= temp_odd;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    result <= 32'd0;
                    valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule