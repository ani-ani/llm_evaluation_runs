module series_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] current_term;
    reg [7:0] next_term;
    reg [15:0] accumulator;
    reg [15:0] next_accumulator;
    reg [4:0] counter;  // Max iterations for n=32 is 16, need 5 bits
    reg [4:0] next_counter;
    reg [7:0] n_reg;  // Store n_in during computation
    reg [7:0] next_n_reg;
    
    // Next state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_term = current_term;
        next_accumulator = accumulator;
        next_counter = counter;
        next_n_reg = n_reg;
        
        case (state)
            IDLE: begin
                done = 1'b0;
                next_counter = 5'd0;
                if (start) begin
                    next_n_reg = n_in;
                    next_term = n_in;
                    next_accumulator = 16'd0;
                    next_state = COMPUTE;
                end
            end
            
            COMPUTE: begin
                done = 1'b0;
                next_counter = counter + 5'd1;
                next_accumulator = accumulator + current_term;
                next_term = current_term - 8'd2;
                
                // Check if term <= 0 or max iterations reached
                if (current_term <= 8'd0 || counter >= 5'd15) begin
                    next_state = COMPLETE;
                end
            end
            
            COMPLETE: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
                done = 1'b0;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_term <= 8'd0;
            accumulator <= 16'd0;
            counter <= 5'd0;
            n_reg <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            current_term <= next_term;
            accumulator <= next_accumulator;
            counter <= next_counter;
            n_reg <= next_n_reg;
            
            // Latch result when complete
            if (state == COMPLETE) begin
                result <= accumulator;
            end
        end
    end

endmodule