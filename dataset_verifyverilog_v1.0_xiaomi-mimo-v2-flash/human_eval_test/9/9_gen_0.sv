module rolling_max (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] arr [0:15],
    input wire [3:0] len,
    output reg signed [15:0] result,
    output reg done,
    output reg [3:0] position
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] PROCESS = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] pos_counter, next_pos_counter;
    reg signed [15:0] current_max, next_current_max;
    reg done_reg, next_done;
    reg [3:0] length_reg, next_length_reg;
    
    // Use integer for array index
    integer i;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos_counter <= 4'd0;
            current_max <= 16'sd0;
            done_reg <= 1'b0;
            length_reg <= 4'd0;
            result <= 16'sd0;
            position <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            pos_counter <= next_pos_counter;
            current_max <= next_current_max;
            done_reg <= next_done;
            length_reg <= next_length_reg;
            
            // Output assignments
            done <= done_reg;
            position <= pos_counter;
            
            // Result updates only during PROCESS state
            if (state == PROCESS) begin
                result <= current_max;
            end else if (state == FINISH) begin
                result <= 16'sd0;
            end
        end
    end

    // Combinational next state logic
    always @(*) begin
        // Defaults
        next_state = state;
        next_pos_counter = pos_counter;
        next_current_max = current_max;
        next_done = 1'b0;
        next_length_reg = length_reg;

        case (state)
            IDLE: begin
                next_pos_counter = 4'd0;
                next_current_max = 16'sd0;
                next_done = 1'b0;
                next_length_reg = 4'd0;
                
                if (start) begin
                    next_state = LOAD;
                    next_length_reg = len;
                    if (len > 4'd0) begin
                        next_current_max = arr[0];
                        next_pos_counter = 4'd0;
                    end
                end
            end
            
            LOAD: begin
                // Prepare first element output
                next_state = PROCESS;
                next_done = 1'b0;
            end
            
            PROCESS: begin
                // Output current maximum and increment position
                next_done = 1'b1;
                
                if (pos_counter < (length_reg - 4'd1)) begin
                    // Move to next position
                    next_pos_counter = pos_counter + 4'd1;
                    
                    // Compare and update max
                    if (arr[pos_counter + 4'd1] > current_max) begin
                        next_current_max = arr[pos_counter + 4'd1];
                    end else begin
                        next_current_max = current_max;
                    end
                    next_state = PROCESS;
                end else begin
                    // Finished processing all elements
                    next_state = FINISH;
                    next_done = 1'b0;
                end
            end
            
            FINISH: begin
                // Wait one cycle before returning to IDLE
                next_state = IDLE;
                next_done = 1'b0;
                next_pos_counter = 4'd0;
                next_current_max = 16'sd0;
            end
            
            default: begin
                next_state = IDLE;
                next_pos_counter = 4'd0;
                next_current_max = 16'sd0;
                next_done = 1'b0;
                next_length_reg = 4'd0;
            end
        endcase
    end

endmodule