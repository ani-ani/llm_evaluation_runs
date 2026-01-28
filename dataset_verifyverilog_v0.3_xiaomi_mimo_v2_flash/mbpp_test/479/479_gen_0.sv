module first_digit_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] num_in,
    output reg [7:0] first_digit,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] COMPUTE = 2'b01;
    localparam [1:0] COMPLETE = 2'b10;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] current_num;
    reg [7:0] next_current_num;
    reg [3:0] iteration_count;
    reg [3:0] next_iteration_count;

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_num <= 8'd0;
            iteration_count <= 4'd0;
            done <= 1'b0;
            first_digit <= 8'd0;
        end else begin
            state <= next_state;
            current_num <= next_current_num;
            iteration_count <= next_iteration_count;
        end
    end

    // Next state and output logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_current_num = current_num;
        next_iteration_count = iteration_count;
        first_digit = 8'd0;
        done = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE;
                    next_current_num = num_in;
                    next_iteration_count = 4'd0;
                end
                done = 1'b0;
            end
            
            COMPUTE: begin
                if (current_num >= 8'd10 && iteration_count < 4'd8) begin
                    next_current_num = current_num / 8'd10;
                    next_iteration_count = iteration_count + 4'd1;
                    next_state = COMPUTE;
                end else begin
                    next_state = COMPLETE;
                end
            end
            
            COMPLETE: begin
                first_digit = current_num;
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
                next_current_num = 8'd0;
                next_iteration_count = 4'd0;
                first_digit = 8'd0;
                done = 1'b0;
            end
        endcase
    end

endmodule