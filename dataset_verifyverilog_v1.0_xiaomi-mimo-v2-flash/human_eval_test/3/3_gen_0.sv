module balance_monitor (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire ops_valid,
    input wire signed [7:0] op,
    output reg below_zero,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE        = 2'd0;
    localparam [1:0] PROCESSING  = 2'd1;
    localparam [1:0] DONE_STATE  = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg signed [15:0] accumulator;
    reg [4:0] op_counter;  // 5-bit counter for up to 16 operations (0-15)
    
    // Combinational adder and comparator
    wire signed [15:0] next_accumulator;
    wire is_below_zero;
    
    assign next_accumulator = accumulator + op;
    assign is_below_zero = (next_accumulator < 16'sd0);
    
    // FSM with synchronous reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            accumulator <= 16'sd0;
            below_zero <= 1'b0;
            done <= 1'b0;
            op_counter <= 5'd0;
        end else begin
            // Default outputs
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        accumulator <= 16'sd0;
                        below_zero <= 1'b0;
                        op_counter <= 5'd0;
                        state <= PROCESSING;
                    end
                end
                
                PROCESSING: begin
                    if (ops_valid && op_counter < 5'd16) begin
                        // Add operation to accumulator
                        accumulator <= next_accumulator;
                        
                        // Check if balance drops below zero
                        if (is_below_zero) begin
                            below_zero <= 1'b1;
                        end
                        
                        // Increment counter
                        op_counter <= op_counter + 5'd1;
                    end else if (!ops_valid || op_counter >= 5'd16) begin
                        // Sequence ended
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule