module sheldon_counter (
    input clk,
    input rst_n,
    input start,
    input [15:0] x,
    input [15:0] y,
    output reg [15:0] count,
    output reg done
);
    // FSM states
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] DONE     = 2'd2;
    
    reg [1:0] state, next_state;
    
    // Counting variables
    reg [7:0] index;                 // 8-bit for up to 200 entries
    
    // ROM storage (initialize with all possible Sheldon numbers)
    reg [15:0] sheldon_rom [0:199];  // Must have exact Sheldon values
    
    // Combinational read
    wire [15:0] current_num = sheldon_rom[index];
    
    // Ensure register initialization in reset
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize ROM (placeholder - actual Sheldon numbers required)
            for (i = 0; i < 200; i = i + 1)
                sheldon_rom[i] <= 16'd0;
                
            state <= IDLE;
            next_state <= IDLE;
            count <= 16'd0;
            done <= 1'b0;
            index <= 8'd0;
        end else begin
            // Default assignments
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        count <= 16'd0;
                        index <= 8'd0;
                        next_state <= COUNTING;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COUNTING: begin
                    // Check current value & increment counter
                    if (current_num >= x && current_num <= y)
                        count <= count + 16'd1;
                    
                    // Proceed to next entry or finish
                    index <= index + 8'd1;
                    if (index == 8'd199)
                        next_state <= DONE;
                end
                
                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule