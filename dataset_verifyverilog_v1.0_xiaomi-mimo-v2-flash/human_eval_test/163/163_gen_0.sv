module DigitGenerator (
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    output reg [7:0] digits_out [0:4],
    output reg [3:0] count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] LOAD     = 3'd1;
    localparam [2:0] COMPUTE  = 3'd2;
    localparam [2:0] OUTPUT   = 3'd3;
    localparam [2:0] FINISH   = 3'd4;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Control registers
    reg [7:0] low_reg;
    reg [7:0] high_reg;
    reg [3:0] digit_idx;
    reg [3:0] output_idx;
    reg [3:0] temp_count;
    
    // Temporary storage for next cycle
    reg [2:0] next_state_reg;
    reg [7:0] next_digits_out [0:4];
    reg [3:0] next_count;
    reg next_done;

    integer i;

    // FSM State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            low_reg <= 8'd0;
            high_reg <= 8'd0;
            digit_idx <= 4'd0;
            output_idx <= 4'd0;
            temp_count <= 4'd0;
            done <= 1'b0;
            count <= 4'd0;
            for (i = 0; i < 5; i = i + 1) begin
                digits_out[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            if (state == LOAD) begin
                low_reg <= (a < b) ? a : b;
                high_reg <= (a < b) ? b : a;
                digit_idx <= 4'd0;
                output_idx <= 4'd0;
                temp_count <= 4'd0;
                // Reset output array
                for (i = 0; i < 5; i = i + 1) begin
                    digits_out[i] <= 8'd0;
                end
            end
            
            if (state == COMPUTE) begin
                // Check even digit (d[0] == 0) and in range
                if ((digit_idx[0] == 1'b0) && (digit_idx >= low_reg[3:0]) && (digit_idx <= high_reg[3:0])) begin
                    if (output_idx < 4'd5) begin
                        digits_out[output_idx] <= {4'd0, digit_idx};
                        output_idx <= output_idx + 4'd1;
                        temp_count <= temp_count + 4'd1;
                    end
                end
                digit_idx <= digit_idx + 4'd1;
            end
            
            if (state == OUTPUT) begin
                count <= temp_count;
            end
            
            if (state == FINISH) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            
            LOAD: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                // Digit range is 0-9 (10 digits)
                if (digit_idx >= 4'd9)
                    next_state = OUTPUT;
                else
                    next_state = COMPUTE;
            end
            
            OUTPUT: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule